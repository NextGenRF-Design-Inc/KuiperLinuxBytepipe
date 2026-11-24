# LVDS, TX clocked from RX (axi_adrv9001 USE_RX_CLK_FOR_TX = 1). make.tcl adds this
# Tcl constraint file only in that case, for implementation only: the IP is a black
# box during top-level synthesis.
#
# RX1 ssi_rst_pos (rx1_dclk_out, clocked over local routing from the K4 clock input)
# clears the RX1 BUFGCE_DIV and, through adc_rst|ssi_rst and dac_rst|ssi_rst, sets
# the serdes_rst_seq registers of RX1 and, in this mode, TX1 (axi_adrv9001_adc_1_clk).
# With two PHYs to reach, the fast-to-divided crossing has a setup+hold window of
# under 0.1 ns: the default build missed setup by 0.080 ns, and a slice-by-slice LOC
# sweep found at best +0.026 ns, varying by +/-0.1 ns between neighbouring slices.
#
# The path is static in this design: system_top.v ties mssi_sync to 1'b0, so the
# mssi_sync_d/_2d/_3d/_edge chain and ssi_rst_pos stay at their power-up 0 and
# ssi_rst_pos never toggles. These endpoints are therefore not timed; the
# BUFGCE_DIV CLR path from the same register stays timed.
#
# This is Tcl rather than XDC so the exception can check its own premise. The build
# stops here if mssi_sync_d/D is no longer driven by a constant 0 (mssi_sync was
# connected), or if the cell names no longer match what this exception was written
# for (the ADI library changed). In either case, remove or rework the exception.

set adrv_if i_system_wrapper/system_i/axi_adrv9001/inst/i_if

set ssi_src [get_cells -quiet $adrv_if/i_rx_1_phy/ssi_rst_pos_reg]
set ssi_dst [get_cells -quiet -hier -filter {NAME =~ i_system_wrapper/system_i/axi_adrv9001/inst/i_if/i_*_1_phy/i_serdes/serdes_rst_seq_reg[*]}]
if {[llength $ssi_src] != 1 || [llength $ssi_dst] != 12} {
  error "lvds_rxclk_constr.tcl: expected 1 ssi_rst_pos_reg and 12 serdes_rst_seq registers in RX1/TX1, found [llength $ssi_src] and [llength $ssi_dst]; the false path no longer matches the design"
}

set ssi_sync_d [get_cells -quiet $adrv_if/i_rx_1_phy/mssi_sync_d_reg]
set ssi_sync_drv [get_cells -quiet -of [get_pins -quiet -leaf -filter {DIRECTION == OUT} -of [get_nets -quiet -of [get_pins -quiet $ssi_sync_d/D]]]]
if {[llength $ssi_sync_drv] != 1 || [get_property REF_NAME $ssi_sync_drv] ne "GND"} {
  error "lvds_rxclk_constr.tcl: RX1 mssi_sync_d/D is not driven by GND (driver: [get_property NAME $ssi_sync_drv]); mssi_sync is live, so the false path on ssi_rst_pos is wrong"
}

set_false_path -from $ssi_src -to $ssi_dst
