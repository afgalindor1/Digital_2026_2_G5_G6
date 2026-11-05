// =============================================================================
// lcd_escritura.v
// Ciclo de escritura en una LCD 16x2 (controlador HD44780 / ST7066U), modo 8 bits.
//
// Cuando recibe un pulso en "iniciar":
//   1. Pone RS y el byte en el bus de datos (PREPARAR).
//   2. Genera un pulso en E; la LCD captura el byte en el flanco de bajada (PULSO_E).
//   3. Espera el tiempo de ejecución de la instrucción (EJECUTAR).
//   4. Avisa con un pulso de un ciclo en "listo" y vuelve a REPOSO.
//
// Tiempos usados (hoja de datos: tPW >= 140 ns, tC >= 1200 ns,
// ejecución 39-43 us para casi todas las instrucciones y 1,53 ms para Clear y Home):
//   preparación   1 us
//   pulso de E    1 us
//   ejecución     50 us  (espera_larga = 0)
//                 2 ms   (espera_larga = 1)
// =============================================================================
`timescale 1ns/1ps
module lcd_escritura #(
    parameter CLK_FREQ = 50_000_000          // frecuencia del reloj en Hz
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       iniciar,               // pulso de un ciclo: comenzar escritura
    input  wire       rs_in,                 // 0: instrucción, 1: carácter
    input  wire [7:0] dato_in,               // código de la instrucción o del carácter
    input  wire       espera_larga,          // 1 para Clear Display y Return Home
    output reg        lcd_rs,
    output reg        lcd_e,
    output reg  [7:0] lcd_data,
    output reg        listo                  // pulso de un ciclo al terminar
);
    // ------------------------------------------------------------ tiempos en ciclos
    localparam CICLOS_US = CLK_FREQ / 1_000_000;    // ciclos en 1 us
    localparam T_PREP    = 1    * CICLOS_US;        // 1 us
    localparam T_PULSO   = 1    * CICLOS_US;        // 1 us
    localparam T_CORTA   = 50   * CICLOS_US;        // 50 us
    localparam T_LARGA   = 2000 * CICLOS_US;        // 2 ms
    localparam W         = $clog2(T_LARGA);         // bits del contador de tiempo

    // Último valor de la cuenta en cada estado (con el ancho del contador)
    localparam [W-1:0] MAX_PREP  = T_PREP[W-1:0] - 1'b1;
    localparam [W-1:0] MAX_PULSO = T_PULSO[W-1:0] - 1'b1;
    localparam [W-1:0] MAX_CORTA = T_CORTA[W-1:0] - 1'b1;
    localparam [W-1:0] MAX_LARGA = T_LARGA[W-1:0] - 1'b1;

    // ------------------------------------------------------------ estados
    localparam REPOSO   = 2'd0,
               PREPARAR = 2'd1,
               PULSO_E  = 2'd2,
               EJECUTAR = 2'd3;

    reg [1:0]   estado, siguiente;
    reg [W-1:0] cuenta;                  // ciclos transcurridos en el estado actual
    reg         larga;                   // copia de espera_larga para esta escritura

    // Fin del tiempo de cada estado
    wire fin_prep  = (cuenta == MAX_PREP);
    wire fin_pulso = (cuenta == MAX_PULSO);
    wire fin_ejec  = (cuenta == (larga ? MAX_LARGA : MAX_CORTA));

    // 1. Registro de estado
    always @(posedge clk)
        if (rst) estado <= REPOSO;
        else     estado <= siguiente;

    // 2. Lógica de siguiente estado
    always @(*) begin
        siguiente = estado;
        case (estado)
            REPOSO:   if (iniciar)   siguiente = PREPARAR;
            PREPARAR: if (fin_prep)  siguiente = PULSO_E;
            PULSO_E:  if (fin_pulso) siguiente = EJECUTAR;
            EJECUTAR: if (fin_ejec)  siguiente = REPOSO;
            default:                 siguiente = REPOSO;
        endcase
    end

    // Contador de tiempo: vuelve a cero cada vez que cambia el estado
    always @(posedge clk)
        if (rst || estado != siguiente) cuenta <= 0;
        else                            cuenta <= cuenta + 1'b1;

    // Registro del dato: se captura al iniciar y se mantiene durante todo el ciclo
    always @(posedge clk)
        if (rst) begin
            lcd_rs   <= 1'b0;
            lcd_data <= 8'h00;
            larga    <= 1'b0;
        end else if (estado == REPOSO && iniciar) begin
            lcd_rs   <= rs_in;
            lcd_data <= dato_in;
            larga    <= espera_larga;
        end

    // 3. Lógica de salida (registrada para evitar glitches en E)
    always @(posedge clk)
        if (rst) begin
            lcd_e <= 1'b0;
            listo <= 1'b0;
        end else begin
            lcd_e <= (siguiente == PULSO_E);
            listo <= (estado == EJECUTAR) && fin_ejec;
        end
endmodule
