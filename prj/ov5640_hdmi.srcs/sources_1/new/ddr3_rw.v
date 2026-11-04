`timescale 1ns / 1ps

module ddr3_rw(
    input           ui_clk,
    input           ui_clk_sync_rst,
    input           init_calib_complete,
    input           app_rdy,
    input           app_wdf_rdy,
    input           app_rd_data_valid,
    input    [8:0]  wfifo_rcount,
    input    [8:0]  rfifo_wcount,
    input           wfifo_empty,
    input           rfifo_full,
    input           wfifo_rd_busy,
    input           rfifo_wr_busy,
    input           rd_load,
    input           wr_load,
    input   [27:0]  app_addr_rd_min,
    input   [27:0]  app_addr_rd_max,
    input    [7:0]  rd_bust_len,
    input   [27:0]  app_addr_wr_min,
    input   [27:0]  app_addr_wr_max,
    input    [7:0]  wr_bust_len,
    input           ddr3_read_valid,
    input           ddr3_pingpang_en,
    output          rfifo_wren,
    output reg      rfifo_flush,
    output          capture_allow,
    output  [27:0]  app_addr,
    output          app_en,
    output          app_wdf_wren,
    output          app_wdf_end,
    output   [2:0]  app_cmd,
    output reg      read_overflow
);

localparam ST_IDLE  = 2'd0;
localparam ST_WRITE = 2'd1;
localparam ST_READ  = 2'd2;

reg [1:0] state;
reg [27:0] app_addr_wr;
reg [27:0] app_addr_rd;
reg [7:0] write_count;
reg [7:0] read_count;
reg [9:0] outstanding_reads;
reg write_page;
reg read_page;
reg ready_page;
reg frame_ready;
reg have_frame;
reg read_frame_done;
reg capture_allow_reg;

(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg rd_load_meta;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg rd_load_sync;
reg rd_load_prev;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg wr_load_meta;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg wr_load_sync;
reg wr_load_prev;

reg       flush_pending;
reg [4:0] flush_count;

wire rd_frame_edge = rd_load_sync && !rd_load_prev;
wire wr_frame_edge = wr_load_sync && !wr_load_prev;
wire write_accept  = (state == ST_WRITE) && app_rdy && app_wdf_rdy &&
                     !wfifo_empty && !wfifo_rd_busy;
wire read_accept   = (state == ST_READ) && app_rdy;
wire [10:0] projected_read_fill = {2'b0, rfifo_wcount} +
                                   {1'b0, outstanding_reads};
wire read_space_available = projected_read_fill <=
                            (11'd512 - {3'b0, rd_bust_len});

assign capture_allow = capture_allow_reg;
assign rfifo_wren    = app_rd_data_valid && !rfifo_full &&
                       !rfifo_wr_busy && !rfifo_flush;
assign app_en        = write_accept || (state == ST_READ);
assign app_wdf_wren  = write_accept;
assign app_wdf_end   = write_accept;
assign app_cmd       = (state == ST_READ) ? 3'd1 : 3'd0;
assign app_addr      = (state == ST_READ) ?
                       (ddr3_pingpang_en ? {2'b0, read_page, app_addr_rd[24:0]} :
                                             {3'b0, app_addr_rd[24:0]}) :
                       (ddr3_pingpang_en ? {2'b0, write_page, app_addr_wr[24:0]} :
                                             {3'b0, app_addr_wr[24:0]});

always @(posedge ui_clk) begin
    if(ui_clk_sync_rst) begin
        rd_load_meta <= 1'b0;
        rd_load_sync <= 1'b0;
        rd_load_prev <= 1'b0;
        wr_load_meta <= 1'b0;
        wr_load_sync <= 1'b0;
        wr_load_prev <= 1'b0;
    end else begin
        rd_load_meta <= rd_load;
        rd_load_sync <= rd_load_meta;
        rd_load_prev <= rd_load_sync;
        wr_load_meta <= wr_load;
        wr_load_sync <= wr_load_meta;
        wr_load_prev <= wr_load_sync;
    end
end

always @(posedge ui_clk) begin
    if(ui_clk_sync_rst) begin
        state             <= ST_IDLE;
        app_addr_wr       <= 28'd0;
        app_addr_rd       <= 28'd0;
        write_count       <= 8'd0;
        read_count        <= 8'd0;
        outstanding_reads <= 10'd0;
        write_page        <= 1'b1;
        read_page         <= 1'b0;
        ready_page        <= 1'b0;
        frame_ready       <= 1'b0;
        have_frame        <= 1'b0;
        read_frame_done   <= 1'b1;
        capture_allow_reg <= 1'b0;
        flush_pending     <= 1'b0;
        flush_count       <= 5'd0;
        rfifo_flush       <= 1'b0;
        read_overflow     <= 1'b0;
    end else begin
        // Register the FIFO reset request before it enters the asynchronous
        // reset synchronizers inside the dual-clock FIFO.
        rfifo_flush <= (flush_count != 0);
        case({read_accept, app_rd_data_valid})
            2'b10: outstanding_reads <= outstanding_reads + 1'b1;
            2'b01: if(outstanding_reads != 0)
                       outstanding_reads <= outstanding_reads - 1'b1;
            default: outstanding_reads <= outstanding_reads;
        endcase

        if(app_rd_data_valid && (rfifo_full || rfifo_wr_busy || rfifo_flush))
            read_overflow <= 1'b1;

        if(flush_count != 0)
            flush_count <= flush_count - 1'b1;
        else if(flush_pending && (outstanding_reads == 0)) begin
            flush_pending <= 1'b0;
            flush_count   <= 5'd16;
        end

        if(init_calib_complete && !frame_ready)
            capture_allow_reg <= 1'b1;

        // Page ownership changes only at a display-frame boundary. The camera
        // is paused after publishing a complete page until the old display page
        // is returned, so read and write addresses can never target one page.
        if(rd_frame_edge) begin
            state         <= ST_IDLE;
            read_count    <= 8'd0;
            app_addr_rd   <= app_addr_rd_min;
            read_frame_done <= 1'b0;
            flush_pending <= 1'b1;
            if(frame_ready) begin
                read_page         <= ready_page;
                write_page        <= ~ready_page;
                app_addr_wr       <= app_addr_wr_min;
                frame_ready       <= 1'b0;
                have_frame        <= 1'b1;
                capture_allow_reg <= 1'b1;
            end
        end else begin
            case(state)
                ST_IDLE: begin
                    write_count <= 8'd0;
                    read_count  <= 8'd0;
                    if(init_calib_complete && capture_allow_reg &&
                       !frame_ready && !wfifo_rd_busy &&
                       (wfifo_rcount >= {1'b0, wr_bust_len}) &&
                       (wr_bust_len != 0)) begin
                        state <= ST_WRITE;
                    end else if(init_calib_complete && have_frame &&
                                ddr3_read_valid && !flush_pending &&
                                (flush_count == 0) && !rfifo_wr_busy &&
                                !read_frame_done &&
                                read_space_available && (rd_bust_len != 0) &&
                                (app_addr_rd < app_addr_rd_max)) begin
                        state <= ST_READ;
                    end
                end

                ST_WRITE: begin
                    if(write_accept) begin
                        if(write_count == wr_bust_len - 1'b1) begin
                            state       <= ST_IDLE;
                            write_count <= 8'd0;
                        end else begin
                            write_count <= write_count + 1'b1;
                        end
                        if(app_addr_wr >= app_addr_wr_max - 8) begin
                            app_addr_wr       <= app_addr_wr_min;
                            ready_page        <= write_page;
                            frame_ready       <= 1'b1;
                            capture_allow_reg <= 1'b0;
                            state             <= ST_IDLE;
                            write_count       <= 8'd0;
                        end else begin
                            app_addr_wr <= app_addr_wr + 8;
                        end
                    end
                end

                ST_READ: begin
                    if(read_accept) begin
                        if(read_count == rd_bust_len - 1'b1) begin
                            state      <= ST_IDLE;
                            read_count <= 8'd0;
                        end else begin
                            read_count <= read_count + 1'b1;
                        end
                        if(app_addr_rd >= app_addr_rd_max - 8) begin
                            app_addr_rd <= app_addr_rd_min;
                            read_frame_done <= 1'b1;
                            state       <= ST_IDLE;
                            read_count  <= 8'd0;
                        end else begin
                            app_addr_rd <= app_addr_rd + 8;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end

        // Keep the synchronized camera edge in the logic cone for debug and
        // explicitly hold capture disabled while waiting for a free page.
        if(wr_frame_edge && !capture_allow_reg)
            capture_allow_reg <= 1'b0;
    end
end

endmodule
