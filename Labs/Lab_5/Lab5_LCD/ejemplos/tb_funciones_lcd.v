// =============================================================================
// tb_funciones_lcd.v
// Prueba de las funciones de funciones_lcd.v: imprime algunos resultados y
// los compara con el valor esperado.
//
//   iverilog -o sim_fun.vvp ejemplos/tb_funciones_lcd.v ejemplos/funciones_lcd.v
//   vvp sim_fun.vvp
// =============================================================================
`timescale 1ns/1ps
module tb_funciones_lcd;
    funciones_lcd f ();                      // instancia solo para llamar sus funciones

    integer errores = 0;

    task comparar(input [8*24-1:0] nombre, input [7:0] obtenido, input [7:0] esperado);
        begin
            if (obtenido === esperado)
                $display("OK     %0s = 0x%h = %b", nombre, obtenido, obtenido);
            else begin
                $display("ERROR  %0s = 0x%h, se esperaba 0x%h", nombre, obtenido, esperado);
                errores = errores + 1;
            end
        end
    endtask

    localparam [8*16-1:0] TEXTO = "Hola, FPGA 2026!";

    initial begin
        $display("--- Set DDRAM Address");
        comparar("dir_ddram(0, 0)",  f.dir_ddram(1'b0, 4'd0),  8'h80);
        comparar("dir_ddram(0, 15)", f.dir_ddram(1'b0, 4'd15), 8'h8F);
        comparar("dir_ddram(1, 0)",  f.dir_ddram(1'b1, 4'd0),  8'hC0);
        comparar("dir_ddram(1, 5)",  f.dir_ddram(1'b1, 4'd5),  8'hC5);

        $display("--- Digitos y hexadecimal");
        comparar("ascii_digito(4)",  f.ascii_digito(4'd4), "4");
        comparar("ascii_hex(4'h9)",  f.ascii_hex(4'h9),    "9");
        comparar("ascii_hex(4'hA)",  f.ascii_hex(4'hA),    "A");
        comparar("ascii_hex(4'hF)",  f.ascii_hex(4'hF),    "F");
        comparar("ascii_bit(1)",     f.ascii_bit(1'b1),    "1");

        $display("--- Caracteres de un texto: \"%s\"", TEXTO);
        comparar("caracter(TEXTO, 0)",  f.caracter(TEXTO, 4'd0),  "H");
        comparar("caracter(TEXTO, 6)",  f.caracter(TEXTO, 4'd6),  "F");
        comparar("caracter(TEXTO, 15)", f.caracter(TEXTO, 4'd15), "!");

        $display("Errores: %0d", errores);
        $finish;
    end
endmodule
