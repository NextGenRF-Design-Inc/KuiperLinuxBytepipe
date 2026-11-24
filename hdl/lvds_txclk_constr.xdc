# LVDS, TX on its own DCLK_IN (axi_adrv9001 USE_RX_CLK_FOR_TX = 0).
# make.tcl adds this file only in that case; with TX clocked from RX these
# TX clock buffers do not exist and the constraints would match nothing.

# TX runs on its own DCLK_IN in LVDS: balance each TX's fast and divided clock
# buffers so the OSERDES CLK/CLKDIV skew stays in spec, as lvds_constr.xdc does
# for RX.
set_property CLOCK_DELAY_GROUP BALANCE_TX_CLOCKS_1 \
  [list [get_nets -of [get_pins i_system_wrapper/system_i/axi_adrv9001/inst/i_if/i_tx_1_phy/i_dac_div_clk_rbuf/O]] \
        [get_nets -of [get_pins i_system_wrapper/system_i/axi_adrv9001/inst/i_if/i_tx_1_phy/i_dac_clk_in_gbuf/O]] \
  ]

set_property CLOCK_DELAY_GROUP BALANCE_TX_CLOCKS_2 \
  [list [get_nets -of [get_pins i_system_wrapper/system_i/axi_adrv9001/inst/i_if/i_tx_2_phy/i_dac_div_clk_rbuf/O]] \
        [get_nets -of [get_pins i_system_wrapper/system_i/axi_adrv9001/inst/i_if/i_tx_2_phy/i_dac_clk_in_gbuf/O]] \
  ]
