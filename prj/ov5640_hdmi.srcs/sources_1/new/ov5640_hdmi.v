module ov5640_hdmi(
    input                 sys_clk,
    input                 sys_rst_n,
    input                 cam_pclk,
    input                 cam_vsync,
    input                 cam_href,
    input   [7:0]         cam_data,
    output                cam_rst_n,
    output                cam_pwdn,
    output                cam_scl,
    inout                 cam_sda,
    inout   [15:0]        ddr3_dq,
    inout   [1:0]         ddr3_dqs_n,
    inout   [1:0]         ddr3_dqs_p,
    output  [13:0]        ddr3_addr,
    output  [2:0]         ddr3_ba,
    output                ddr3_ras_n,
    output                ddr3_cas_n,
    output                ddr3_we_n,
    output                ddr3_reset_n,
    output  [0:0]         ddr3_ck_p,
    output  [0:0]         ddr3_ck_n,
    output  [0:0]         ddr3_cke,
    output  [0:0]         ddr3_cs_n,
    output  [1:0]         ddr3_dm,
    output  [0:0]         ddr3_odt,
    input                 hpdin,
    output                tmds_clk_p,
    output                tmds_clk_n,
    output  [2:0]         tmds_data_p,
    output  [2:0]         tmds_data_n
);

localparam [10:0] V_CMOS_DISP = 11'd768;
localparam [10:0] H_CMOS_DISP = 11'd1024;
localparam [12:0] TOTAL_H_PIXEL = 13'd2240;
localparam [12:0] TOTAL_V_PIXEL = 13'd1272;
localparam [27:0] FRAME_PIXELS = 28'd786432;

wire clk_50m;
wire clk_200m;
wire pixel_clk;
wire pixel_clk_5x;
wire locked;
wire base_reset_n = sys_rst_n & locked;
wire cfg_reset;
wire cam_reset;
wire cfg_rst_n = ~cfg_reset;
wire cam_domain_rst_n = ~cam_reset;
reg pixel_rst_n;

wire cam_init_done;
wire cam_init_error;
wire init_calib_complete;
wire capture_allow_ui;
wire cmos_frame_vsync;
wire cmos_frame_valid;
wire [15:0] wr_data;
wire [15:0] rd_data;
wire rdata_req;
wire rd_vsync;
reg rd_vsync_pixel;
wire [10:0] h_disp;

