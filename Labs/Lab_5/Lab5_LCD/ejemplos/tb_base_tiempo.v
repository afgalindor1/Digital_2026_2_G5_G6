// =============================================================================
// tb_base_tiempo.v
// Prueba de base_tiempo con valores reducidos: reloj de 10 kHz y periodo de
// 2 ms, es decir, un pulso cada 20 ciclos. Además cuenta los pulsos, como lo
// haría un contador de segundos.
//
//   iverilog -o sim_bt.vvp ejemplos/tb_base_tiempo.v ejemplos/base_tiempo.v
//   vvp sim_bt.vvp
// =============================================================================
`timescale 1ns/1ps
module tb_base_tiempo;
    localparam CLK_FREQ   = 10_000;        // 10 kHz: periodo de reloj de 100 us
    localparam PERIODO_MS = 2;             // 2 ms = 20 ciclos
    localparam CICLOS     = (CLK_FREQ / 1000) * PERIODO_MS;

    reg  clk = 1'b0, rst = 1'b1;
    wire tick;
    always #50_000 clk = ~clk;             // medio periodo: 50 us

    base_tiempo #(.CLK_FREQ(CLK_FREQ), .PERIODO_MS(PERIODO_MS)) dut (
        .clk(clk), .rst(rst), .tick(tick)
    );

    // Contador de pulsos, como un contador de segundos
    reg [7:0] pulsos;
    always @(posedge clk)
        if (rst)       pulsos <= 0;
        else if (tick) pulsos <= pulsos + 1'b1;

    // Medición de la distancia entre pulsos, en ciclos de reloj
    integer ciclo = 0, ultimo = -1, errores = 0;
    always @(posedge clk) begin
        ciclo = ciclo + 1;
        if (tick) begin
            if (ultimo >= 0 && ciclo - ultimo != CICLOS) begin
                $display("ERROR: pulsos separados %0d ciclos (se esperaban %0d)", ciclo - ultimo, CICLOS);
                errores = errores + 1;
            end
            ultimo = ciclo;
        end
    end

    initial begin
        $dumpfile("tb_base_tiempo.vcd");
        $dumpvars(0, tb_base_tiempo);
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (10 * CICLOS + 1) @(posedge clk);   // 10 periodos (+1: tick es registrado)
        $display("Pulsos contados: %0d (se esperaban 10)", pulsos);
        if (pulsos != 10) errores = errores + 1;
        $display("Errores: %0d", errores);
        $finish;
    end
endmodule
