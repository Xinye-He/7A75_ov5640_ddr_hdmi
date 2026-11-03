param(
    [string]$VivadoBin = "C:\Xilinx\Vivado\2024.2\bin"
)

$ErrorActionPreference = "Stop"
$verificationDir = $PSScriptRoot
$rtlDir = Join-Path $PSScriptRoot "..\prj\ov5640_hdmi.srcs\sources_1\new"

Push-Location $verificationDir
try {
    & (Join-Path $VivadoBin "xvlog.bat") --sv (Join-Path $rtlDir "ddr3_rw.v") "tb_ddr3_rw.sv"
    if($LASTEXITCODE -ne 0) { throw "xvlog failed for tb_ddr3_rw" }
    & (Join-Path $VivadoBin "xelab.bat") tb_ddr3_rw -s tb_ddr3_rw_sim
    if($LASTEXITCODE -ne 0) { throw "xelab failed for tb_ddr3_rw" }
    & (Join-Path $VivadoBin "xsim.bat") tb_ddr3_rw_sim -runall
    if($LASTEXITCODE -ne 0) { throw "xsim failed for tb_ddr3_rw" }

    & (Join-Path $VivadoBin "xvlog.bat") --sv (Join-Path $rtlDir "ddr3_fifo_ctrl.v") "fifo_models.sv" "tb_ddr3_fifo_ctrl.sv"
    if($LASTEXITCODE -ne 0) { throw "xvlog failed for tb_ddr3_fifo_ctrl" }
    & (Join-Path $VivadoBin "xelab.bat") tb_ddr3_fifo_ctrl -s tb_ddr3_fifo_ctrl_sim
    if($LASTEXITCODE -ne 0) { throw "xelab failed for tb_ddr3_fifo_ctrl" }
    & (Join-Path $VivadoBin "xsim.bat") tb_ddr3_fifo_ctrl_sim -runall
    if($LASTEXITCODE -ne 0) { throw "xsim failed for tb_ddr3_fifo_ctrl" }
} finally {
    Pop-Location
}
