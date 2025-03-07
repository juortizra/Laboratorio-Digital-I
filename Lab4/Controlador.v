module I2C_Controlador(
   input wire CLK_CON,               // Reloj del divisor de frecuencia
   input wire BUSY_CON,              // Estado de si la FPGA esta ocupada o no
   input wire RST_CON,               // Reset asíncrono
   input wire WRITE_READ_CON,
   input wire [7:0] DATA_READ1_CON,  // Primer byte leido por los sensores 
   input wire [7:0] DATA_READ2_CON,  // Segundo byte leido por los sensores 
   input wire [7:0] DATA_READ3_CON,  // Tercer byte leido por los sensores 
   output reg START_CON,             // Bit de inicio de modulo I2C Master
   output wire RW_CON,               // Bit para escribir o leer  
   output reg [4:0] AMOUNT_W_CON,    // Cuantas veces se va a escribir
   output reg [1:0] BYTE_INDEX_CON, 
   output reg [7:0] DATA_WRITE1_CON, // Datos enviados primer byte (8 bits de direccion)
   output reg [7:0] DATA_WRITE2_CON, // Datos enviados segundo byte (8 bits de direccion)   
   output reg [7:0] DATA_WRITE3_CON, // Datos enviados tercer byte (8 bits de direccion) 
   output reg [6:0] ADDR_CON         // Direccion del sensor
);    

   localparam state_WAIT   = 0;
   localparam state_WRITE  = 1;
   //localparam state_READ   = 2;
   localparam state_FINISH = 3;

   // Direcciones y registros de sensores
   localparam ADDR_BME280   = 7'h76;
   localparam ADDR_SEESAW   = 7'h36;
   localparam ADDR_VEML7700 = 7'h10;
   localparam ADDR_LCD      = 7'h27;

   // Comandos para BME280
   localparam REG_CHIP_ID     = 8'hD0;
   localparam REG_CONF_SEN    = 8'hF5;
   localparam REG_CONF_HUM    = 8'hF2; 
   localparam REG_CONF_TEMP   = 8'hF4;
   localparam REG_TEMP_BME1   = 8'hFA; // Registro de temperatura del BME280
   localparam REG_TEMP_BME2   = 8'hFB; // Registro de temperatura del BME280
   localparam REG_TEMP_BME3   = 8'hFC; // Registro de temperatura del BME280
   localparam REG_HUM_BME1    = 8'hFD; // Registro de humedad del BME280
   localparam REG_HUM_BME2    = 8'hFE; // Registro de humedad del BME280
   
   localparam REG_HUM_SEESAW  = 8'h0F; // Registro de humedad del Seesaw
   localparam REG_HUM_SEESAW1 = 8'h10;
   localparam REG_LUX_VEML    = 8'h04; // Registro de luz del VEML7700
   // Comandos para la LCD
   localparam REG_LCD_RESET_E = 8'h3C;
   localparam REG_LCD_RESET   = 8'h38;
   localparam REG_LCD_FORTH_E = 8'h2C;
   localparam REG_LCD_FORTH   = 8'h28;
   localparam REG_FUN_SET_E   = 8'h8C;
   localparam REG_FUN_SET     = 8'h88;
   localparam REG_DIS_OFF_E   = 8'h0C;
   localparam REG_DIS_OFF     = 8'h8C;
   localparam REG_CLE_DIS_E   = 8'h1C;
   localparam REG_CLE_DIS     = 8'h18;
   localparam REG_MODE_SET_E  = 8'h6C;
   localparam REG_MODE_SET    = 8'h68;
   localparam REG_DIS_ON_OFF_E= 8'hCC;
   localparam REG_DIS_ON_OFF  = 8'hC8;
   // Datos extraidos de los sensores

   reg [7:0] MSB_TEMP;
   reg [7:0] LSB_TEMP;
   reg [7:0] XLSB_TEM;
   reg [7:0] MSB_HUM_BME280;
   reg [7:0] LSB_HUM_BME280;

   // Extraccion de valor de humedad

   reg [7:0] MSB_HUM_SEESAW      = 0;
   reg [7:0] LSB_HUM_SEESAW      = 0;
   reg [16:0] HUM_CRUD0          = 0;
   reg [16:0] HUM_CAL            = 0;
   reg [7:0] HUM_TOTAL           = 0;
   reg [3:0] DIGITO_CENTENA      = 0;
   reg [3:0] DIGITO_DECENA       = 0;
   reg [3:0] DIGITO_UNIDAD       = 0; 
   reg [7:0] ASCCI_CENTENA_MSB_E = 0;
   reg [7:0] ASCCI_CENTENA_MSB   = 0;
   reg [7:0] ASCCI_CENTENA_LSB_E = 0;
   reg [7:0] ASCCI_CENTENA_LSB   = 0;
   reg [7:0] ASCCI_DECENA_MSB_E  = 0;
   reg [7:0] ASCCI_DECENA_MSB    = 0;
   reg [7:0] ASCCI_DECENA_LSB_E  = 0;
   reg [7:0] ASCCI_DECENA_LSB    = 0;
   reg [7:0] ASCCI_UNIDAD_MSB_E  = 0;
   reg [7:0] ASCCI_UNIDAD_MSB    = 0;
   reg [7:0] ASCCI_UNIDAD_LSB_E  = 0;
   reg [7:0] ASCCI_UNIDAD_LSB    = 0;
   localparam ENABLE_ON          = 8'h0D;
   localparam ENABLE_OFF         = 8'h09;  
   reg [7:0] MSB_LUX;
   reg [7:0] LSB_LUX;

   reg [1:0] count_LCD         = 0;
   reg [1:0] FINISH            = 0;
   reg [2:0] LCD_R             = 0;    
   reg [9:0] delay_con         = 0;    
   reg [7:0] Byte1_Temp_BME280 = 0;
   reg [7:0] Byte2_Temp_BME280 = 0;
   reg [7:0] Byte3_Temp_BME280 = 0;
   reg [7:0] Byte1_Hum_BME280  = 0;
   reg [7:0] Byte2_Hum_BME280  = 0;
   reg [7:0] Byte1_VMEL7700    = 0;
   reg [7:0] Byte2_VMEL7700    = 0;
   reg [7:0] Byte1_SOIL        = 0;
   reg [7:0] Byte2_SOIL        = 0;
   reg [2:0] state_controlador = state_WAIT;
   reg [20:0] sensores_indice  = 0; // Con en él se escoge el sensor por direccion y la direccion de datos que va a extraer
   //reg write_phase = 1;        // 1: Escritura de registro, 0: Lectura de datos
   // Inicialización explícita de las señales para simulacion 
   initial begin
     START_CON = 0;                    // Inicializar START con 0 
     DATA_WRITE1_CON = 0;          // Inicilaizar la informacion con temperatura BME280
     DATA_WRITE2_CON = 0;          // Inicilaizar la informacion con temperatura BME280
     DATA_WRITE3_CON = 0;          // Inicilaizar la informacion con temperatura BME280
     ADDR_CON        = 0;                 // Inicializar la informacion con la direccion del BME280
     sensores_indice = 0;              // Empezar con el sensor BME280 y el registro de temperatura
    end
       
   assign RW_CON = (WRITE_READ_CON) ? 0 : 1;
   
