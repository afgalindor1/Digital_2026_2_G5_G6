// =============================================================================
// lcd_ctrl.v
// Controlador de una LCD 16x2 en modo 8 bits: inicializa la pantalla y escribe
// un texto fijo de 16 caracteres en cada fila.
//
// Unidad de control: máquina de estados (Moore) que recorre la secuencia
//   ESPERA_ENCENDIDO -> CONFIG -> DIR_LINEA1 -> LINEA1 -> DIR_LINEA2 -> LINEA2 -> FIN
// Ruta de datos: contador de espera, índice de comandos, índice de columna,
// memoria de comandos, texto de cada fila y multiplexor del byte a enviar.
// Cada byte se envía con el módulo lcd_escritura (señales iniciar / listo).
// =============================================================================
`timescale 1ns/1ps
module lcd_ctrl #(
    parameter CLK_FREQ = 50_000_000,                 // frecuencia del reloj en Hz
    parameter [8*16-1:0] LINEA1 = "Electronica Dig.",// exactamente 16 caracteres
    parameter [8*16-1:0] LINEA2 = "  LCD 16x2 OK   " // exactamente 16 caracteres
)(
    input  wire       clk,
    input  wire       rst,
    output wire       lcd_rs,
    output wire       lcd_rw,
    output wire       lcd_e,
    output wire [7:0] lcd_data
);
    // ------------------------------------------------------------ instrucciones
    localparam CMD_FUNCION = 8'h38;   // Function Set: 8 bits, 2 líneas, 5x8 puntos
    localparam CMD_DISPLAY = 8'h0C;   // Display ON, cursor OFF, parpadeo OFF
    localparam CMD_BORRAR  = 8'h01;   // Clear Display (ejecución larga)
    localparam CMD_ENTRADA = 8'h06;   // Entry Mode: incrementa dirección, sin desplazar
    localparam CMD_LINEA1  = 8'h80;   // Set DDRAM Address 0x00 (fila 1, columna 0)
    localparam CMD_LINEA2  = 8'hC0;   // Set DDRAM Address 0x40 (fila 2, columna 0)

    // ------------------------------------------------------------ espera inicial
    localparam T_ENCENDIDO = CLK_FREQ / 20;          // 50 ms (> 40 ms de la hoja de datos)
    localparam WE          = $clog2(T_ENCENDIDO);
    localparam [WE-1:0] MAX_ESPERA = T_ENCENDIDO[WE-1:0] - 1'b1;

    // ------------------------------------------------------------ estados
    localparam ESPERA_ENCENDIDO = 3'd0,
               CONFIG           = 3'd1,
               DIR_LINEA1       = 3'd2,
               LINEA1_TXT       = 3'd3,
               DIR_LINEA2       = 3'd4,
               LINEA2_TXT       = 3'd5,
               FIN              = 3'd6;

    reg  [2:0]    estado, siguiente;
    reg  [WE-1:0] espera;            // contador de la espera de encendido
    reg  [2:0]    idx;               // número de comando de configuración (0 a 4)
    reg  [3:0]    col;               // columna del carácter (0 a 15)
    reg           iniciar;           // orden de escritura para lcd_escritura
    wire          listo;             // lcd_escritura terminó una escritura

    wire fin_espera = (espera == MAX_ESPERA);

    // La secuencia avanza al terminar la espera inicial o al terminar cada escritura
    wire avanzar = (estado == ESPERA_ENCENDIDO) ? fin_espera : listo;

    // ------------------------------------------------------------ 1. registro de estado
    always @(posedge clk)
        if (rst) estado <= ESPERA_ENCENDIDO;
        else     estado <= siguiente;

    // ------------------------------------------------------------ 2. siguiente estado
    always @(*) begin
        siguiente = estado;
        case (estado)
            ESPERA_ENCENDIDO: if (fin_espera)              siguiente = CONFIG;
            CONFIG:           if (listo && idx == 3'd4)    siguiente = DIR_LINEA1;
            DIR_LINEA1:       if (listo)                   siguiente = LINEA1_TXT;
            LINEA1_TXT:       if (listo && col == 4'd15)   siguiente = DIR_LINEA2;
            DIR_LINEA2:       if (listo)                   siguiente = LINEA2_TXT;
            LINEA2_TXT:       if (listo && col == 4'd15)   siguiente = FIN;
            FIN:                                           siguiente = FIN;
            default:                                       siguiente = ESPERA_ENCENDIDO;
        endcase
    end

    // ------------------------------------------------------------ ruta de datos
    // Contador de la espera de encendido
    always @(posedge clk)
        if (rst || estado != ESPERA_ENCENDIDO) espera <= 0;
        else                                   espera <= espera + 1'b1;

    // Índices: avanzan cada vez que termina una escritura del grupo actual
    always @(posedge clk)
        if (rst) begin
            idx <= 3'd0;
            col <= 4'd0;
        end else if (listo) begin
            if (estado == CONFIG)                            idx <= idx + 1'b1;
            if (estado == LINEA1_TXT || estado == LINEA2_TXT) col <= col + 1'b1;  // 15 -> 0
        end

    // Se pide una escritura nueva un ciclo después de avanzar, salvo al llegar a FIN
    always @(posedge clk)
        if (rst) iniciar <= 1'b0;
        else     iniciar <= avanzar && (siguiente != FIN);

    // Memoria de comandos de configuración
    reg [7:0] cmd_config;
    always @(*)
        case (idx)
            3'd0:    cmd_config = CMD_FUNCION;     // la hoja de datos envía Function Set dos veces
            3'd1:    cmd_config = CMD_FUNCION;
            3'd2:    cmd_config = CMD_DISPLAY;
            3'd3:    cmd_config = CMD_BORRAR;
            default: cmd_config = CMD_ENTRADA;
        endcase

    // Carácter de la columna c de una fila (el primer carácter está en los bits altos)
    function [7:0] caracter(input [8*16-1:0] linea, input [3:0] c);
        caracter = linea[8*(15 - c) +: 8];
    endfunction

    // ------------------------------------------------------------ 3. salidas
    // Multiplexor del byte a enviar y del tipo (RS) según el estado
    reg       rs_sel;
    reg [7:0] dato_sel;
    always @(*) begin
        rs_sel   = 1'b0;
        dato_sel = 8'h00;
        case (estado)
            CONFIG:     dato_sel = cmd_config;
            DIR_LINEA1: dato_sel = CMD_LINEA1;
            LINEA1_TXT: begin rs_sel = 1'b1; dato_sel = caracter(LINEA1, col); end
            DIR_LINEA2: dato_sel = CMD_LINEA2;
            LINEA2_TXT: begin rs_sel = 1'b1; dato_sel = caracter(LINEA2, col); end
            default:    ;
        endcase
    end

    wire espera_larga = (estado == CONFIG) && (cmd_config == CMD_BORRAR);

    assign lcd_rw = 1'b0;            // solo se escribe en la LCD

    lcd_escritura #(.CLK_FREQ(CLK_FREQ)) u_escritura (
        .clk(clk), .rst(rst),
        .iniciar(iniciar), .rs_in(rs_sel), .dato_in(dato_sel), .espera_larga(espera_larga),
        .lcd_rs(lcd_rs), .lcd_e(lcd_e), .lcd_data(lcd_data), .listo(listo)
    );
endmodule
