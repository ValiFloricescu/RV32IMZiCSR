`timescale 1ns/1ps
module tb_fpga_top;
    reg clk = 0, btn_reset = 1;
    wire [3:0] led;
    always #5 clk = ~clk;

    fpga_top #(.ADDR_WIDTH(12), .MEM_FILE("sw/fpga_demo.mem")) dut (
        .clk(clk), .btn_reset(btn_reset), .led(led)
    );

    integer i;
    initial begin
        // tine reset apasat cateva cicluri, apoi elibereaza
        repeat (5) @(posedge clk);
        btn_reset = 0;
        // ruleaza
        repeat (300) @(posedge clk);
        $display("result_reg = %0d (0x%08x)", dut.result_reg, dut.result_reg);
        $display("led        = %04b (0x%01x)", led, led);
        if (dut.result_reg === 32'd55 && led === 4'h7)
            $display(">>> PASS <<< (suma 1..10 = 55, LED-uri = 0111)");
        else
            $display(">>> FAIL <<<");
        $finish;
    end
endmodule
