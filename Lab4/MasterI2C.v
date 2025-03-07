module I2C_FPGA(
   input wire CLK,               // Reloj del divisor de frecuencia
   input wire RST,               // Reset asincrono 
   input wire START,             // Bit de inicio de maquina de estados
   input wire RW,                // Bit para escribir o leer  
   input wire [6:0] ADDR,        // Direccion del dispositivo (7 bits de direccion)
   input wire [4:0] AMOUNT_W,    // Cantidad de veces que va escribir 
   input wire [1:0] BYTE_INDEX,  // Cuantas veces se debe repetir la recepcion de datos
   input wire [7:0] DATA_WRITE1, // Primer byte de escritura 
   input wire [7:0] DATA_WRITE2, // Segundo byte de escritura 
   input wire [7:0] DATA_WRITE3, // Tercer byte de escritura 
   inout wire SDA,               // Linea serial de datos
   output wire SCL,              // Línea serial del clock
   output reg BUSY = 0,              // Indica si el maestro esta ocupado e una operacion
   output reg WRITE_READ,
   output reg [7:0] DATA_READ1,  // Primer byte de lectura 
   output reg [7:0] DATA_READ2,  // Segundo byte de lectura 
   output reg [7:0] DATA_READ3   // Tercer byte de lectura 
);
   localparam state_IDLE          = 0; // Estado ocioso
   localparam state_IDLE_REPEAT   = 1; // Estado ocioso de repeticion
   localparam state_START         = 2; // Empezar la comunicacion I2C
   localparam state_DELAY_START   = 3; // Permite empezar con un delay de n ciclos despues del start 
   localparam state_START_REPEAT  = 4; // Repetición de orden de inicio de I2C
   localparam state_DELAY_START_R = 5; // Permite empezar con un delay de n ciclos despues del start repeat (Tiempo para que el sensor pueda cargar los datos)
   localparam state_ADDR          = 6; // Estado para llamar al esclavo
   localparam state_RW            = 7; // Estado que envie el bit de escritura (0) o lectura (1)
   localparam state_ACK           = 8; // Señal de reconocimiento que puede enviar el maestro o el esclavo
   localparam state_WAIT_SCL      = 9; // Hacer clock streching para darle tiempo al sensor de responder 
   localparam state_DATA          = 10; // Guardas los bits de datos que envia el maestro o el sensor 
   localparam state_NACK          = 11; // Estado de no reconocimiento
   localparam state_STOP          = 12; // Parar la comunicacion I2C

   reg [4:0] state;      // Estados de la FSM 
   reg [4:0] count;      // Contador usado para añadir bits 
   reg [1:0] count_ADDR; // Contador usado para añadir la ultima posicion de un arreglo de bits
   reg [3:0] count_W;    // Contador para determinar cuantas veces voy a escribir 
   reg [7:0] WRITE;
   reg [1:0] count_W_R;  // Contador que me permite identificar si voy a escribir o leer 
   reg [1:0] count_DATA; // Contador para añadir los ocho espacios necesarios para que el sensor envie los ocho bits
   reg [1:0] byte_index; // Cuantos bytes me va a enviar el sensor 
   reg [1:0] count_NACK; // Contador para reconocer un "no reconoce" y que la maquina pase al estado NACK
   reg [9:0] delay;      // Contador para determinar cunatos ciclos SCL permanecera en 0 
   // Registro para guardar la direccion que se va a llamar
   reg [6:0] saved_addr;
   // Registro para guardar los bits a escribir
   reg [7:0] saved_data [0:2];
   // Registros internos para almacenamiento
   reg [7:0] storage1;
   reg [7:0] storage2;
   reg [7:0] storage3;

   reg [24:0] registro = 0; // Registro para almacenar todos los datos a enviar 

    // Guardar valores en el registro en orden
   always @(negedge CLK) begin
      if (RST)
         registro <= 24'b0;
      else begin
         registro[7:0]   <= DATA_WRITE1; // Primer dato a escribir
         registro[15:8]  <= DATA_WRITE2; // Segundo dato a escribir
         registro[23:16] <= DATA_WRITE3; // Tercer dato a escribir
         //registro[31:24] <= DATA_WRITE3; // Tercer dato a escribir
      end
   end

    // Multiplexor para seleccionar el dato de salida
   always @(negedge CLK) begin
      case (count_W)
             1 : WRITE = registro[7:0];    // Primer dato a escribir
             2 : WRITE = registro[15:8];   // Segundo dato a escribir
             3 : WRITE = registro[23:16];  // Tercer dato a escribir
             //3 : WRITE = registro[31:24]; // Tercer dato a escribir
             default: WRITE = 8'b0;
      endcase
   end


   // Señales para el control de SDA y SCL
   reg SCL_out = 1;
   reg SCL_en  = 0;
   reg SDA_out = 1; 
   reg SDA_en  = 1;

   // Tri-states para SDA y SCL
   assign SDA = (SDA_en) ? SDA_out : 1'bz; 
   assign SCL = (SCL_en == 0) ? SCL_out : CLK;

