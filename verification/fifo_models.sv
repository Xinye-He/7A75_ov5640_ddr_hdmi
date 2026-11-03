`timescale 1ns/1ps

module fifo_model_512x128(
    input rst, input wr_clk, input rd_clk, input [127:0] din,
    input wr_en, input rd_en, output [127:0] dout,
    output full, output empty, output [8:0] rd_data_count,
    output [8:0] wr_data_count, output wr_rst_busy, output rd_rst_busy
);
    reg [127:0] mem [0:511];
    integer wptr = 0;
    integer rptr = 0;
    integer count = 0;

    assign dout = mem[rptr];
    assign full = (count == 512);
    assign empty = (count == 0);
    assign rd_data_count = count[8:0];
    assign wr_data_count = count[8:0];
    assign wr_rst_busy = 1'b0;
    assign rd_rst_busy = 1'b0;

    always @(posedge wr_clk) begin
        if(rst) begin
            wptr <= 0;
            rptr <= 0;
            count <= 0;
        end else begin
            case({wr_en && !full, rd_en && !empty})
                2'b10: begin
                    mem[wptr] <= din;
                    wptr <= (wptr + 1) & 511;
                    count <= count + 1;
                end
                2'b01: begin
                    rptr <= (rptr + 1) & 511;
                    count <= count - 1;
                end
                2'b11: begin
                    mem[wptr] <= din;
                    wptr <= (wptr + 1) & 511;
                    rptr <= (rptr + 1) & 511;
                end
            endcase
        end
    end
endmodule

module wr_fifo(
    input rst, input wr_clk, input rd_clk, input [127:0] din,
    input wr_en, input rd_en, output [127:0] dout,
    output full, output empty, output [8:0] rd_data_count,
    output [8:0] wr_data_count, output wr_rst_busy, output rd_rst_busy
);
    fifo_model_512x128 u_model(.*);
endmodule

module rd_fifo(
    input rst, input wr_clk, input rd_clk, input [127:0] din,
    input wr_en, input rd_en, output [127:0] dout,
    output full, output empty, output [8:0] rd_data_count,
    output [8:0] wr_data_count, output wr_rst_busy, output rd_rst_busy
);
    fifo_model_512x128 u_model(.*);
endmodule
