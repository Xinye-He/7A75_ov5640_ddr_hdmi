# Digital IC hardening notes

## Implemented changes

- Added asynchronous-assert/synchronous-release reset chains and `ASYNC_REG` attributes.
- Synchronized frame markers and capture permissions at every clock-domain boundary.
- Replaced frame-wide combinational FIFO resets with controlled packer alignment and a
  display-blanking read-FIFO flush that waits for outstanding MIG reads to drain.
- Connected FIFO `full`, `empty`, and reset-busy flags and added sticky overflow and
  underflow observability.
- Reworked the MIG scheduler to account for accepted commands, returned read beats,
  FIFO capacity, and the independent `app_rdy`/`app_wdf_rdy` backpressure signals.
- Added explicit two-page ownership. A completed camera page is published only at a
  display frame boundary; camera capture pauses at its next frame boundary until the
  previous display page is free.
- Prevented a completed display frame from being prefetched a second time before the
  next vertical sync.
- Made OV5640 SCCB NACK status sticky and blocked capture/HDMI release when camera
  initialization fails.
- Corrected RGB565 grayscale conversion by expanding each component to eight bits
  before applying the 77/150/29 luma coefficients.
- Removed the constraint on the nonexistent top-level `tmds_oen` port and corrected
  several interface widths and MIG tie-offs.

## Verification

- `verification/tb_ddr3_rw.sv` checks two consecutive page handoffs, page isolation,
  frame completion, MIG ready handling, and read-return accounting.
- `verification/tb_ddr3_fifo_ctrl.sv` checks exact 8x RGB565 to 128-bit packing,
  FWFT 128-bit to 8x RGB565 unpacking, FIFO drain boundaries, and error guards.
- `verification/run_rtl_lint.tcl` performs a low-memory Vivado RTL elaboration using
  black-box IP interfaces. It is intended for interface/syntax checks, not timing signoff.
- `prj/run_hardening_synth.tcl` runs the real project synthesis and emits utilization,
  CDC, methodology, and timing reports when sufficient host virtual memory is available.

Full timing signoff still requires board-validated OV5640 input-delay numbers. The
repository intentionally does not invent setup/hold constraints without the camera PCB
trace and sensor timing data.