// Maquina de estados principal
   always @(negedge CLK) begin
      if (RST == 1) begin
         // Controladores de SDA y SCL
         SDA_en  <= 1; // La FPGA tiene el control del bus
         SDA_out <= 1; // Se queda en estado alto
         SCL_out <= 1; // SCL actua con normalidad
         SCL_en  <= 0;
         // Contadores
         count      <= 0; // Contador de bits para ADDRESS y DATA
         count_ADDR <= 0; // Me permite agregar el ultimo bit de direccion y registro
         count_W    <= 0; // Contador que me permite despues de manda la direccion el registro    
         WRITE_READ <= 1; // Controlador de si lectura (0) o Escritura (1)
         byte_index <= 0; // Cuantas veces repetira DATA
         delay      <= 0; // Tiempo de espera para respuesta del sensor
         count_DATA <= 0; // No extender el SCL para data
         count_NACK <= 0;
         //
         BUSY <= 0;
         //DATA_READ1 <= 0;
         //DATA_READ2 <= 0;
         //DATA_READ3 <= 0;
         // Almacenamientos
         storage1 <= 0;
         storage2 <= 0;
         storage3 <= 0;
      end else begin
         SDA_en  <= 1; // La FPGA tiene el control del bus
         SDA_out <= 1; // Se queda en estado alto
         SCL_out <= 1; // SCL actua con normalidad
         SCL_en  <= 1;
         state <= state_IDLE;
         if ((ADDR == 7'h76) && (DATA_WRITE1 == 8'hD0)) begin
            case(state)
            
                   state_IDLE : begin 
                      if (START == 1) begin // El bus esta desocupado
                         // Controladores de SDA y SCL 
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // Indicador de incio comunicacion I2C
                         SCL_en  <= 0; // SCL no sigue el clock
                         SCL_out <= 1; // SCL se queda en 1
                         // Guardar la dirección del sensor 
                         saved_addr <= ADDR;
                         // Cantidad de veces que se repetira DATA
                         byte_index <= BYTE_INDEX;
                         // Contadores 
                         count      <= 0;
                         count_ADDR <= 0;
                         count_W    <= 0;
                         WRITE_READ <= 1; // Empezamos Escribiendo
                         delay      <= 0; // Tiempo de espera para respuesta del sensor
                         count_DATA <= 0;
                         count_NACK <= 0;
                         // Almacenamientos
                         storage1   <= 0;
                         storage2   <= 0;
                         storage3   <= 0;
                         DATA_READ1 <= 0;
                         DATA_READ2 <= 0;
                         DATA_READ3 <= 0;
                         BUSY  <= 1;           // El bus SDA esta ocupado
                         state <= state_START; // Pasa a estado "START"
                      end else begin
                         BUSY <= 0;
                         state <= state_IDLE;
                      end
                   end 

                   state_START : begin 
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA tiene el control del bus
                      SDA_out <= 0; // Indicador de incio comunicacion I2C
                      SCL_en  <= 0; // SCL no sigue el clock
                      SCL_out <= 0; // SCL permanece en 0
                      delay   <= 1; 
                      state <= state_DELAY_START;
                   end

                   state_DELAY_START : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock       
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_W_R  <= 0;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START;             
                      end
                   end

                   state_IDLE_REPEAT : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en     <= 1; // La FPGA tiene el control del bus
                         SDA_out    <= 0; // Indicador de incio comunicacion I2C
                         SCL_en     <= 0; // SCL no sigue el clock
                         SCL_out    <= 1; // SCL se queda en 1
                         count_DATA <= 0; // Contador data en 0
                         if (BYTE_INDEX == 2) begin
                            byte_index <= 2; // 1 byte de datos
                         end else if (BYTE_INDEX == 1) begin
                            byte_index <= 1; // 2 bytes de datos
                         end else begin
                            byte_index <= 0; // 3 bytes de datos
                         end                     
                         state <= state_START_REPEAT; // Pasa a estado START REPEAT
                      end else begin 
                         SCL_out <= 1;
                         delay   <= delay - 1;
                         state   <= state_IDLE_REPEAT;
                      end
                   end

                   state_START_REPEAT : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1;  // La FPGA tiene el control de SDA
                      SDA_out <= 0;  // SDA permanece en 0
                      SCL_out <= 0;  // SCL no sigue al clock
                      SCL_en  <= 0;  // SCL permanece en cero
                      delay   <= 10; // Retardos para que el sensor pueda captar los datos
                      state <= state_DELAY_START_R;
                   end

                   state_DELAY_START_R : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock    
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START_R;
                      end        
                   end

                   state_ADDR : begin
                      // Mandar direccion y luego comando a escribir
                      if (count_W == 0) begin
                         SDA_out <= saved_addr[count]; // Guarda la direccion desde el segundo MSB al penultimo bit
                      end else if ((count_W > 0) && (count_W <= AMOUNT_W)) begin
                         SDA_out <= WRITE[count];
                      end
                      if ((count == 0) && (count_ADDR == 1) && (count_W == 0)) begin // Como el ultimo bit de dirección no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1; // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= saved_addr[0];  // SDA guarda el bit LMS de la dirección
                         state <= state_ADDR;          // Vuelve al mismo estado
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W == 0)) begin  // Ahora si pasamos al estado RW
                         count_W <= count_W + 1; // Aumentamos el contador para ahora escribir comandos
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;           // La FPGA tiene el control del bus              
                         SDA_out <= RW;          // SDA toma el valor de bit de escritura o lectura
                         SCL_en  <= 1;           // SCL sigue al clock
                         if (count_W_R == 0) begin
                            count_DATA <= count_DATA + 1;
                         end  
                         state   <= state_RW;    // Pasa al estado lectura o escritura
                      end else if ((count == 0) && (count_ADDR == 1) && (count_W > 0)) begin // Como el ultimo bit de comando no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1;  // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= WRITE[0];        // SDA guarda el bit LMS del Comando
                         if (count_W == AMOUNT_W) begin // Si el contador de escritura es el mismo que la cantidad de escrituras cambiar a lectura
                            count_W_R <= count_W_R + 1; // Cambiamos de estado escritura a estado lectura
                         end
                         state      <= state_ADDR;      // Vuelve al mismo estado 
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W > 0)) begin
                         if (count_W < AMOUNT_W) begin
                            count_W <= count_W + 1; 
                         end
                         // Controladores de SDA y SCL
                         SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                         SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                         SCL_out <= 1; // SCL sigue al clock
                         state <= state_ACK; // Pasa a estado de reconocimiento
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SCL_en  <= 1; // SCL sigue al clock
                         count <= count - 1;
                         state <= state_ADDR;
                      end
                   end
            
                   state_RW : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                      SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                      SCL_en  <= 1; // SCL sigue al clock 
                      state <= state_ACK; // Pasa a estado de reconocimiento
                   end

                   state_ACK : begin 
                     SCL_en  <= 0;               // SCL no sigue al clock
                     SCL_out <= 0;               // SCL se mantiene en 0
                     if (SDA == 0) begin
                        SDA_en <= 1;             // La FPGA controla SDA 
                        SDA_out <= 0;            // SDA permanece en 0
                     end
                      if (SDA == 1) begin        // Reconocimiento del NACK
                         count_NACK <= 1;         
                      end
                      DATA_READ1 <= storage1;
                      DATA_READ2 <= storage2;
                      delay   <= 0;              // Retraso de un ciclo
                      state   <= state_WAIT_SCL; // Pasa estado de esperar ACK
                   end
            
                   state_WAIT_SCL: begin
                      if ((SDA == 0) && (count_NACK == 0) && (delay == 0)) begin // Dar tiempo al sensor de responder mediante restrasos de tiempo
                         if (RW == 0) begin // Si vamos a escribir comandos
                            // Controladores de SDA y SCL
                            SDA_en     <= 1;        // La FPGA recupera el control de SDA
                            SDA_out    <= WRITE[7]; // SDA toma el primer bit MSB del comando
                            SCL_out    <= 1;        // SCL sigue al clock
                            // Contadores
                            count      <= 6; // Escribir los bits de registro hasta el penultimo
                            count_ADDR <= 1; // Para obtener el ultimo bit de registro
                            if (count_W_R == 0) begin // Si se esta escribiedndo
                               state <= state_ADDR;   // Pasar al estado direccion de nuevo
                            end else begin // Si se esta leyendo
                               // Controladores de SDA y SCL
                               SDA_en <=  1;    // La FPGA toma control del sensor 
                               SDA_out <= 1;    // SDA permanece en uno 
                               SCL_en  <= 0;    // SCL no sigue al clock
                               SCL_out <= 0;    // SCL permanece en cero
                               WRITE_READ <= 0; // Dejamos la condicion en escritura
                               delay <= 1;      // Aplicamos un retraso
                               state <= state_IDLE_REPEAT;
                            end     
                         end else begin        
                            count_ADDR <= 1;
                            count      <= 7; // Numero de byte de datos
                            // Controladores de SDA y SCL
                            SDA_en     <= 0; //* La FPGA deja libre el bus SDA (Simulacion (1), implementacion (0))
                            SCL_en     <= 1; // SCL sigue al clock
                            state <= state_DATA;  // Pasa al estado datos
                         end
                      end else if (count_NACK == 1) begin // Si el dispositivo manda un NACK pasar a estado NACK
                         //Controladores de SDA y SCL
                         SDA_en  <= 1; // La FPGA toma control de SDA
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_out <= 1; // SCL sigue el clock
                         state   <= state_NACK; // Para la trasnferencia 
                      end else if (SCL == 0) begin // Dar tiempo para que el dispositivo envie el ACK o el NACK
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;            // La FPGA no controla SDA
                         SDA_out <= 0;
                         SCL_en  <= 0;            // SCL no sigue al clock    
                         SCL_out <= 0;            // SCL permanece en cero              
                         delay   <= delay - 1;    // Finalizar el retardo
                         state <= state_WAIT_SCL; // Pasar de nuevo al estado 
                      end
                   end
            
                   state_DATA : begin
                      //SDA_out <= DATA_WRITE1[count]; //Prueba
                      if (RW == 1 && count < 8) begin // Leer los byte de datos
                         case (byte_index)            // Casos segun el número de byte_index
                                0: begin storage1[count] <= SDA; 
                                end
                                1: begin storage2[count] <= SDA; 
                                end
                                2: begin storage3[count] <= SDA; 
                                end
                         endcase
                      end
                      if (count == 0) begin
                         if (byte_index < 2) begin
                            byte_index <= byte_index + 1;
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 0; // SCL actua con normalidad   
                            state <= state_ACK;
                         end else begin
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 1; // SCL actua con normalidad   
                            WRITE_READ <= 1;
                            state <= state_NACK;
                         end
                      end else begin
                         SDA_en  <= 0; //* La FPGA no controla SDA
                         SCL_en  <= 1; // SCL sigue al clock
                         count   <= count - 1;
                         state   <= state_DATA;
                      end 
                   end 

                   state_NACK : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA recupera el control
                      SDA_out <= 1; // Preparar la linea para recibir condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      DATA_READ3 <= storage3;
                      BUSY    <= 0; // SDA ya no esta ocupado
                      state   <= state_STOP;
                   end 

                   state_STOP : begin  
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA controla el bus
                      SDA_out <= 1; // Deja la condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      state <= state_IDLE;
                   end 
            endcase
         end else if ((ADDR == 7'h76) && (DATA_WRITE1 == 8'hFA)) begin
            case(state)
            
                   state_IDLE : begin 
                      if (START == 1) begin // El bus esta desocupado
                         // Controladores de SDA y SCL 
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // Indicador de incio comunicacion I2C
                         SCL_en  <= 0; // SCL no sigue el clock
                         SCL_out <= 1; // SCL se queda en 1
                         // Guardar la dirección del sensor 
                         saved_addr <= ADDR;
                         // Cantidad de veces que se repetira DATA
                         byte_index <= BYTE_INDEX;
                         // Contadores 
                         count      <= 0;
                         count_ADDR <= 0;
                         count_W    <= 0;
                         WRITE_READ <= 1; // Empezamos Escribiendo
                         delay      <= 0; // Tiempo de espera para respuesta del sensor
                         count_DATA <= 0;
                         count_NACK <= 0;
                         // Almacenamientos
                         storage1   <= 0;
                         storage2   <= 0;
                         storage3   <= 0;
                         DATA_READ1 <= 0;
                         DATA_READ2 <= 0;
                         DATA_READ3 <= 0;
                         BUSY  <= 1;           // El bus SDA esta ocupado
                         state <= state_START; // Pasa a estado "START"
                      end else begin
                         BUSY <= 0;
                         state <= state_IDLE;
                      end
                   end 

                   state_START : begin 
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA tiene el control del bus
                      SDA_out <= 0; // Indicador de incio comunicacion I2C
                      SCL_en  <= 0; // SCL no sigue el clock
                      SCL_out <= 0; // SCL permanece en 0
                      delay   <= 1; 
                      state <= state_DELAY_START;
                   end

                   state_DELAY_START : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock       
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_W_R  <= 0;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START;             
                      end
                   end

                   state_IDLE_REPEAT : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en     <= 1; // La FPGA tiene el control del bus
                         SDA_out    <= 0; // Indicador de incio comunicacion I2C
                         SCL_en     <= 0; // SCL no sigue el clock
                         SCL_out    <= 1; // SCL se queda en 1
                         count_DATA <= 0; // Contador data en 0
                         if (BYTE_INDEX == 2) begin
                            byte_index <= 2; // 1 byte de datos
                         end else if (BYTE_INDEX == 1) begin
                            byte_index <= 1; // 2 bytes de datos
                         end else begin
                            byte_index <= 0; // 3 bytes de datos
                         end                     
                         state <= state_START_REPEAT; // Pasa a estado START REPEAT
                      end else begin 
                         SCL_out <= 1;
                         delay   <= delay - 1;
                         state   <= state_IDLE_REPEAT;
                      end
                   end

                   state_START_REPEAT : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1;  // La FPGA tiene el control de SDA
                      SDA_out <= 0;  // SDA permanece en 0
                      SCL_out <= 0;  // SCL no sigue al clock
                      SCL_en  <= 0;  // SCL permanece en cero
                      delay   <= 10; // Retardos para que el sensor pueda captar los datos
                      state <= state_DELAY_START_R;
                   end

                   state_DELAY_START_R : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock    
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START_R;
                      end        
                   end

                   state_ADDR : begin
                      // Mandar direccion y luego comando a escribir
                      if (count_W == 0) begin
                         SDA_out <= saved_addr[count]; // Guarda la direccion desde el segundo MSB al penultimo bit
                      end else if ((count_W > 0) && (count_W <= AMOUNT_W)) begin
                         SDA_out <= WRITE[count];
                      end
                      if ((count == 0) && (count_ADDR == 1) && (count_W == 0)) begin // Como el ultimo bit de dirección no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1; // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= saved_addr[0];  // SDA guarda el bit LMS de la dirección
                         state <= state_ADDR;          // Vuelve al mismo estado
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W == 0)) begin  // Ahora si pasamos al estado RW
                         count_W <= count_W + 1; // Aumentamos el contador para ahora escribir comandos
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;           // La FPGA tiene el control del bus              
                         SDA_out <= RW;          // SDA toma el valor de bit de escritura o lectura
                         SCL_en  <= 1;           // SCL sigue al clock
                         if (count_W_R == 0) begin
                            count_DATA <= count_DATA + 1;
                         end  
                         state   <= state_RW;    // Pasa al estado lectura o escritura
                      end else if ((count == 0) && (count_ADDR == 1) && (count_W > 0)) begin // Como el ultimo bit de comando no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1;  // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= WRITE[0];        // SDA guarda el bit LMS del Comando
                         if (count_W == AMOUNT_W) begin // Si el contador de escritura es el mismo que la cantidad de escrituras cambiar a lectura
                            count_W_R <= count_W_R + 1; // Cambiamos de estado escritura a estado lectura
                         end
                         state      <= state_ADDR;      // Vuelve al mismo estado 
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W > 0)) begin
                         if (count_W < AMOUNT_W) begin
                            count_W <= count_W + 1; 
                         end
                         // Controladores de SDA y SCL
                         SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                         SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                         SCL_out <= 1; // SCL sigue al clock
                         state <= state_ACK; // Pasa a estado de reconocimiento
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SCL_en  <= 1; // SCL sigue al clock
                         count <= count - 1;
                         state <= state_ADDR;
                      end
                   end
            
                   state_RW : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                      SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                      SCL_en  <= 1; // SCL sigue al clock 
                      state <= state_ACK; // Pasa a estado de reconocimiento
                   end

                   state_ACK : begin 
                     SCL_en  <= 0;               // SCL no sigue al clock
                     SCL_out <= 0;               // SCL se mantiene en 0
                     if (SDA == 0) begin
                        SDA_en <= 1;             // La FPGA controla SDA 
                        SDA_out <= 0;            // SDA permanece en 0
                     end
                      if (SDA == 1) begin        // Reconocimiento del NACK
                         count_NACK <= 1;         
                      end
                      DATA_READ1 <= storage1;
                      DATA_READ2 <= storage2;
                      delay   <= 0;              // Retraso de un ciclo
                      state   <= state_WAIT_SCL; // Pasa estado de esperar ACK
                   end
            
                   state_WAIT_SCL: begin
                      if ((SDA == 0) && (count_NACK == 0) && (delay == 0)) begin // Dar tiempo al sensor de responder mediante restrasos de tiempo
                         if (RW == 0) begin // Si vamos a escribir comandos
                            // Controladores de SDA y SCL
                            SDA_en     <= 1;        // La FPGA recupera el control de SDA
                            SDA_out    <= WRITE[7]; // SDA toma el primer bit MSB del comando
                            SCL_out    <= 1;        // SCL sigue al clock
                            // Contadores
                            count      <= 6; // Escribir los bits de registro hasta el penultimo
                            count_ADDR <= 1; // Para obtener el ultimo bit de registro
                            if (count_W_R == 0) begin // Si se esta escribiedndo
                               state <= state_ADDR;   // Pasar al estado direccion de nuevo
                            end else begin // Si se esta leyendo
                               // Controladores de SDA y SCL
                               SDA_en <=  1;    // La FPGA toma control del sensor 
                               SDA_out <= 1;    // SDA permanece en uno 
                               SCL_en  <= 0;    // SCL no sigue al clock
                               SCL_out <= 0;    // SCL permanece en cero
                               WRITE_READ <= 0; // Dejamos la condicion en escritura
                               delay <= 1;      // Aplicamos un retraso
                               state <= state_IDLE_REPEAT;
                            end     
                         end else begin        
                            count_ADDR <= 1;
                            count      <= 7; // Numero de byte de datos
                            // Controladores de SDA y SCL
                            SDA_en     <= 0; //* La FPGA deja libre el bus SDA (Simulacion (1), implementacion (0))
                            SCL_en     <= 1; // SCL sigue al clock
                            state <= state_DATA;  // Pasa al estado datos
                         end
                      end else if (count_NACK == 1) begin // Si el dispositivo manda un NACK pasar a estado NACK
                         //Controladores de SDA y SCL
                         SDA_en  <= 1; // La FPGA toma control de SDA
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_out <= 1; // SCL sigue el clock
                         state   <= state_NACK; // Para la trasnferencia 
                      end else if (SCL == 0) begin // Dar tiempo para que el dispositivo envie el ACK o el NACK
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;            // La FPGA no controla SDA
                         SDA_out <= 0;
                         SCL_en  <= 0;            // SCL no sigue al clock    
                         SCL_out <= 0;            // SCL permanece en cero              
                         delay   <= delay - 1;    // Finalizar el retardo
                         state <= state_WAIT_SCL; // Pasar de nuevo al estado 
                      end
                   end
            
                   state_DATA : begin
                      //SDA_out <= DATA_WRITE1[count]; //Prueba
                      if (RW == 1 && count < 8) begin // Leer los byte de datos
                         case (byte_index)            // Casos segun el número de byte_index
                                0: begin storage1[count] <= SDA; 
                                end
                                1: begin storage2[count] <= SDA; 
                                end
                                2: begin storage3[count] <= SDA; 
                                end
                         endcase
                      end
                      if (count == 0) begin
                         if (byte_index < 2) begin
                            byte_index <= byte_index + 1;
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 0; // SCL actua con normalidad   
                            state <= state_ACK;
                         end else begin
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 1; // SCL actua con normalidad   
                            WRITE_READ <= 1;
                            state <= state_NACK;
                         end
                      end else begin
                         SDA_en  <= 0; //* La FPGA no controla SDA
                         SCL_en  <= 1; // SCL sigue al clock
                         count   <= count - 1;
                         state   <= state_DATA;
                      end 
                   end 

                   state_NACK : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA recupera el control
                      SDA_out <= 1; // Preparar la linea para recibir condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      DATA_READ3 <= storage3;
                      BUSY    <= 0; // SDA ya no esta ocupado
                      state   <= state_STOP;
                   end 

                   state_STOP : begin  
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA controla el bus
                      SDA_out <= 1; // Deja la condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      state <= state_IDLE;
                   end 
            endcase
         end else if (ADDR == 7'h36) begin
            case(state)
            
                   state_IDLE : begin 
                      if (START == 1) begin // El bus esta desocupado
                         // Controladores de SDA y SCL 
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // Indicador de incio comunicacion I2C
                         SCL_en  <= 0; // SCL no sigue el clock
                         SCL_out <= 1; // SCL se queda en 1
                         // Guardar la dirección del sensor 
                         saved_addr <= ADDR;
                         // Cantidad de veces que se repetira DATA
                         byte_index <= BYTE_INDEX;
                         // Contadores 
                         count      <= 0;
                         count_ADDR <= 0;
                         count_W    <= 0;
                         WRITE_READ <= 1; // Empezamos Escribiendo
                         delay      <= 0; // Tiempo de espera para respuesta del sensor
                         count_DATA <= 0;
                         count_NACK <= 0;
                         // Almacenamientos
                         storage1   <= 0;
                         storage2   <= 0;
                         storage3   <= 0;
                         DATA_READ1 <= 0;
                         DATA_READ2 <= 0;
                         DATA_READ3 <= 0;
                         BUSY  <= 1;           // El bus SDA esta ocupado
                         state <= state_START; // Pasa a estado "START"
                      end else begin
                         BUSY <= 0;
                         state <= state_IDLE;
                      end
                   end 

                   state_START : begin 
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA tiene el control del bus
                      SDA_out <= 0; // Indicador de incio comunicacion I2C
                      SCL_en  <= 0; // SCL no sigue el clock
                      SCL_out <= 0; // SCL permanece en 0
                      delay   <= 1; 
                      state <= state_DELAY_START;
                   end

                   state_DELAY_START : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock       
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_W_R  <= 0;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START;             
                      end
                   end

                   state_IDLE_REPEAT : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en     <= 1; // La FPGA tiene el control del bus
                         SDA_out    <= 0; // Indicador de incio comunicacion I2C
                         SCL_en     <= 0; // SCL no sigue el clock
                         SCL_out    <= 1; // SCL se queda en 1
                         count_DATA <= 0; // Contador data en 0
                         if (BYTE_INDEX == 2) begin
                            byte_index <= 2; // 1 byte de datos
                         end else if (BYTE_INDEX == 1) begin
                            byte_index <= 1; // 2 bytes de datos
                         end else begin
                            byte_index <= 0; // 3 bytes de datos
                         end                     
                         state <= state_START_REPEAT; // Pasa a estado START REPEAT
                      end else begin 
                         SCL_out <= 1;
                         delay   <= delay - 1;
                         state   <= state_IDLE_REPEAT;
                      end
                   end

                   state_START_REPEAT : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1;  // La FPGA tiene el control de SDA
                      SDA_out <= 0;  // SDA permanece en 0
                      SCL_out <= 0;  // SCL no sigue al clock
                      SCL_en  <= 0;  // SCL permanece en cero
                      delay   <= 300; // Retardos para que el sensor pueda captar los datos
                      state <= state_DELAY_START_R;
                   end

                   state_DELAY_START_R : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock    
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START_R;
                      end        
                   end

                   state_ADDR : begin
                      // Mandar direccion y luego comando a escribir
                      if (count_W == 0) begin
                         SDA_out <= saved_addr[count]; // Guarda la direccion desde el segundo MSB al penultimo bit
                      end else if ((count_W > 0) && (count_W <= AMOUNT_W)) begin
                         SDA_out <= WRITE[count];
                      end
                      if ((count == 0) && (count_ADDR == 1) && (count_W == 0)) begin // Como el ultimo bit de dirección no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1; // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= saved_addr[0];  // SDA guarda el bit LMS de la dirección
                         state <= state_ADDR;          // Vuelve al mismo estado
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W == 0)) begin  // Ahora si pasamos al estado RW
                         count_W <= count_W + 1; // Aumentamos el contador para ahora escribir comandos
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;           // La FPGA tiene el control del bus              
                         SDA_out <= RW;          // SDA toma el valor de bit de escritura o lectura
                         SCL_en  <= 1;           // SCL sigue al clock
                         if (count_W_R == 0) begin
                            count_DATA <= count_DATA + 1;
                         end  
                         state   <= state_RW;    // Pasa al estado lectura o escritura
                      end else if ((count == 0) && (count_ADDR == 1) && (count_W > 0)) begin // Como el ultimo bit de comando no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1;  // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= WRITE[0];        // SDA guarda el bit LMS del Comando
                         if (count_W == AMOUNT_W) begin // Si el contador de escritura es el mismo que la cantidad de escrituras cambiar a lectura
                            count_W_R <= count_W_R + 1; // Cambiamos de estado escritura a estado lectura
                         end
                         state      <= state_ADDR;      // Vuelve al mismo estado 
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W > 0)) begin
                         if (count_W < AMOUNT_W) begin
                            count_W <= count_W + 1; 
                         end
                         // Controladores de SDA y SCL
                         SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                         SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                         SCL_out <= 1; // SCL sigue al clock
                         state <= state_ACK; // Pasa a estado de reconocimiento
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SCL_en  <= 1; // SCL sigue al clock
                         count <= count - 1;
                         state <= state_ADDR;
                      end
                   end
            
                   state_RW : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                      SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                      SCL_en  <= 1; // SCL sigue al clock 
                      state <= state_ACK; // Pasa a estado de reconocimiento
                   end

                   state_ACK : begin 
                     SCL_en  <= 0;               // SCL no sigue al clock
                     SCL_out <= 0;               // SCL se mantiene en 0
                     if (SDA == 0) begin
                        SDA_en <= 1;             // La FPGA controla SDA 
                        SDA_out <= 0;            // SDA permanece en 0
                     end
                      if (SDA == 1) begin        // Reconocimiento del NACK
                         count_NACK <= 1;         
                      end
                      DATA_READ1 <= storage1;
                      DATA_READ2 <= storage2;
                      delay   <= 0;              // Retraso de un ciclo
                      state   <= state_WAIT_SCL; // Pasa estado de esperar ACK
                   end
            
                   state_WAIT_SCL: begin
                      if ((SDA == 0) && (count_NACK == 0) && (delay == 0)) begin // Dar tiempo al sensor de responder mediante restrasos de tiempo
                         if (RW == 0) begin // Si vamos a escribir comandos
                            // Controladores de SDA y SCL
                            SDA_en     <= 1;        // La FPGA recupera el control de SDA
                            SDA_out    <= WRITE[7]; // SDA toma el primer bit MSB del comando
                            SCL_out    <= 1;        // SCL sigue al clock
                            // Contadores
                            count      <= 6; // Escribir los bits de registro hasta el penultimo
                            count_ADDR <= 1; // Para obtener el ultimo bit de registro
                            if (count_W_R == 0) begin // Si se esta escribiedndo
                               state <= state_ADDR;   // Pasar al estado direccion de nuevo
                            end else begin // Si se esta leyendo
                               // Controladores de SDA y SCL
                               SDA_en <=  1;    // La FPGA toma control del sensor 
                               SDA_out <= 1;    // SDA permanece en uno 
                               SCL_en  <= 0;    // SCL no sigue al clock
                               SCL_out <= 0;    // SCL permanece en cero
                               WRITE_READ <= 0; // Dejamos la condicion en escritura
                               delay <= 1;      // Aplicamos un retraso
                               state <= state_IDLE_REPEAT;
                            end     
                         end else begin        
                            count_ADDR <= 1;
                            count      <= 7; // Numero de byte de datos
                            // Controladores de SDA y SCL
                            SDA_en     <= 0; //* La FPGA deja libre el bus SDA (Simulacion (1), implementacion (0))
                            SCL_en     <= 1; // SCL sigue al clock
                            state <= state_DATA;  // Pasa al estado datos
                         end
                      end else if (count_NACK == 1) begin // Si el dispositivo manda un NACK pasar a estado NACK
                         //Controladores de SDA y SCL
                         SDA_en  <= 1; // La FPGA toma control de SDA
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_out <= 1; // SCL sigue el clock
                         state   <= state_NACK; // Para la trasnferencia 
                      end else if (SCL == 0) begin // Dar tiempo para que el dispositivo envie el ACK o el NACK
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;            // La FPGA no controla SDA
                         SDA_out <= 0;
                         SCL_en  <= 0;            // SCL no sigue al clock    
                         SCL_out <= 0;            // SCL permanece en cero              
                         delay   <= delay - 1;    // Finalizar el retardo
                         state <= state_WAIT_SCL; // Pasar de nuevo al estado 
                      end
                   end
            
                   state_DATA : begin
                      //SDA_out <= DATA_WRITE1[count]; //Prueba
                      if (RW == 1 && count < 8) begin // Leer los byte de datos
                         case (byte_index)            // Casos segun el número de byte_index
                                0: begin storage1[count] <= SDA; 
                                end
                                1: begin storage2[count] <= SDA; 
                                end
                                2: begin storage3[count] <= SDA; 
                                end
                         endcase
                      end
                      if (count == 0) begin
                         if (byte_index < 2) begin
                            byte_index <= byte_index + 1;
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 0; // SCL actua con normalidad   
                            state <= state_ACK;
                         end else begin
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 1; // SCL actua con normalidad   
                            WRITE_READ <= 1;
                            state <= state_NACK;
                         end
                      end else begin
                         SDA_en  <= 0; //* La FPGA no controla SDA
                         SCL_en  <= 1; // SCL sigue al clock
                         count   <= count - 1;
                         state   <= state_DATA;
                      end 
                   end 

                   state_NACK : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA recupera el control
                      SDA_out <= 1; // Preparar la linea para recibir condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      DATA_READ3 <= storage3;
                      BUSY    <= 0; // SDA ya no esta ocupado
                      state   <= state_STOP;
                   end 

                   state_STOP : begin  
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA controla el bus
                      SDA_out <= 1; // Deja la condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      state <= state_IDLE;
                   end 
            endcase
         end else if (ADDR == 7'h10) begin
            case(state)
            
                   state_IDLE : begin 
                      if (START == 1) begin // El bus esta desocupado
                         // Controladores de SDA y SCL 
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // Indicador de incio comunicacion I2C
                         SCL_en  <= 0; // SCL no sigue el clock
                         SCL_out <= 1; // SCL se queda en 1
                         // Guardar la dirección del sensor 
                         saved_addr <= ADDR;
                         // Cantidad de veces que se repetira DATA
                         byte_index <= BYTE_INDEX;
                         // Contadores 
                         count      <= 0;
                         count_ADDR <= 0;
                         count_W    <= 0;
                         WRITE_READ <= 1; // Empezamos Escribiendo
                         delay      <= 0; // Tiempo de espera para respuesta del sensor
                         count_DATA <= 0;
                         count_NACK <= 0;
                         // Almacenamientos
                         storage1   <= 0;
                         storage2   <= 0;
                         storage3   <= 0;
                         DATA_READ1 <= 0;
                         DATA_READ2 <= 0;
                         DATA_READ3 <= 0;
                         BUSY  <= 1;           // El bus SDA esta ocupado
                         state <= state_START; // Pasa a estado "START"
                      end else begin
                         BUSY <= 0;
                         state <= state_IDLE;
                      end
                   end 

                   state_START : begin 
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA tiene el control del bus
                      SDA_out <= 0; // Indicador de incio comunicacion I2C
                      SCL_en  <= 0; // SCL no sigue el clock
                      SCL_out <= 0; // SCL permanece en 0
                      delay   <= 1; 
                      state <= state_DELAY_START;
                   end

                   state_DELAY_START : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock       
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_W_R  <= 0;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START;             
                      end
                   end

                   state_IDLE_REPEAT : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en     <= 1; // La FPGA tiene el control del bus
                         SDA_out    <= 0; // Indicador de incio comunicacion I2C
                         SCL_en     <= 0; // SCL no sigue el clock
                         SCL_out    <= 1; // SCL se queda en 1
                         count_DATA <= 0; // Contador data en 0
                         if (BYTE_INDEX == 2) begin
                            byte_index <= 2; // 1 byte de datos
                         end else if (BYTE_INDEX == 1) begin
                            byte_index <= 1; // 2 bytes de datos
                         end else begin
                            byte_index <= 0; // 3 bytes de datos
                         end                     
                         state <= state_START_REPEAT; // Pasa a estado START REPEAT
                      end else begin 
                         SCL_out <= 1;
                         delay   <= delay - 1;
                         state   <= state_IDLE_REPEAT;
                      end
                   end

                   state_START_REPEAT : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1;  // La FPGA tiene el control de SDA
                      SDA_out <= 0;  // SDA permanece en 0
                      SCL_out <= 0;  // SCL no sigue al clock
                      SCL_en  <= 0;  // SCL permanece en cero
                      delay   <= 10; // Retardos para que el sensor pueda captar los datos
                      state <= state_DELAY_START_R;
                   end

                   state_DELAY_START_R : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock    
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START_R;
                      end        
                   end

                   state_ADDR : begin
                      // Mandar direccion y luego comando a escribir
                      if (count_W == 0) begin
                         SDA_out <= saved_addr[count]; // Guarda la direccion desde el segundo MSB al penultimo bit
                      end else if ((count_W > 0) && (count_W <= AMOUNT_W)) begin
                         SDA_out <= WRITE[count];
                      end
                      if ((count == 0) && (count_ADDR == 1) && (count_W == 0)) begin // Como el ultimo bit de dirección no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1; // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= saved_addr[0];  // SDA guarda el bit LMS de la dirección
                         state <= state_ADDR;          // Vuelve al mismo estado
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W == 0)) begin  // Ahora si pasamos al estado RW
                         count_W <= count_W + 1; // Aumentamos el contador para ahora escribir comandos
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;           // La FPGA tiene el control del bus              
                         SDA_out <= RW;          // SDA toma el valor de bit de escritura o lectura
                         SCL_en  <= 1;           // SCL sigue al clock
                         if (count_W_R == 0) begin
                            count_DATA <= count_DATA + 1;
                         end  
                         state   <= state_RW;    // Pasa al estado lectura o escritura
                      end else if ((count == 0) && (count_ADDR == 1) && (count_W > 0)) begin // Como el ultimo bit de comando no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1;  // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= WRITE[0];        // SDA guarda el bit LMS del Comando
                         if (count_W == AMOUNT_W) begin // Si el contador de escritura es el mismo que la cantidad de escrituras cambiar a lectura
                            count_W_R <= count_W_R + 1; // Cambiamos de estado escritura a estado lectura
                         end
                         state      <= state_ADDR;      // Vuelve al mismo estado 
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W > 0)) begin
                         if (count_W < AMOUNT_W) begin
                            count_W <= count_W + 1; 
                         end
                         // Controladores de SDA y SCL
                         SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                         SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                         SCL_out <= 1; // SCL sigue al clock
                         state <= state_ACK; // Pasa a estado de reconocimiento
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SCL_en  <= 1; // SCL sigue al clock
                         count <= count - 1;
                         state <= state_ADDR;
                      end
                   end
            
                   state_RW : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 0; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                      SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                      SCL_en  <= 1; // SCL sigue al clock 
                      state <= state_ACK; // Pasa a estado de reconocimiento
                   end

                   state_ACK : begin 
                     SCL_en  <= 0;               // SCL no sigue al clock
                     SCL_out <= 0;               // SCL se mantiene en 0
                     if (SDA == 0) begin
                        SDA_en <= 1;             // La FPGA controla SDA 
                        SDA_out <= 0;            // SDA permanece en 0
                     end
                      if (SDA == 1) begin        // Reconocimiento del NACK
                         count_NACK <= 1;         
                      end
                      DATA_READ1 <= storage1;
                      DATA_READ2 <= storage2;
                      delay   <= 0;              // Retraso de un ciclo
                      state   <= state_WAIT_SCL; // Pasa estado de esperar ACK
                   end
            
                   state_WAIT_SCL: begin
                      if ((SDA == 0) && (count_NACK == 0) && (delay == 0)) begin // Dar tiempo al sensor de responder mediante restrasos de tiempo
                         if (RW == 0) begin // Si vamos a escribir comandos
                            // Controladores de SDA y SCL
                            SDA_en     <= 1;        // La FPGA recupera el control de SDA
                            SDA_out    <= WRITE[7]; // SDA toma el primer bit MSB del comando
                            SCL_out    <= 1;        // SCL sigue al clock
                            // Contadores
                            count      <= 6; // Escribir los bits de registro hasta el penultimo
                            count_ADDR <= 1; // Para obtener el ultimo bit de registro
                            if (count_W_R == 0) begin // Si se esta escribiedndo
                               state <= state_ADDR;   // Pasar al estado direccion de nuevo
                            end else begin // Si se esta leyendo
                               // Controladores de SDA y SCL
                               SDA_en <=  1;    // La FPGA toma control del sensor 
                               SDA_out <= 1;    // SDA permanece en uno 
                               SCL_en  <= 0;    // SCL no sigue al clock
                               SCL_out <= 0;    // SCL permanece en cero
                               WRITE_READ <= 0; // Dejamos la condicion en escritura
                               delay <= 1;      // Aplicamos un retraso
                               state <= state_IDLE_REPEAT;
                            end     
                         end else begin        
                            count_ADDR <= 1;
                            count      <= 7; // Numero de byte de datos
                            // Controladores de SDA y SCL
                            SDA_en     <= 0; //* La FPGA deja libre el bus SDA (Simulacion (1), implementacion (0))
                            SCL_en     <= 1; // SCL sigue al clock
                            state <= state_DATA;  // Pasa al estado datos
                         end
                      end else if (count_NACK == 1) begin // Si el dispositivo manda un NACK pasar a estado NACK
                         //Controladores de SDA y SCL
                         SDA_en  <= 1; // La FPGA toma control de SDA
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_out <= 1; // SCL sigue el clock
                         state   <= state_NACK; // Para la trasnferencia 
                      end else if (SCL == 0) begin // Dar tiempo para que el dispositivo envie el ACK o el NACK
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;            // La FPGA no controla SDA
                         SDA_out <= 0;
                         SCL_en  <= 0;            // SCL no sigue al clock    
                         SCL_out <= 0;            // SCL permanece en cero              
                         delay   <= delay - 1;    // Finalizar el retardo
                         state <= state_WAIT_SCL; // Pasar de nuevo al estado 
                      end
                   end
            
                   state_DATA : begin
                      //SDA_out <= DATA_WRITE1[count]; //Prueba
                      if (RW == 1 && count < 8) begin // Leer los byte de datos
                         case (byte_index)            // Casos segun el número de byte_index
                                0: begin storage1[count] <= SDA; 
                                end
                                1: begin storage2[count] <= SDA; 
                                end
                                2: begin storage3[count] <= SDA; 
                                end
                         endcase
                      end
                      if (count == 0) begin
                         if (byte_index < 2) begin
                            byte_index <= byte_index + 1;
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 0; // SCL actua con normalidad   
                            state <= state_ACK;
                         end else begin
                            // Controladores de SDA y SCL
                            SDA_en  <= 1; // La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                            SDA_out <= 0; // Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                            SCL_out <= 1; // SCL actua con normalidad   
                            WRITE_READ <= 1;
                            state <= state_NACK;
                         end
                      end else begin
                         SDA_en  <= 0; //* La FPGA no controla SDA
                         SCL_en  <= 1; // SCL sigue al clock
                         count   <= count - 1;
                         state   <= state_DATA;
                      end 
                   end 

                   state_NACK : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA recupera el control
                      SDA_out <= 1; // Preparar la linea para recibir condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      DATA_READ3 <= storage3;
                      BUSY    <= 0; // SDA ya no esta ocupado
                      state   <= state_STOP;
                   end 

                   state_STOP : begin  
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA controla el bus
                      SDA_out <= 1; // Deja la condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      state <= state_IDLE;
                   end 
            endcase
         end else if (ADDR == 7'h27) begin
            case(state)
            
                   state_IDLE : begin 
                      if (START == 1) begin // El bus esta desocupado
                         // Controladores de SDA y SCL 
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // Indicador de incio comunicacion I2C
                         SCL_en  <= 0; // SCL no sigue el clock
                         SCL_out <= 1; // SCL se queda en 1
                         // Guardar la dirección del sensor 
                         saved_addr <= ADDR;
                         // Cantidad de veces que se repetira DATA
                         byte_index <= BYTE_INDEX;
                         // Contadores 
                         count      <= 0;
                         count_ADDR <= 0;
                         count_W    <= 0;
                         WRITE_READ <= 1; // Empezamos Escribiendo
                         delay      <= 0; // Tiempo de espera para respuesta del sensor
                         count_DATA <= 0;
                         count_NACK <= 0;
                         // Almacenamientos
                         storage1 <= 0;
                         storage2 <= 0;
                         storage3 <= 0;
                         DATA_READ1 <= 0;
                         DATA_READ2 <= 0;
                         DATA_READ3 <= 0;
                         BUSY  <= 1;           // El bus SDA esta ocupado
                         state <= state_START; // Pasa a estado "START"
                      end else begin
                         BUSY <= 0;
                         state <= state_IDLE;
                      end
                   end 

                   state_START : begin 
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA tiene el control del bus
                      SDA_out <= 0; // Indicador de incio comunicacion I2C
                      SCL_en  <= 0; // SCL no sigue el clock
                      SCL_out <= 0; // SCL permanece en 0
                      delay   <= 1; 
                      state <= state_DELAY_START;
                   end

                   state_DELAY_START : begin
                      if (delay == 0) begin
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;              // La FPGA tiene el control del bus
                         SDA_out <= saved_addr[6];  // SDA guarda el primer bit MSB de direccion
                         SCL_en  <= 1;              // SCL sigue al clock       
                         // Contadores 
                         count      <= 5;
                         count_W    <= 0;
                         count_ADDR <= 1;
                         count_W_R  <= 0;
                         count_NACK <= 0;
                         state      <= state_ADDR; // Pasa a estado direccion
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_en  <= 0; // SCL no sigue al clock
                         SCL_out <= 0; // SCL permanece en 0
                         delay <= delay - 1; 
                         state <= state_DELAY_START;             
                      end
                   end

                   state_ADDR : begin
                      // Mandar direccion y luego comando a escribir
                      if (count_W == 0) begin
                         SDA_out <= saved_addr[count]; // Guarda la direccion desde el segundo MSB al penultimo bit
                      end else if ((count_W > 0) && (count_W <= AMOUNT_W)) begin
                         SDA_out <= WRITE[count];
                      end
                      if ((count == 0) && (count_ADDR == 1) && (count_W == 0)) begin // Como el ultimo bit de dirección no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1; // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= saved_addr[0];  // SDA guarda el bit LMS de la dirección
                         state <= state_ADDR;          // Vuelve al mismo estado
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W == 0)) begin  // Ahora si pasamos al estado RW
                         count_W <= count_W + 1; // Aumentamos el contador para ahora escribir comandos
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;           // La FPGA tiene el control del bus              
                         SDA_out <= RW;          // SDA toma el valor de bit de escritura o lectura
                         SCL_en  <= 1;           // SCL sigue al clock
                         if (count_W_R == 0) begin
                            count_DATA <= count_DATA + 1;
                         end  
                         state   <= state_RW;    // Pasa al estado lectura o escritura
                      end else if ((count == 0) && (count_ADDR == 1) && (count_W > 0)) begin // Como el ultimo bit de comando no se guarda, lo forzamos a guardarse con estas condiciones
                         count_ADDR <= count_ADDR - 1;  // Disminuye el contador de guardar ultimo bit
                         SDA_out    <= WRITE[0];        // SDA guarda el bit LMS del Comando
                         if (count_W == AMOUNT_W) begin // Si el contador de escritura es el mismo que la cantidad de escrituras cambiar a lectura
                            count_NACK <= count_NACK + 1; // Terminamos la escritura
                         end
                         state      <= state_ADDR;      // Vuelve al mismo estado 
                      end else if ((count == 0) && (count_ADDR == 0) && (count_W > 0)) begin
                         if (count_W < AMOUNT_W) begin
                            count_W <= count_W + 1; 
                         end
                         // Controladores de SDA y SCL
                         SDA_en  <= 1; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                         SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                         SCL_out <= 1; // SCL sigue al clock
                         state <= state_ACK; // Pasa a estado de reconocimiento
                      end else begin
                         // Controladores de SDA y SCL   
                         SDA_en  <= 1; // La FPGA tiene el control del bus
                         SCL_en  <= 1; // SCL sigue al clock
                         count <= count - 1;
                         state <= state_ADDR;
                      end
                   end
            
                   state_RW : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; //* La FPGA suelta el bus (Para pruebas simulacion (hacer 1), para implementacion (hacer 0))   
                      SDA_out <= 0; //* Este valor no importa en teoria (Pero para implementacion dejar en (1) y para probar codigo dejar en (0))
                      SCL_en  <= 1; // SCL sigue al clock 
                      state <= state_ACK; // Pasa a estado de reconocimiento
                   end

                   state_ACK : begin 
                     SCL_en  <= 0;               // SCL no sigue al clock
                     SCL_out <= 0;               // SCL se mantiene en 0
                     if (SDA == 0) begin
                        SDA_en <= 1;             // La FPGA controla SDA 
                        SDA_out <= 0;            // SDA permanece en 0
                     end
                      if (SDA == 1) begin        // Reconocimiento del NACK
                         count_NACK <= 1;         
                      end
                      DATA_READ1 <= storage1;
                      DATA_READ2 <= storage2;
                      delay   <= 0;              // Retraso de un ciclo
                      state   <= state_WAIT_SCL; // Pasa estado de esperar ACK
                   end
            
                   state_WAIT_SCL: begin
                      if ((SDA == 0) && (count_NACK == 0) && (delay == 0)) begin // Dar tiempo al sensor de responder mediante restrasos de tiempo
                         if (RW == 0) begin // Si vamos a escribir comandos
                            // Controladores de SDA y SCL
                            SDA_en     <= 1;        // La FPGA recupera el control de SDA
                            SDA_out    <= WRITE[7]; // SDA toma el primer bit MSB del comando
                            SCL_out    <= 1;        // SCL sigue al clock
                            // Contadores
                            count      <= 6; // Escribir los bits de registro hasta el penultimo
                            count_ADDR <= 1; // Para obtener el ultimo bit de registro
                            if (count_W_R == 0) begin // Si se esta escribiedndo
                               state <= state_ADDR;   // Pasar al estado direccion de nuevo
                            end else begin // Si se esta leyendo
                               // Controladores de SDA y SCL
                               SDA_en <=  1;    // La FPGA toma control del sensor 
                               SDA_out <= 1;    // SDA permanece en uno 
                               SCL_en  <= 0;    // SCL no sigue al clock
                               SCL_out <= 0;    // SCL permanece en cero
                               WRITE_READ <= 0; // Dejamos la condicion en escritura
                               delay <= 1;      // Aplicamos un retraso
                               state <= state_IDLE_REPEAT;
                            end     
                         end
                      end else if (count_NACK == 1) begin // Si el dispositivo manda un NACK pasar a estado NACK
                         //Controladores de SDA y SCL
                         SDA_en  <= 1; // La FPGA toma control de SDA
                         SDA_out <= 0; // SDA permanece en 0
                         SCL_out <= 1; // SCL sigue el clock
                         state   <= state_NACK; // Para la trasnferencia 
                      end else if (SCL == 0) begin // Dar tiempo para que el dispositivo envie el ACK o el NACK
                         // Controladores de SDA y SCL
                         SDA_en  <= 1;            // La FPGA no controla SDA
                         SDA_out <= 0;
                         SCL_en  <= 0;            // SCL no sigue al clock    
                         SCL_out <= 0;            // SCL permanece en cero              
                         delay   <= delay - 1;    // Finalizar el retardo
                         state <= state_WAIT_SCL; // Pasar de nuevo al estado 
                      end
                   end                  
                   state_NACK : begin
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA recupera el control
                      SDA_out <= 1; // Preparar la linea para recibir condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      DATA_READ3 <= storage3;
                      BUSY    <= 0; // SDA ya no esta ocupado
                      state   <= state_STOP;
                   end 

                   state_STOP : begin  
                      // Controladores de SDA y SCL
                      SDA_en  <= 1; // La FPGA controla el bus
                      SDA_out <= 1; // Deja la condicion de STOP
                      SCL_en  <= 0; // SCL no sigue al clock
                      SCL_out <= 1; // SCL permanece en 1
                      state <= state_IDLE;
                   end 
            endcase
         end
      end
   end
endmodule

