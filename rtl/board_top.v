`timescale 1ns / 1ps

module board_top (
    input  wire       sysclk,
    input  wire       btn,
    output wire [3:0] led
);
    wire clk50, locked;

    // MMCM generat de Clocking Wizard (clk_wiz_0), creat de scriptul Tcl
    clk_wiz_0 u_clk (
        .clk_in1 (sysclk),
        .clk_out1(clk50),
        .locked  (locked)
    );

    // reset nucleu: activ cat timp butonul e apasat SAU MMCM inca nu e blocat
    wire core_reset = btn | ~locked;

    fpga_top #(
        .ADDR_WIDTH (12),
        .RESULT_ADDR(32'h0000_0100),
        .MEM_FILE   ("fpga_demo.mem")
    ) u_soc (
        .clk      (clk50),
        .btn_reset(core_reset),
        .led      (led)
    );
endmodule
