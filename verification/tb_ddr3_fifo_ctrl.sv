`timescale 1ns/1ps

module tb_ddr3_fifo_ctrl;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg datain_valid = 1'b0;
    reg [15:0] datain = 16'b0;
    reg [127:0] rfifo_din = 128'b0;
    reg rdata_req = 1'b0;
    reg rfifo_wren = 1'b0;
    reg wfifo_rden = 1'b0;
    reg rfifo_flush = 1'b0;
    reg rd_load = 1'b0;
    reg wr_load = 1'b0;

    wire [127:0] wfifo_dout;
    wire [8:0] wfifo_rcount;
    wire [8:0] rfifo_wcount;
    wire [15:0] pic_data;
    wire wfifo_empty;
    wire rfifo_full;
    wire wfifo_rd_busy;
    wire rfifo_wr_busy;
    wire camera_overflow;
    wire video_underflow;

    integer i;
    reg [127:0] expected_pack;

    ddr3_fifo_ctrl dut (
        .rst_n(rst_n), .wr_clk(clk), .rd_clk(clk), .ui_clk(clk),
        .datain_valid(datain_valid), .datain(datain),
        .rfifo_din(rfifo_din), .rdata_req(rdata_req),
        .rfifo_wren(rfifo_wren), .wfifo_rden(wfifo_rden),
        .rfifo_flush(rfifo_flush), .rd_load(rd_load), .wr_load(wr_load),
        .wfifo_dout(wfifo_dout), .wfifo_rcount(wfifo_rcount),
        .rfifo_wcount(rfifo_wcount), .pic_data(pic_data),
        .wfifo_empty(wfifo_empty), .rfifo_full(rfifo_full),
        .wfifo_rd_busy(wfifo_rd_busy), .rfifo_wr_busy(rfifo_wr_busy),
        .camera_overflow(camera_overflow), .video_underflow(video_underflow)
    );

    initial begin
        expected_pack = {16'h1000,16'h1001,16'h1002,16'h1003,
                         16'h1004,16'h1005,16'h1006,16'h1007};
        repeat(4) @(posedge clk);
        rst_n = 1'b1;

        @(negedge clk); wr_load = 1'b1;
        @(negedge clk); wr_load = 1'b0;
        for(i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            datain_valid = 1'b1;
            datain = 16'h1000 + i;
        end
        @(negedge clk); datain_valid = 1'b0;
        repeat(3) @(posedge clk);
        if(wfifo_rcount !== 9'd1 || wfifo_dout !== expected_pack)
            $fatal(1, "RGB565 pack order/count mismatch");

        @(negedge clk); wfifo_rden = 1'b1;
        @(negedge clk); wfifo_rden = 1'b0;

        @(negedge clk);
        rfifo_din = {16'hA000,16'hA001,16'hA002,16'hA003,
                     16'hA004,16'hA005,16'hA006,16'hA007};
        rfifo_wren = 1'b1;
        @(negedge clk); rfifo_wren = 1'b0;
        repeat(2) @(posedge clk);

        for(i = 0; i < 8; i = i + 1) begin
            @(negedge clk); rdata_req = 1'b1;
            @(posedge clk); #1;
            if(pic_data !== (16'hA000 + i))
                $fatal(1, "128-to-16 unpack mismatch at pixel %0d: %h", i, pic_data);
        end
        @(negedge clk); rdata_req = 1'b0;
        repeat(2) @(posedge clk);

        if(!wfifo_empty || rfifo_wcount !== 0)
            $fatal(1, "FIFO did not drain at exact frame-word boundary");
        if(camera_overflow || video_underflow)
            $fatal(1, "unexpected overflow/underflow flag");

        $display("PASS: RGB565 8:1 pack, FWFT 1:8 unpack, and FIFO guards");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "simulation timeout");
    end
endmodule
