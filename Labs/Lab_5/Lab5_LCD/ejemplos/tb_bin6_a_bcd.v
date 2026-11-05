// =============================================================================
// tb_bin6_a_bcd.v
// Prueba exhaustiva del convertidor: recorre los 64 valores de entrada y
// compara con el resultado calculado con división y residuo (que en el
// testbench sí se pueden usar, porque no se sintetiza).
//
//   iverilog -o sim_bcd.vvp ejemplos/tb_bin6_a_bcd.v ejemplos/bin6_a_bcd.v
//   vvp sim_bcd.vvp
// =============================================================================
`timescale 1ns/1ps
module tb_bin6_a_bcd;
    reg  [5:0] bin;
    wire [3:0] decenas, unidades;

    bin6_a_bcd dut (.bin(bin), .decenas(decenas), .unidades(unidades));

    integer n, errores = 0;
    initial begin
        for (n = 0; n < 64; n = n + 1) begin
            bin = n;
            #10;                            // dar tiempo a la lógica combinacional
            if (decenas !== n / 10 || unidades !== n % 10) begin
                $display("ERROR: %0d -> %0d%0d", n, decenas, unidades);
                errores = errores + 1;
            end
        end
        // Algunos ejemplos en consola
        bin = 6'd7;  #10 $display("%2d -> BCD %b %b -> \"%0d%0d\"", bin, decenas, unidades, decenas, unidades);
        bin = 6'd42; #10 $display("%2d -> BCD %b %b -> \"%0d%0d\"", bin, decenas, unidades, decenas, unidades);
        bin = 6'd63; #10 $display("%2d -> BCD %b %b -> \"%0d%0d\"", bin, decenas, unidades, decenas, unidades);
        $display("64 valores probados, errores: %0d", errores);
        $finish;
    end
endmodule
