// =============================================================================
// tb_revisar_pantalla.v
// Ejemplo de testbench que revisa una parte de la pantalla: n caracteres a
// partir de una fila y una columna. Es útil cuando solo interesa un campo de
// la pantalla, por ejemplo un número escrito en unas columnas fijas.
//
// Usa el controlador del código base (src/lcd_ctrl.v) con un texto de prueba
// y el modelo de la pantalla (test/modelo_lcd.v).
//
// Muestra tres técnicas:
//   1. Esperar a que el modelo haya recibido un número de escrituras, en lugar
//      de esperar un estado del controlador (sirve aunque la máquina nunca
//      llegue a un estado final, como en un lazo de refresco).
//   2. Leer la pantalla del modelo con lcd.caracter(fila, columna).
//   3. Pasar a una tarea un texto más corto que el vector que lo recibe.
//
// Se simula con el reloj real de 50 MHz: el modelo revisa los tiempos de la
// hoja de datos, así que CLK_FREQ debe coincidir con el reloj del testbench.
//
//   iverilog -o sim_rev.vvp ejemplos/tb_revisar_pantalla.v test/modelo_lcd.v src/lcd_ctrl.v src/lcd_escritura.v
//   vvp sim_rev.vvp
// =============================================================================
`timescale 1ns/1ps
module tb_revisar_pantalla;
    reg clk = 1'b0, rst = 1'b1;
    always #10 clk = ~clk;                       // 50 MHz

    wire       lcd_rs, lcd_rw, lcd_e;
    wire [7:0] lcd_data;

    lcd_ctrl #(
        .CLK_FREQ(50_000_000),
        .LINEA1  ("Grupo 7: Prueba "),
        .LINEA2  ("Temp:   23 C    ")
    ) dut (
        .clk(clk), .rst(rst),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_e(lcd_e), .lcd_data(lcd_data)
    );

    modelo_lcd lcd (.rs(lcd_rs), .rw(lcd_rw), .e(lcd_e), .data(lcd_data));

    // -------------------------------------------------------------------------
    // Compara n caracteres de la pantalla, desde (fila, columna), con un texto.
    // fila y columna empiezan en 0. Un texto entre comillas más corto que
    // el vector se completa con ceros a la izquierda, así que sus n caracteres
    // quedan en los 8*n bits menos significativos.
    // -------------------------------------------------------------------------
    integer fallas = 0;
    task revisar_texto(input integer fila, input integer columna,
                       input [8*16-1:0] esperado, input integer n);
        integer k;
        reg [8*16-1:0] visto;
        begin
            visto = 0;
            for (k = 0; k < n; k = k + 1)
                visto[8*(n-1-k) +: 8] = lcd.caracter(fila, columna + k);
            if (visto === esperado)
                $display("OK     fila %0d, columnas %0d a %0d: \"%0s\"",
                         fila + 1, columna, columna + n - 1, visto);
            else begin
                $display("FALLO  fila %0d, columnas %0d a %0d: se esperaba \"%0s\" y se ve \"%0s\"",
                         fila + 1, columna, columna + n - 1, esperado, visto);
                fallas = fallas + 1;
            end
        end
    endtask

    initial begin
        #200 rst = 1'b0;

        // 1. Esperar 5 instrucciones de configuración + 2 de posición + 32 caracteres
        wait (lcd.escrituras == 39);
        #100_000;                                // la última escritura termina de ejecutarse

        lcd.imprimir_pantalla;

        // 2 y 3. Revisar campos de la pantalla
        revisar_texto(0, 0,  "Grupo 7", 7);      // fila 1, columnas 0 a 6
        revisar_texto(1, 8,  "23", 2);           // fila 2, columnas 8 y 9
        revisar_texto(1, 11, "C", 1);            // fila 2, columna 11
        revisar_texto(1, 8,  "24", 2);           // este caso falla a propósito

        if (lcd.errores != 0) fallas = fallas + 1;
        $display("Fallas: %0d (se espera 1: el caso que falla a proposito)", fallas);
        $finish;
    end
endmodule
