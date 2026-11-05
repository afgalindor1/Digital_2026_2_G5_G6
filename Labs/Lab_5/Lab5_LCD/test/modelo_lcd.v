// =============================================================================
// modelo_lcd.v  (solo para simulación)
// Modelo de comportamiento de una LCD 16x2 con controlador HD44780 / ST7066U.
//
// - Captura cada byte en el flanco de bajada de E, como la pantalla real.
// - Interpreta las instrucciones de la hoja de datos y guarda los caracteres
//   en una DDRAM de 128 posiciones (fila 1: 0x00-0x0F, fila 2: 0x40-0x4F).
// - Revisa los tiempos de la hoja de datos y cuenta los errores:
//     espera de 40 ms después del encendido, ancho del pulso E >= 140 ns,
//     ciclo de E >= 1200 ns, dato estable >= 40 ns antes de bajar E,
//     y no escribir mientras la instrucción anterior se ejecuta.
// - La tarea imprimir_pantalla muestra en consola lo que se vería en la LCD.
//   Los caracteres personalizados (códigos 0x00 a 0x0F) se imprimen como '*'.
// - Guarda los caracteres personalizados en una CGRAM de 64 bytes
//   (Set CGRAM Address y escrituras de datos), sin dibujarlos.
// - No modela el desplazamiento de la pantalla (Cursor/Display Shift con
//   S/C = 1, ni Entry Mode Set con S = 1): la ventana visible no se mueve.
//
// Las unidades de tiempo del modelo son nanosegundos (`timescale 1ns/1ps).
// =============================================================================
`timescale 1ns/1ps
module modelo_lcd (
    input wire       rs,
    input wire       rw,
    input wire       e,
    input wire [7:0] data
);
    // Tiempos de la hoja de datos, en ns
    localparam real T_ENCENDIDO = 40_000_000.0;   // 40 ms
    localparam real T_PW        = 140.0;          // ancho mínimo de E
    localparam real T_CICLO     = 1200.0;         // ciclo mínimo de E
    localparam real T_DSW       = 40.0;           // setup del dato
    localparam real T_EJEC      = 39_000.0;       // 39 us (43 us para datos)
    localparam real T_EJEC_DATO = 43_000.0;
    localparam real T_EJEC_LARGA= 1_530_000.0;    // 1,53 ms (Clear, Home)

    reg [7:0] ddram [0:127];
    reg [6:0] ac;                 // contador de direcciones
    reg       incrementa;         // Entry Mode: 1 = incrementa
    reg       display_on;
    reg       modo_8bits, dos_lineas;
    reg       configurada;        // ya recibió Function Set de 8 bits y 2 líneas
    reg [7:0] cgram [0:63];       // caracteres personalizados: 8 caracteres x 8 filas
    reg [5:0] ac_cg;              // dirección de la CGRAM
    reg       en_cgram;           // 1: los datos van a la CGRAM (después de Set CGRAM Address)

    integer errores;              // errores de protocolo o de tiempo
    integer escrituras;           // bytes recibidos
    real    t_subida, t_bajada_ant, t_libre, t_cambio;
    reg     e_alto;               // E pasó de 0 a 1 (descarta transiciones desde x al inicio)

    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1) ddram[i] = 8'h20;   // espacios
        for (i = 0; i < 64; i = i + 1) cgram[i] = 8'h00;
        ac = 0; ac_cg = 0; en_cgram = 0; incrementa = 1; display_on = 0;
        modo_8bits = 0; dos_lineas = 0; configurada = 0;
        errores = 0; escrituras = 0; e_alto = 0;
        t_subida = -1.0e9; t_bajada_ant = -1.0e9; t_libre = T_ENCENDIDO; t_cambio = 0.0;
    end

    // Momento del último cambio de RS o del dato (para revisar el setup)
    always @(data or rs) t_cambio = $realtime;

    // Flanco de subida de E
    always @(posedge e) begin
        e_alto   = (e === 1'b1);
        t_subida = $realtime;
        if ($realtime < T_ENCENDIDO) begin
            $display("[LCD] ERROR t=%0.3f ms: escritura antes de 40 ms desde el encendido", $realtime/1e6);
            errores = errores + 1;
        end else if ($realtime < t_libre) begin
            $display("[LCD] ERROR t=%0.3f ms: escritura mientras la instruccion anterior se ejecuta (faltan %0.1f us)",
                     $realtime/1e6, (t_libre - $realtime)/1e3);
            errores = errores + 1;
        end
    end

    // Flanco de bajada de E: la LCD captura el byte
    always @(negedge e) if (e_alto) begin
        e_alto     = 1'b0;
        escrituras = escrituras + 1;
        if ($realtime - t_subida < T_PW) begin
            $display("[LCD] ERROR t=%0.3f ms: pulso E de %0.0f ns (minimo %0.0f ns)",
                     $realtime/1e6, $realtime - t_subida, T_PW);
            errores = errores + 1;
        end
        if ($realtime - t_bajada_ant < T_CICLO) begin
            $display("[LCD] ERROR t=%0.3f ms: ciclo de E de %0.0f ns (minimo %0.0f ns)",
                     $realtime/1e6, $realtime - t_bajada_ant, T_CICLO);
            errores = errores + 1;
        end
        if ($realtime - t_cambio < T_DSW) begin
            $display("[LCD] ERROR t=%0.3f ms: RS o dato cambiaron %0.0f ns antes de bajar E (minimo %0.0f ns)",
                     $realtime/1e6, $realtime - t_cambio, T_DSW);
            errores = errores + 1;
        end
        if (rw !== 1'b0) begin
            $display("[LCD] ERROR t=%0.3f ms: R/W debe ser 0 (solo escritura)", $realtime/1e6);
            errores = errores + 1;
        end
        if (^{rs, data} === 1'bx) begin
            $display("[LCD] ERROR t=%0.3f ms: RS o dato indefinidos (x/z)", $realtime/1e6);
            errores = errores + 1;
        end
        t_bajada_ant = $realtime;
        if (rs) escribir_dato(data);
        else    ejecutar_instruccion(data);
    end

    // Avanza el contador de direcciones como lo hace el HD44780 en modo de 2 líneas
    task avanzar_ac;
        begin
            if (incrementa) ac = (ac == 7'h27) ? 7'h40 : (ac == 7'h67) ? 7'h00 : ac + 1'b1;
            else            ac = (ac == 7'h00) ? 7'h67 : (ac == 7'h40) ? 7'h27 : ac - 1'b1;
        end
    endtask

    task escribir_dato(input [7:0] c);
        begin
            if (!configurada) begin
                $display("[LCD] ERROR t=%0.3f ms: se escribio un caracter antes de configurar la pantalla",
                         $realtime/1e6);
                errores = errores + 1;
            end
            if (en_cgram) begin
                cgram[ac_cg] = c;
                ac_cg = incrementa ? ac_cg + 1'b1 : ac_cg - 1'b1;
            end else begin
                ddram[ac] = c;
                avanzar_ac;
            end
            t_libre = $realtime + T_EJEC_DATO;
        end
    endtask

    task ejecutar_instruccion(input [7:0] c);
        begin
            t_libre = $realtime + T_EJEC;
            casez (c)
                8'b0000_0001: begin                              // Clear Display
                    for (i = 0; i < 128; i = i + 1) ddram[i] = 8'h20;
                    ac = 0; incrementa = 1; en_cgram = 0;
                    t_libre = $realtime + T_EJEC_LARGA;
                end
                8'b0000_001?: begin                              // Return Home
                    ac = 0; en_cgram = 0;
                    t_libre = $realtime + T_EJEC_LARGA;
                end
                8'b0000_01??: incrementa = c[1];                 // Entry Mode Set
                8'b0000_1???: display_on = c[2];                 // Display ON/OFF
                8'b0001_0???: begin                              // Cursor Shift (S/C = 0)
                    if (c[2]) ac = (ac == 7'h27) ? 7'h40 : (ac == 7'h67) ? 7'h00 : ac + 1'b1;
                    else      ac = (ac == 7'h00) ? 7'h67 : (ac == 7'h40) ? 7'h27 : ac - 1'b1;
                end
                8'b0001_1???: ;                                  // Display Shift (no se modela)
                8'b001?_????: begin                              // Function Set
                    modo_8bits = c[4];
                    dos_lineas = c[3];
                    if (!c[4]) begin
                        $display("[LCD] ERROR t=%0.3f ms: Function Set en modo 4 bits (la tarjeta usa 8 bits)",
                                 $realtime/1e6);
                        errores = errores + 1;
                    end
                    configurada = c[4] & c[3];
                end
                8'b01??_????: begin ac_cg = c[5:0]; en_cgram = 1; end  // Set CGRAM Address
                8'b1???_????: begin ac = c[6:0]; en_cgram = 0; end    // Set DDRAM Address
                default: ;                                       // 0x00: sin efecto
            endcase
        end
    endtask

    // Carácter visible en una posición (fila 0 o 1, columna 0 a 15)
    function [7:0] caracter(input integer fila, input integer columna);
        caracter = ddram[(fila ? 7'h40 : 7'h00) + columna];
    endfunction

    // Imprime en consola lo que mostraría la pantalla
    task imprimir_pantalla;
        integer f, k;
        reg [8*16-1:0] texto;
        begin
            $display("        +----------------+");
            for (f = 0; f < 2; f = f + 1) begin
                for (k = 0; k < 16; k = k + 1)
                    texto[8*(15-k) +: 8] = (caracter(f, k) < 8'h10) ? "*" : caracter(f, k);
                $display("  LCD   |%s|", texto);
            end
            $display("        +----------------+  display %0s, %0d escrituras, %0d errores",
                     display_on ? "encendido" : "APAGADO", escrituras, errores);
        end
    endtask
endmodule
