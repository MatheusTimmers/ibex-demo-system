// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_nexysa7 (
  input               IO_CLK,
  input               IO_RST,
  input  [15:0]       SW,
  input  [3:0]        BTN,
  output [15:0]       LED,
  output [5:0]        RGB_LED,
  input               UART_RX,
  output              UART_TX,
  output              QSPI_CS_N,
  output              QSPI_MOSI,
  input               QSPI_MISO,
  output              QSPI_WP_N,
  output              QSPI_HOLD_N
);
  parameter SRAMInitFile = "";

  localparam int unsigned ClockFrequency = 40_000_000;

  logic clk_sys, rst_sys_n;
  logic [15:0] gp_o;

  ibex_demo_system #(
    .ClockFrequency(ClockFrequency),
    .GpiWidth(20),
    .GpoWidth(16),
    .PwmWidth(6),
    .SRAMInitFile(SRAMInitFile)
  ) u_ibex_demo_system (
    .clk_sys_i(clk_sys),
    .rst_sys_ni(rst_sys_n),
    .gp_i({SW, BTN[3:1], QSPI_MISO}),
    .uart_rx_i(UART_RX),

    .gp_o(gp_o),
    .pwm_o(RGB_LED),
    .uart_tx_o(UART_TX),

    .spi_rx_i(1'b0),
    .spi_tx_o(),
    .spi_sck_o(),

    .trst_ni(1'b1),
    .tms_i  (1'b0),
    .tck_i  (1'b0),
    .td_i   (1'b0),
    .td_o   ()
  );

  assign LED = {gp_o[15:11], 3'b000, gp_o[7:0]};

  assign QSPI_CS_N   = ~gp_o[8];
  assign QSPI_MOSI   = gp_o[10];
  assign QSPI_WP_N   = 1'b1;
  assign QSPI_HOLD_N = 1'b1;

  STARTUPE2 #(
    .PROG_USR("FALSE"),
    .SIM_CCLK_FREQ(0.0)
  ) u_startup (
    .CFGCLK(),
    .CFGMCLK(),
    .EOS(),
    .PREQ(),
    .CLK(1'b0),
    .GSR(1'b0),
    .GTS(1'b0),
    .KEYCLEARB(1'b1),
    .PACK(1'b0),
    .USRCCLKO(gp_o[9]),
    .USRCCLKTS(1'b0),
    .USRDONEO(1'b1),
    .USRDONETS(1'b1)
  );

  logic IO_RST_N;
  assign IO_RST_N = ~IO_RST;

  clkgen_nexysa7 clkgen(
    .IO_CLK,
    .IO_RST_N,
    .clk_sys,
    .rst_sys_n
  );

endmodule
