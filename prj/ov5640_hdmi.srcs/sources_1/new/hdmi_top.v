module hdmi_top(
    input           pixel_clk,
    input           pixel_clk_5x,
    input           sys_rst_n,
    input           hpdin,
    output          tmds_clk_p,
    output          tmds_clk_n,
    output [2:0]    tmds_data_p,
    output [2:0]    tmds_data_n,
    output          tmds_oen,
    output          hpdout,
    output          video_vs,
    output [10:0]   h_disp,
    output [10:0]   v_disp,
    output [10:0]   pixel_xpos,
    output [10:0]   pixel_ypos,
    input  [15:0]   data_in,
    output          data_req
);

wire video_hs;
wire video_de;
wire [15:0] video_rgb565_unused;
wire [7:0] red8   = {data_in[15:11], data_in[15:13]};
wire [7:0] green8 = {data_in[10:5],  data_in[10:9]};
wire [7:0] blue8  = {data_in[4:0],   data_in[4:2]};

reg [15:0] red_weighted;
reg [15:0] green_weighted;
reg [15:0] blue_weighted;
reg [16:0] luma_sum;
reg  [7:0] grey;

assign hpdout = hpdin;

// RGB565 is first expanded to full-range RGB888.  The 77/150/29
// coefficients implement round(256 * {0.299, 0.587, 0.114}).
// The four-clock request lead in video_driver covers FIFO output plus this
// three-stage arithmetic pipeline.
always @(posedge pixel_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        red_weighted   <= 16'd0;
        green_weighted <= 16'd0;
        blue_weighted  <= 16'd0;
        luma_sum       <= 17'd0;
        grey           <= 8'd0;
    end else begin
        red_weighted   <= 8'd77  * red8;
        green_weighted <= 8'd150 * green8;
        blue_weighted  <= 8'd29  * blue8;
        luma_sum       <= red_weighted + green_weighted + blue_weighted;
        grey           <= luma_sum[15:8];
    end
end

video_driver u_video_driver (
    .pixel_clk  (pixel_clk),
    .sys_rst_n  (sys_rst_n),
    .video_hs   (video_hs),
    .video_vs   (video_vs),
    .video_de   (video_de),
    .video_rgb  (video_rgb565_unused),
    .data_req   (data_req),
    .h_disp     (h_disp),
    .v_disp     (v_disp),
    .pixel_xpos (pixel_xpos),
    .pixel_ypos (pixel_ypos),
    .pixel_data (data_in)
);

dvi_transmitter_top u_rgb2dvi_0 (
    .pclk        (pixel_clk),
    .pclk_x5     (pixel_clk_5x),
    .reset_n     (sys_rst_n),
    .video_din   ({grey, grey, grey}),
    .video_hsync (video_hs),
    .video_vsync (video_vs),
    .video_de    (video_de),
    .tmds_clk_p  (tmds_clk_p),
    .tmds_clk_n  (tmds_clk_n),
    .tmds_data_p (tmds_data_p),
    .tmds_data_n (tmds_data_n),
    .tmds_oen    (tmds_oen)
);

endmodule
