// =============================================================================
// tb_lcd.v
// Testbench del controlador de la LCD 16x2 (Parte 1).
//
// Conecta lcd_ctrl al modelo de la pantalla, espera a que termine de escribir
// y compara lo que muestra el modelo con el texto de los parámetros LINEA1 y
// LINEA2. Se simula con el reloj real de 50 MHz para que el modelo pueda revisar
// los tiempos de la hoja de datos (unos 55 ms de tiempo simulado).
//
//   iverilog -o sim.vvp test/tb_lcd.v test/modelo_lcd.v src/lcd_ctrl.v src/lcd_escritura.v
//   vvp sim.vvp
//   gtkwave tb_lcd.vcd
// =============================================================================
`timescale 1ns/1ps
module tb_lcd;
    localparam CLK_FREQ = 50_000_000;
    localparam [8*16-1:0] TXT1 = "Electronica Dig.";
    localparam [8*16-1:0] TXT2 = "  LCD 16x2 OK   ";

    reg clk = 1'b0, rst = 1'b1;
    always #10 clk = ~clk;                       // 50 MHz

    wire       lcd_rs, lcd_rw, lcd_e;
    wire [7:0] lcd_data;

    lcd_ctrl #(.CLK_FREQ(CLK_FREQ), .LINEA1(TXT1), .LINEA2(TXT2)) dut (
        .clk(clk), .rst(rst),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_e(lcd_e), .lcd_data(lcd_data)
    );

    modelo_lcd lcd (.rs(lcd_rs), .rw(lcd_rw), .e(lcd_e), .data(lcd_data));

    // Compara una fila del modelo con el texto esperado
    integer fallas = 0;
    task revisar_fila(input integer fila, input [8*16-1:0] esperado);
        integer k;
        reg ok;
        begin
            ok = 1'b1;
            for (k = 0; k < 16; k = k + 1)
                if (lcd.caracter(fila, k) !== esperado[8*(15-k) +: 8]) ok = 1'b0;
            if (ok) $display("OK    fila %0d = \"%s\"", fila + 1, esperado);
            else begin
                $display("FALLO fila %0d: se esperaba \"%s\"", fila + 1, esperado);
                fallas = fallas + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_lcd.vcd");
        // Solo las señales útiles: con el reloj incluido el archivo crece mucho
        $dumpvars(0, lcd_rs, lcd_rw, lcd_e, lcd_data,
                  dut.estado, dut.idx, dut.col, dut.iniciar, dut.listo,
                  dut.u_escritura.estado);

        #200 rst = 1'b0;

        // Espera a que el controlador llegue al estado FIN (máximo 100 ms)
        while (dut.estado != dut.FIN && $realtime < 100_000_000) #1000;
        #100_000;                                // deja terminar la última instrucción

        lcd.imprimir_pantalla;
        revisar_fila(0, TXT1);
        revisar_fila(1, TXT2);
        if (dut.estado != dut.FIN) begin
            $display("FALLO el controlador no llego a FIN");
            fallas = fallas + 1;
        end
        if (lcd.errores != 0) begin
            $display("FALLO el modelo de la LCD reporto %0d errores de protocolo o de tiempo", lcd.errores);
            fallas = fallas + 1;
        end
        $display("Tiempo total: %0.2f ms   Fallas: %0d", $realtime / 1e6, fallas);
        $finish;
    end
endmodule
