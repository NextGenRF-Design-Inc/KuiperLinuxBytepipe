# CMOS, TX on its own DCLK_IN (axi_adrv9001 USE_RX_CLK_FOR_TX = 0).
# make.tcl adds this file only in that case; with TX clocked from RX the TX1
# clock input buffer does not exist and the constraint would match nothing.

# TX1 DCLK_IN arrives on A3, the N side of a clock-capable pair, which cannot drive a
# clock buffer as a single-ended input. Route it through fabric to the TX1 BUFGCE and
# BUFGCE_DIV instead.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of [get_pins -hier -filter {NAME =~ *i_tx_1_phy/i_dac_clk_in_ibuf/O}]]
