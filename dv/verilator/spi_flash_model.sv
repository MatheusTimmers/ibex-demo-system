module spi_flash_model #(
  parameter int unsigned AddrBits = 16
) (
  input  logic clk_i,
  input  logic cs_ni,
  input  logic sck_i,
  input  logic mosi_i,
  output logic miso_o
);

  localparam logic [7:0] ReadCmd = 8'h03;

  logic [7:0] mem [2**AddrBits];

  logic                sck_q;
  logic [31:0]         header;
  logic [5:0]          header_bits;
  logic                reading;
  logic [AddrBits-1:0] addr;
  logic [2:0]          next_bit;

  wire rise = sck_i & ~sck_q;
  wire fall = ~sck_i & sck_q;
  wire header_done = header_bits == 6'd32;

  string image;

  initial begin
    for (int i = 0; i < 2**AddrBits; i++) begin
      mem[i] = 8'hFF;
    end
    if ($value$plusargs("flash=%s", image)) begin
      $readmemh(image, mem);
    end
  end

  always_ff @(posedge clk_i) begin
    sck_q <= sck_i;

    if (cs_ni) begin
      header_bits <= '0;
      reading     <= 1'b0;
      miso_o      <= 1'b0;
    end else if (rise && !header_done) begin
      header      <= {header[30:0], mosi_i};
      header_bits <= header_bits + 6'd1;
    end else if (fall && header_done && !reading && header[31:24] == ReadCmd) begin
      reading  <= 1'b1;
      miso_o   <= mem[header[AddrBits-1:0]][7];
      addr     <= header[AddrBits-1:0];
      next_bit <= 3'd6;
    end else if (fall && reading) begin
      miso_o   <= mem[addr][next_bit];
      next_bit <= next_bit - 3'd1;
      if (next_bit == 3'd0) begin
        addr <= addr + 1'b1;
      end
    end
  end

endmodule
