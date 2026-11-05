// =============================================================================
// tb_semaforo.v
// Prueba de semaforo.v y espera.v con un reloj de 10 kHz (1 ms = 10 ciclos)
// y duraciones de 3, 1 y 2 ms (30, 10 y 20 ciclos). Imprime cada cambio de
// color con su duración y compara con lo esperado.
//
// Cada color dura 2 ciclos más que la espera pedida: uno para que espera.v
// reciba la orden (iniciar) y otro para que semaforo.v reciba el aviso (listo).
// En la LCD pasa lo mismo y no causa problemas, porque los tiempos de la hoja
// de datos son mínimos: esperar un poco más siempre es válido.
//
//   iverilog -o sim_semaforo.vvp ejemplos/tb_semaforo.v ejemplos/semaforo.v ejemplos/espera.v
//   vvp sim_semaforo.vvp
//   gtkwave tb_semaforo.vcd
// =============================================================================
`timescale 1ns/1ps
module tb_semaforo;
    localparam CLK_FREQ = 10_000;           // 10 kHz: un ciclo dura 100 us

    reg  clk = 1'b0, rst = 1'b1;
    wire verde, amarillo, rojo;
    always #50_000 clk = ~clk;

    semaforo #(.CLK_FREQ(CLK_FREQ), .T_VERDE_MS(3), .T_AMARILLO_MS(1), .T_ROJO_MS(2)) dut (
        .clk(clk), .rst(rst), .verde(verde), .amarillo(amarillo), .rojo(rojo)
    );

    // Duración esperada de cada color, en ciclos: la espera pedida + 2
    function integer esperado(input [1:0] e);
        case (e)
            2'd0:    esperado = 30 + 2;     // verde
            2'd1:    esperado = 10 + 2;     // amarillo
            default: esperado = 20 + 2;     // rojo
        endcase
    endfunction

    function [8*8-1:0] nombre(input [1:0] e);
        case (e)
            2'd0:    nombre = "VERDE";
            2'd1:    nombre = "AMARILLO";
            default: nombre = "ROJO";
        endcase
    endfunction

    integer ciclos = 0, cambios = 0, errores = 0;
    reg [1:0] estado_ant = 2'd0;
    always @(posedge clk) if (!rst) begin
        if (dut.estado != estado_ant) begin
            cambios = cambios + 1;
            // el primer verde no se mide: empieza durante el reset
            if (cambios > 1) begin
                $display("%-8s durante %0d ciclos", nombre(estado_ant), ciclos);
                if (ciclos != esperado(estado_ant)) errores = errores + 1;
            end
            ciclos = 0;
        end
        ciclos     = ciclos + 1;
        estado_ant = dut.estado;
    end

    initial begin
        $dumpfile("tb_semaforo.vcd");
        $dumpvars(0, tb_semaforo);
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (200) @(posedge clk);        // más de tres ciclos completos del semáforo
        $display("Errores: %0d", errores);
        $finish;
    end
endmodule
