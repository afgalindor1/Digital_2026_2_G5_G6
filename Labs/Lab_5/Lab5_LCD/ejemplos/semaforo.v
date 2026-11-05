// =============================================================================
// semaforo.v
// Módulo "maestro": un semáforo que pasa por VERDE, AMARILLO y ROJO. No cuenta
// el tiempo él mismo: en cada estado le pide al módulo espera.v que espere la
// duración de ese color, y cambia de estado cuando recibe listo.
//
//   VERDE --listo--> AMARILLO --listo--> ROJO --listo--> VERDE ...
//
// Es la misma organización que lcd_ctrl.v y lcd_escritura.v del código base:
//
//   +----------------------+   iniciar, ciclos   +----------------------+
//   | semaforo (maestro)   | ------------------> | espera (trabajador)  |
//   | qué hacer y cuándo   | <------------------ | cómo esperar         |
//   +----------------------+        listo        +----------------------+
//
// Handshake:
//   - iniciar: el maestro pide una espera (pulso de un ciclo), con la
//     duración ya puesta en "ciclos";
//   - listo:   el trabajador avisa que terminó (pulso de un ciclo).
//
// Cada color dura 2 ciclos más que la espera pedida: uno para pasar la orden
// y otro para recibir el aviso.
// =============================================================================
`timescale 1ns/1ps
module semaforo #(
    parameter CLK_FREQ = 50_000_000,        // Hz
    parameter T_VERDE_MS    = 3000,
    parameter T_AMARILLO_MS = 1000,
    parameter T_ROJO_MS     = 2000
)(
    input  wire clk,
    input  wire rst,                        // reset síncrono, activo en alto
    output wire verde,
    output wire amarillo,
    output wire rojo
);
    // ------------------------------------------------------------ duraciones en ciclos
    localparam ANCHO = 28;                  // debe coincidir con el ancho de espera.v
    localparam [ANCHO-1:0] C_VERDE    = (CLK_FREQ / 1000) * T_VERDE_MS;
    localparam [ANCHO-1:0] C_AMARILLO = (CLK_FREQ / 1000) * T_AMARILLO_MS;
    localparam [ANCHO-1:0] C_ROJO     = (CLK_FREQ / 1000) * T_ROJO_MS;

    // ------------------------------------------------------------ estados
    localparam VERDE    = 2'd0,
               AMARILLO = 2'd1,
               ROJO     = 2'd2;

    reg  [1:0] estado, siguiente;
    reg        iniciar;                     // orden para espera.v
    wire       listo;                       // aviso de espera.v

    // 1. Registro de estado
    always @(posedge clk)
        if (rst) estado <= VERDE;
        else     estado <= siguiente;

    // 2. Siguiente estado: se avanza cada vez que termina la espera
    always @(*) begin
        siguiente = estado;
        case (estado)
            VERDE:    if (listo) siguiente = AMARILLO;
            AMARILLO: if (listo) siguiente = ROJO;
            ROJO:     if (listo) siguiente = VERDE;
            default:             siguiente = VERDE;
        endcase
    end

    // Ruta de datos: duración que se pide en cada estado (multiplexor)
    reg [ANCHO-1:0] duracion;
    always @(*)
        case (estado)
            VERDE:    duracion = C_VERDE;
            AMARILLO: duracion = C_AMARILLO;
            default:  duracion = C_ROJO;
        endcase

    // Pedir una espera: al salir del reset y cada vez que llega listo.
    // iniciar sube un ciclo después de listo; para entonces el estado ya cambió,
    // así que "duracion" ya corresponde al nuevo color.
    reg en_reset;
    always @(posedge clk) en_reset <= rst;

    always @(posedge clk)
        if (rst) iniciar <= 1'b0;
        else     iniciar <= en_reset || listo;

    // 3. Salidas: un LED por estado
    assign verde    = (estado == VERDE);
    assign amarillo = (estado == AMARILLO);
    assign rojo     = (estado == ROJO);

    // Trabajador
    espera #(.ANCHO(ANCHO)) u_espera (
        .clk(clk), .rst(rst),
        .iniciar(iniciar), .ciclos(duracion), .listo(listo)
    );
endmodule