(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg capture_allow_meta;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg capture_allow_cam;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg ddr_ready_meta;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg ddr_ready_cam;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg cam_init_meta;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg cam_init_cam;
reg cam_init_ok_cfg;
reg cmos_frame_vsync_cam;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg calib_meta_pixel;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg calib_sync_pixel;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg init_meta_pixel;
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg init_sync_pixel;

asyn_rst_syn u_cfg_reset_sync (
    .clk      (clk_50m),
    .reset_n  (base_reset_n),
    .syn_reset(cfg_reset)
);

asyn_rst_syn u_cam_reset_sync (
    .clk      (cam_pclk),
    .reset_n  (base_reset_n),
    .syn_reset(cam_reset)
);

// Synchronize readiness into the pixel domain before releasing HDMI logic.
// pixel_rst_n is itself registered, so no combinational CDC signal drives a
// reset input.
always @(posedge pixel_clk or negedge base_reset_n) begin
    if(!base_reset_n) begin
        calib_meta_pixel <= 1'b0;
        calib_sync_pixel <= 1'b0;
        init_meta_pixel  <= 1'b0;
        init_sync_pixel  <= 1'b0;
        pixel_rst_n      <= 1'b0;
        rd_vsync_pixel   <= 1'b0;
    end else begin
        calib_meta_pixel <= init_calib_complete;
        calib_sync_pixel <= calib_meta_pixel;
        init_meta_pixel  <= cam_init_ok_cfg;
        init_sync_pixel  <= init_meta_pixel;
        pixel_rst_n      <= calib_sync_pixel & init_sync_pixel;
        rd_vsync_pixel   <= rd_vsync;
    end
end

always @(posedge cam_pclk or negedge cam_domain_rst_n) begin
    if(!cam_domain_rst_n) begin
        capture_allow_meta <= 1'b0;
        capture_allow_cam  <= 1'b0;
        ddr_ready_meta     <= 1'b0;
        ddr_ready_cam      <= 1'b0;
        cam_init_meta      <= 1'b0;
        cam_init_cam       <= 1'b0;
        cmos_frame_vsync_cam <= 1'b0;
    end else begin
        capture_allow_meta <= capture_allow_ui;
        capture_allow_cam  <= capture_allow_meta;
        ddr_ready_meta     <= init_calib_complete;
        ddr_ready_cam      <= ddr_ready_meta;
        cam_init_meta      <= cam_init_ok_cfg;
        cam_init_cam       <= cam_init_meta;
        cmos_frame_vsync_cam <= cmos_frame_vsync;
    end
end

// Register the combined status in its source domain before synchronizing it.
// This prevents glitches from feeding the first CDC synchronizer stage.
always @(posedge clk_50m or negedge cfg_rst_n) begin
    if(!cfg_rst_n)
        cam_init_ok_cfg <= 1'b0;
    else
        cam_init_ok_cfg <= cam_init_done & ~cam_init_error;
end

ov5640_dri u_ov5640_dri (
    .clk               (clk_50m),
    .rst_n             (cfg_rst_n),
    .cam_domain_rst_n  (cam_domain_rst_n),
    .cam_pclk          (cam_pclk),
    .cam_vsync         (cam_vsync),
    .cam_href          (cam_href),
    .cam_data          (cam_data),
    .cam_rst_n         (cam_rst_n),
    .cam_pwdn          (cam_pwdn),
    .cam_scl           (cam_scl),
    .cam_sda           (cam_sda),
    .capture_start     (capture_allow_cam & ddr_ready_cam & cam_init_cam),
    .cmos_h_pixel      ({2'b0, H_CMOS_DISP}),
    .cmos_v_pixel      ({2'b0, V_CMOS_DISP}),
    .total_h_pixel     (TOTAL_H_PIXEL),
    .total_v_pixel     (TOTAL_V_PIXEL),
    .cam_init_done     (cam_init_done),
    .cam_init_error    (cam_init_error),
    .cmos_frame_vsync  (cmos_frame_vsync),
    .cmos_frame_href   (),
    .cmos_frame_valid  (cmos_frame_valid),
    .cmos_frame_data   (wr_data)
);

ddr3_top u_ddr3_top (
    .clk_200m            (clk_200m),
    .sys_rst_n           (base_reset_n),
    .init_calib_complete (init_calib_complete),
    .capture_allow       (capture_allow_ui),
    .app_addr_rd_min     (28'd0),
    .app_addr_rd_max     (FRAME_PIXELS),
    .rd_bust_len         (8'd128),
    .app_addr_wr_min     (28'd0),
    .app_addr_wr_max     (FRAME_PIXELS),
    .wr_bust_len         (8'd128),
    .ddr3_dq             (ddr3_dq),
    .ddr3_dqs_n          (ddr3_dqs_n),
    .ddr3_dqs_p          (ddr3_dqs_p),
    .ddr3_addr           (ddr3_addr),
    .ddr3_ba             (ddr3_ba),
    .ddr3_ras_n          (ddr3_ras_n),
    .ddr3_cas_n          (ddr3_cas_n),
    .ddr3_we_n           (ddr3_we_n),
    .ddr3_reset_n        (ddr3_reset_n),
    .ddr3_ck_p           (ddr3_ck_p),
    .ddr3_ck_n           (ddr3_ck_n),
    .ddr3_cke            (ddr3_cke),
    .ddr3_cs_n           (ddr3_cs_n),
    .ddr3_dm             (ddr3_dm),
    .ddr3_odt            (ddr3_odt),
    .ddr3_read_valid     (1'b1),
    .ddr3_pingpang_en    (1'b1),
    .wr_clk              (cam_pclk),
    .wr_load             (cmos_frame_vsync_cam),
    .datain_valid        (cmos_frame_valid),
    .datain              (wr_data),
    .rd_clk              (pixel_clk),
    .rd_load             (rd_vsync_pixel),
    .dataout             (rd_data),
    .rdata_req           (rdata_req)
);

clk_wiz_0 u_clk_wiz_0 (
    .clk_out1 (clk_200m),
    .clk_out2 (clk_50m),
    .clk_out3 (pixel_clk_5x),
    .clk_out4 (pixel_clk),
    .reset    (1'b0),
    .locked   (locked),
    .clk_in1  (sys_clk)
);

hdmi_top u_hdmi_top (
    .pixel_clk    (pixel_clk),
    .pixel_clk_5x (pixel_clk_5x),
    .sys_rst_n    (pixel_rst_n),
    .hpdin        (hpdin),
    .tmds_clk_p   (tmds_clk_p),
    .tmds_clk_n   (tmds_clk_n),
    .tmds_data_p  (tmds_data_p),
    .tmds_data_n  (tmds_data_n),
    .tmds_oen     (),
    .hpdout       (),
    .video_vs     (rd_vsync),
    .h_disp       (h_disp),
    .v_disp       (),
    .pixel_xpos   (),
    .pixel_ypos   (),
    .data_in      (rd_data),
    .data_req     (rdata_req)
);

endmodule