// Maquina de estados de control
   always @(posedge CLK_CON) begin
           state_controlador <= state_FINISH;
           START_CON <= 1;
           case (state_controlador)
                state_WAIT: begin
                   if (BUSY_CON == 0) begin // Esperar a que el bus esté libre
                      if (sensores_indice < 106) begin // Parte que permite repetir el ciclo luego de haber leido las cuatro lectura de los tres sensores
                         START_CON <= 1;
                         state_controlador <= state_WRITE;
                      end else begin
                         state_controlador <= state_FINISH;
                      end
                   end else begin
                      START_CON <= 0;
                      state_controlador <= state_WAIT;
                   end
                end

              state_WRITE: begin

                 case (sensores_indice) // Se escoge el sensor y el registro de datos que debe leer

                    0: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= REG_LCD_RESET_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    1: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= REG_LCD_RESET;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                       if ((delay_con == 0) && (FINISH == 0)) begin
                          LCD_R     <= 2;
                          delay_con <= 250;
                       end else if ((delay_con == 0) && (FINISH == 1)) begin
                          LCD_R     <= 1;
                          delay_con <= 25;             
                       end
                    end

                    2: begin // Pantalla_LCD
                       ADDR_CON <= 0;
                       if (LCD_R == 2) begin
                          delay_con <= 250;
                       end else if (LCD_R == 1) begin
                          delay_con <= 25;
                       end else begin
                          delay_con <= 0;
                          FINISH    <= FINISH + 1;
                       end
                    end

                    3: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= REG_LCD_FORTH_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    4: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= REG_LCD_FORTH;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    //Comandos
                    5: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h2C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    6: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h28;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end
                    
                    7: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h8C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    8: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h88;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 
                         
                    9: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h0C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    10: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h08;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end     
                          
                    11: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h8C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    12: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h88;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end                      

                    13: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h0C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    14: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h08;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    15: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h1C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    16: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h18;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                       delay_con       <= 100;
                    end 

                    17: begin // Pantalla_LCD
                       ADDR_CON <= 0;
                    end 
                    
                    18: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h0C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    19: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h08;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    20: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    21: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h68;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    22: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h0C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    23: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h08;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    24: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hCC;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    25: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hC8;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Datos a escribir
                    // Posicion
                    26: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h8C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    27: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h88;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    28: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h0C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    29: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h08;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Primera letra
 
                    30: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    31: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    32: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h8D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    33: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h89;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Segunda letra

                    34: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h7D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    35: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h79;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    36: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h5D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    37: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h59;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 
                    
                    // Tercera letra

                    38: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    39: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    40: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hDD;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    41: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hD9;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Cuarta letra

                    42: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    43: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    44: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h5D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    45: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h59;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Quinta letra

                    46: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    47: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    48: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h4D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    49: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h49;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Sexta letra

                    50: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    51: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    52: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h1D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    53: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h19;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Septima letra

                    54: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    55: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    56: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h4D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    57: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h49;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Espacio

                    58: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h2D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    59: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h29;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    60: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h0D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    61: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h09;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Novena letra

                    62: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h7D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    63: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h79;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    64: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h3D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    65: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h39;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Decima letra

                    66: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h7D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    67: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h79;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    68: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h5D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    69: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h59;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Decima primera letra

                    70: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    71: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    72: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h5D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    73: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h59;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Decima segunda letra

                    74: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    75: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    76: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hCD;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    77: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hC9;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    // Decima tercera letra

                    78: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h6D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    79: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h69;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    80: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hFD;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    81: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hF9;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Segunda fila 
                    
                    82: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hCC;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    83: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'hC8;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    84: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h0C;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    85: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h08;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Centena

                    86: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_CENTENA_MSB_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    87: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_CENTENA_MSB;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    88: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_CENTENA_LSB_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    89: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_CENTENA_LSB;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Decena

                    90: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_DECENA_MSB_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    91: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_DECENA_MSB;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    92: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_DECENA_LSB_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    93: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_DECENA_LSB;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                    // Unidad

                    94: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_UNIDAD_MSB_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    95: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_UNIDAD_MSB;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    96: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_UNIDAD_LSB_E;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    97: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= ASCCI_UNIDAD_LSB;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end 

                   // Porcentaje

                    98: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h2D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    99: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h29;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end   
                      
                    100: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h5D;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                    end

                    101: begin // Pantalla_LCD
                       ADDR_CON <= ADDR_LCD;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= 8'h59;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                       count_LCD       <= 1;
                    end 

                    // Etapa de sensado 

                    102: begin // BME280 - Temperatura
                       ADDR_CON <= ADDR_BME280;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 2;
                       DATA_WRITE1_CON <= REG_CHIP_ID;
                       DATA_WRITE2_CON <= REG_TEMP_BME2;
                       DATA_WRITE3_CON <= REG_TEMP_BME3;
                       MSB_TEMP        <= DATA_READ1_CON;
                       LSB_TEMP        <= DATA_READ2_CON;
                       XLSB_TEM        <= DATA_READ3_CON;               
                    end
                    
                    103: begin // BME280 - Humedad
                       ADDR_CON <= ADDR_BME280;
                       AMOUNT_W_CON    <= 2;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= REG_HUM_BME1;
                       DATA_WRITE2_CON <= REG_HUM_BME2;
                       DATA_WRITE3_CON <= 8'h00;
                       MSB_HUM_BME280  <= DATA_READ2_CON;
                       LSB_HUM_BME280  <= DATA_READ3_CON;
                    end
                    
                    104: begin // Seesaw - Humedad del suelo
                       ADDR_CON <= ADDR_SEESAW;
                       AMOUNT_W_CON    <= 2;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= REG_HUM_SEESAW;
                       DATA_WRITE2_CON <= REG_HUM_SEESAW1;
                       DATA_WRITE3_CON <= 8'h00;
                       MSB_HUM_SEESAW  <= DATA_READ2_CON;
                       LSB_HUM_SEESAW  <= DATA_READ3_CON;
                    end
                    
                    105: begin // VEML7700 - Luz
                       ADDR_CON <= ADDR_VEML7700;
                       AMOUNT_W_CON    <= 1;
                       BYTE_INDEX_CON  <= 1;
                       DATA_WRITE1_CON <= REG_LUX_VEML;
                       DATA_WRITE2_CON <= 8'h00;
                       DATA_WRITE3_CON <= 8'h00;
                       MSB_LUX         <= DATA_READ2_CON;
                       LSB_LUX         <= DATA_READ3_CON;
                    end
                    
                 endcase
                 if ((delay_con == 0) && (LCD_R == 0)) begin
                    sensores_indice <= sensores_indice + 1;
                    state_controlador <= state_WAIT;
                 end else if ((delay_con == 0) && (LCD_R > 0)) begin
                    sensores_indice <= 0;
                    delay_con       <= 0;
                    LCD_R           <= 0;
                    FINISH          <= FINISH + 1;
                    state_controlador <= state_WRITE;
                 end else begin
                    delay_con <= delay_con - 1;
                    if (sensores_indice == 1)  begin
                       sensores_indice <= 2;
                    end else if (sensores_indice == 16) begin
                       sensores_indice <= 17;
                    end
                    state_controlador <= state_WRITE;
                 end
              end

              state_FINISH: begin
                 if (count_LCD == 1) begin
                    sensores_indice   <= 102;
                 end else begin
                    sensores_indice   <= 0;
                 end
                 state_controlador <= state_WRITE;
                 ADDR_CON <= 0;
              end
        endcase
  end
endmodule

