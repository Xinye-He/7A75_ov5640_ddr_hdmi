`timescale 1ns/1ps

module tb_ddr3_rw;
    reg ui_clk = 1'b0;
    always #5 ui_clk = ~ui_clk;

    reg ui_clk_sync_rst = 1'b1;
    reg init_calib_complete = 1'b0;
    reg app_rdy = 1'b1;
    reg app_wdf_rdy = 1'b1;
    reg app_rd_data_valid = 1'b0;
    reg [8:0] wfifo_rcount = 9'd0;
    reg [8:0] rfifo_wcount = 9'd0;
    reg wfifo_empty = 1'b0;
    reg rfifo_full = 1'b0;
    reg wfifo_rd_busy = 1'b0;
    reg rfifo_wr_busy = 1'b0;
    reg rd_load = 1'b0;
    reg wr_load = 1'b0;

    wire rfifo_wren;
    wire rfifo_flush;
    wire capture_allow;
    wire [27:0] app_addr;
    wire app_en;
    wire app_wdf_wren;
    wire app_wdf_end;
    wire [2:0] app_cmd;
    wire read_overflow;

    integer write_beats = 0;
    integer read_beats = 0;
    integer expected_write_page = 1;
    integer expected_read_page = 1;

    ddr3_rw dut (
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst),
        .init_calib_complete(init_calib_complete),
        .app_rdy(app_rdy),
        .app_wdf_rdy(app_wdf_rdy),
        .app_rd_data_valid(app_rd_data_valid),
        .wfifo_rcount(wfifo_rcount),
        .rfifo_wcount(rfifo_wcount),
        .wfifo_empty(wfifo_empty),
        .rfifo_full(rfifo_full),
        .wfifo_rd_busy(wfifo_rd_busy),
        .rfifo_wr_busy(rfifo_wr_busy),
        .rd_load(rd_load),
        .wr_load(wr_load),
        .app_addr_rd_min(28'd0),
        .app_addr_rd_max(28'd32),
        .rd_bust_len(8'd2),
        .app_addr_wr_min(28'd0),
        .app_addr_wr_max(28'd32),
        .wr_bust_len(8'd2),
        .ddr3_read_valid(1'b1),
        .ddr3_pingpang_en(1'b1),
        .rfifo_wren(rfifo_wren),
        .rfifo_flush(rfifo_flush),
        .capture_allow(capture_allow),
        .app_addr(app_addr),
        .app_en(app_en),
        .app_wdf_wren(app_wdf_wren),
        .app_wdf_end(app_wdf_end),
        .app_cmd(app_cmd),
        .read_overflow(read_overflow)
    );

    always @(posedge ui_clk) begin
        app_rd_data_valid <= app_en && (app_cmd == 3'd1);

        if(app_wdf_wren) begin
            if(app_addr[25] !== expected_write_page[0])
                $fatal(1, "write/read page collision: write page=%0d expected=%0d",
                       app_addr[25], expected_write_page);
            write_beats <= write_beats + 1;
            if(wfifo_rcount != 0)
                wfifo_rcount <= wfifo_rcount - 1'b1;
        end

        if(app_en && (app_cmd == 3'd1)) begin
            if(app_addr[25] !== expected_read_page[0])
                $fatal(1, "wrong display page: read page=%0d expected=%0d",
                       app_addr[25], expected_read_page);
            read_beats <= read_beats + 1;
        end

        if(read_overflow)
            $fatal(1, "unexpected read FIFO overflow");
    end

    task pulse_display_frame;
        begin
            @(negedge ui_clk);
            rd_load = 1'b1;
            @(negedge ui_clk);
            rd_load = 1'b0;
        end
    endtask

    initial begin
        repeat(5) @(posedge ui_clk);
        ui_clk_sync_rst = 1'b0;
        init_calib_complete = 1'b1;
        wfifo_rcount = 9'd4;

        wait(write_beats == 4);
        wait(capture_allow == 1'b0);
        pulse_display_frame();
        wait(capture_allow == 1'b1);
        wait(read_beats == 4);

        // A second camera frame must use the page released by the display.
        expected_write_page = 0;
        wfifo_rcount = 9'd4;
        wait(write_beats == 8);
        wait(capture_allow == 1'b0);
        expected_read_page = 0;
        pulse_display_frame();
        wait(capture_allow == 1'b1);
        wait(read_beats == 8);

        repeat(5) @(posedge ui_clk);
        $display("PASS: page ownership, frame handoff, and MIG backpressure counters");
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "simulation timeout");
    end
endmodule
