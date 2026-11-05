// =============================================================================
// lcd_top.v
// Módulo superior para la tarjeta Cyclone IV: conecta el controlador a la LCD.
// Los pulsadores de la tarjeta son activos en bajo, por eso el reset se invierte.
// =============================================================================
`timescale 1ns/1ps
module lcd_top (
    input  wire       clk,          // reloj de 50 MHz (pin 23)
    input  wire       rst_n,        // pulsador de reset, activo en bajo
    output wire       lcd_rs,
    output wire       lcd_rw,
    output wire       lcd_e,
    output wire [7:0] lcd_data
);
    lcd_ctrl #(
        .CLK_FREQ(50_000_000),
        .LINEA1  ("Electronica Dig."),     // cambiar por el texto del grupo
        .LINEA2  ("  LCD 16x2 OK   ")      // (exactamente 16 caracteres)
    ) u_lcd (
        .clk(clk), .rst(~rst_n),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_e(lcd_e), .lcd_data(lcd_data)
    );
endmodule
