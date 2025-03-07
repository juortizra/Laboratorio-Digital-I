// filename: divFreq.v
module freqDiv #(
    parameter integer FREQ_IN = 1000,
    parameter integer FREQ_OUT = 100,
    parameter integer INIT = 0
) (
    // Inputs and output ports
    input wire RST,          // Reset
    input wire CLK_IN,       // Reloj de la FPGA 
    output reg CLK_OUT = 0      // Reloj de la linea SCL
);

  localparam integer COUNT = (FREQ_IN / FREQ_OUT) / 2;
  localparam integer SIZE = $clog2(COUNT);
  localparam integer LIMIT = COUNT - 1;

  // Declaración de señales [reg, wire]
  reg [SIZE-1:0] count = INIT;

  // Descripción del comportamiento
  always @(posedge CLK_IN) begin
       if (RST == 1) begin
            count <= 0;
            CLK_OUT <= 0;
        end else begin
            if (count != LIMIT)
                count <= count + 1;
            else begin
                count <= 0;
                CLK_OUT <= ~CLK_OUT; // Alterna el estado de SCL
            end
       end
   end
endmodule
