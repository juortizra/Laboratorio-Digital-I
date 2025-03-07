`include "./freqDiv.v"
`include "./MasterI2C.v"
`include "./Controlador.v"

module top (
    //output wire [7:0] read1I2C,
    //output wire [7:0] read2I2C,
    //output wire [7:0] read3I2C,
    input wire rst,
    input wire clk,
    inout wire sda,
    output wire scl

);

 wire read = read1I2C[2];
 wire clkI2C;
 wire startI2C;
 wire busyI2C;
 wire [6:0] addrI2C;
 wire rwI2C;
 wire wrI2C;
 wire [1:0] byteI2C;
 wire [4:0] amountI2C;
 wire [7:0] read1I2C;
 wire [7:0] read2I2C;
 wire [7:0] read3I2C;
 wire [7:0] write1I2C;
 wire [7:0] write2I2C;
 wire [7:0] write3I2C;
 
    // Generación del reloj I2C
`ifdef DEBUG
  assign clkI2C = clk;
`else
  freqDiv #(
      .FREQ_IN(25e6),
      .FREQ_OUT(50e3)
  ) clki2c (
      .RST(rst),
      .CLK_IN(clk),
      .CLK_OUT(clkI2C)
  );
`endif

   // Instancia del Controlador I2C
   I2C_Controlador Controlador( 
      .CLK_CON(clkI2C),
      .BUSY_CON(busyI2C),
      .RST_CON(rst),
      .DATA_READ1_CON(read1I2C),
      .DATA_READ2_CON(read2I2C),
      .DATA_READ3_CON(read3I2C),
      .START_CON(startI2C),
      .RW_CON(rwI2C),
      .WRITE_READ_CON(wrI2C),
      .AMOUNT_W_CON(amountI2C),
      .BYTE_INDEX_CON(byteI2C),
      .DATA_WRITE1_CON(write1I2C),
      .DATA_WRITE2_CON(write2I2C),
      .DATA_WRITE3_CON(write3I2C),
      .ADDR_CON(addrI2C)
  ); 

  I2C_FPGA MasterI2C( 
      .CLK(clkI2C),
      .RST(rst),
      .START(startI2C),
      .RW(rwI2C),
      .WRITE_READ(wrI2C),
      .AMOUNT_W(amountI2C),
      .BYTE_INDEX(byteI2C),
      .ADDR(addrI2C),
      .DATA_WRITE1(write1I2C),
      .DATA_WRITE2(write2I2C),
      .DATA_WRITE3(write3I2C),
      .DATA_READ1(read1I2C),
      .DATA_READ2(read2I2C),
      .DATA_READ3(read3I2C),
      .SDA(sda),
      .SCL(scl),
      .BUSY(busyI2C)
  );


endmodule
