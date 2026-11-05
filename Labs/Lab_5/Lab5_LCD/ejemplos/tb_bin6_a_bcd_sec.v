// =============================================================================
// tb_bin6_a_bcd_sec.v
// Prueba exhaustiva del convertidor secuencial. Para cada valor: pone el
// número, da un pulso de un ciclo en iniciar, espera listo y compara.
// Muestra cómo manejar un handshake iniciar / listo desde un testbench.
//
//   iverilog -o sim_bcd_sec.vvp ejemplos/tb_bin6_a_bcd_sec.v ejemplos/bin6_a_bcd_sec.v
//   vvp sim_bcd_sec.vvp
//   gtkwave tb_bin6_a_bcd_sec.vcd
// =============================================================================
`timescale 1ns/1ps
module tb_bin6_a_bcd_sec;
    reg        clk = 1'b0, rst = 1'b1, iniciar = 1'b0;
    reg  [5:0] bin = 6'd0;
    wire [3:0] decenas, unidades;
    wire       listo;
    always #10 clk = ~clk;                   // 50 MHz

    bin6_a_bcd_sec dut (
        .clk(clk), .rst(rst), .iniciar(iniciar), .bin(bin),
        .decenas(decenas), .unidades(unidades), .listo(listo)
    );

    integer ciclos;

    // Convierte un valor siguiendo el handshake y devuelve cuántos ciclos tardó
    task convertir(input [5:0] valor);
        begin
            @(negedge clk);                  // cambiar entradas lejos del flanco de subida
            bin = valor;
            iniciar = 1'b1;
            @(negedge clk);
            iniciar = 1'b0;                  // pulso de un solo ciclo
            ciclos = 1;
            while (!listo) begin
                @(negedge clk);
                ciclos = ciclos + 1;
            end
        end
    endtask

    integer n, errores = 0;
    initial begin
        $dumpfile("tb_bin6_a_bcd_sec.vcd");
        $dumpvars(0, tb_bin6_a_bcd_sec);
        repeat (2) @(negedge clk);
        rst = 1'b0;

        for (n = 0; n < 64; n = n + 1) begin
            convertir(n);
            if (decenas !== n / 10 || unidades !== n % 10) begin
                $display("ERROR: %0d -> %0d%0d", n, decenas, unidades);
                errores = errores + 1;
            end
        end
        $display("Cada conversion tarda %0d ciclos desde iniciar hasta listo", ciclos);

        // Los resultados se mantienen después de listo
        convertir(6'd38);
        repeat (5) @(negedge clk);
        $display("38 -> \"%0d%0d\" (5 ciclos despues de listo)", decenas, unidades);
        if (decenas !== 4'd3 || unidades !== 4'd8) errores = errores + 1;

        $display("64 valores probados, errores: %0d", errores);
        $finish;
    end
endmodule
