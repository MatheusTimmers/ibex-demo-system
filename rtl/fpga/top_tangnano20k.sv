module top_tangnano20k #(
  parameter SRAMInitFile = ""
) (
  input        IO_CLK,
  output [5:0] LED,
  input        UART_RX,
  output       UART_TX
);

  localparam int unsigned ClockFrequency = 27_000_000;

  logic [7:0] por_count = '0;
  logic       rst_sys_n;
  logic [7:0] gp_o;

  always_ff @(posedge IO_CLK) begin
    if (!por_count[7]) begin
      por_count <= por_count + 8'd1;
    end
  end

  assign rst_sys_n = por_count[7];

  ibex_demo_system #(
    .GpiWidth       ( 8                   ),
    .GpoWidth       ( 8                   ),
    .PwmWidth       ( 1                   ),
    .ClockFrequency ( ClockFrequency      ),
    .RegFile        ( ibex_pkg::RegFileFF ),
    .SRAMInitFile   ( SRAMInitFile        )
  ) u_ibex_demo_system (
    .clk_sys_i (IO_CLK),
    .rst_sys_ni(rst_sys_n),
    .gp_i      ('0),
    .uart_rx_i (UART_RX),

    .gp_o     (gp_o),
    .pwm_o    (),
    .uart_tx_o(UART_TX),

    .spi_rx_i (1'b0),
    .spi_tx_o (),
    .spi_sck_o(),

    .trst_ni(1'b1),
    .tms_i  (1'b0),
    .tck_i  (1'b0),
    .td_i   (1'b0),
    .td_o   ()
  );

  assign LED = ~gp_o[5:0];

endmodule
