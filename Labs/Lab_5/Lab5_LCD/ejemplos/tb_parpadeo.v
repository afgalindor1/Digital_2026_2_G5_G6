// =============================================================================
// tb_parpadeo.v
// Prueba de parpadeo.v con un reloj de 10 kHz: 1 ms = 10 ciclos.
// Con T_ON_MS = 2 y T_OFF_MS = 3, el LED debe estar 20 ciclos encendido y
// 30 ciclos apagado. El testbench mide cada tramo y lo compara.
//
//   iverilog -o sim_parpadeo.vvp ejemplos/tb_parpadeo.v ejemplos/parpadeo.v
//   vvp sim_parpadeo.vvp
//   gtkwave tb_parpadeo.vcd
// =============================================================================
`timescale 1ns/1ps
module tb_parpadeo;
    localparam CLK_FREQ = 10_000;           // 10 kHz: un ciclo dura 100 us
    localparam T_ON_MS  = 2;                // 20 ciclos
    localparam T_OFF_MS = 3;                // 30 ciclos

    reg  clk = 1'b0, rst = 1'b1;
    wire led;
    always #50_000 clk = ~clk;

    parpadeo #(.CLK_FREQ(CLK_FREQ), .T_ON_MS(T_ON_MS), .T_OFF_MS(T_OFF_MS)) dut (
        .clk(clk), .rst(rst), .led(led)
    );

    // Mide cuántos ciclos dura cada tramo encendido o apagado
    integer ciclos = 0, tramos = 0, errores = 0;
    reg     led_ant = 1'b0;
    always @(posedge clk) if (!rst) begin
        if (led != led_ant && ciclos > 0) begin
            tramos = tramos + 1;
            if (tramos > 2) begin           // el primer encendido es más corto: empieza durante el reset
                $display("LED %s durante %0d ciclos", led_ant ? "encendido" : "apagado  ", ciclos);
                if (ciclos != (led_ant ? 10 * T_ON_MS : 10 * T_OFF_MS)) errores = errores + 1;
            end
            ciclos = 0;
        end
        ciclos  = ciclos + 1;
        led_ant = led;
    end

    initial begin
        $dumpfile("tb_parpadeo.vcd");
        $dumpvars(0, tb_parpadeo);
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (200) @(posedge clk);        // cuatro periodos completos
        $display("Errores: %0d", errores);
        $finish;
    end
endmodule
