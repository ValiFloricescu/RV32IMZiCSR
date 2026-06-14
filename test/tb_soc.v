`timescale 1ns / 1ps
// ============================================================
//  tb_soc.v  -  Bring-up complet SoC (imita PS-ul Zynq)
// ------------------------------------------------------------
//  Flux:
//    1) CPU in reset; PS incarca prog5 in memorie prin AXI4-Lite;
//    2) PS porneste CPU-ul (cpu_resetn=1);
//    3) CPU calculeaza suma 1..10 = 55 si o scrie la 0x100;
//    4) PS citeste 0x100 prin AXI si verifica = 55.
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_soc.vcd"
`endif
`ifndef PROG_HEX
 `define PROG_HEX "sw/prog5.hex"
`endif

module tb_soc;

    localparam ADDR_WIDTH = 12;
    reg clk = 1'b0, rst_n, cpu_resetn;
    integer errors = 0, i;
    always #5 clk = ~clk;

    reg  [ADDR_WIDTH-1:0] awaddr, araddr;
    reg  [31:0]           wdata;
    reg  [3:0]            wstrb;
    reg                   awvalid, wvalid, bready, arvalid, rready;
    wire                  awready, wready, bvalid, arready, rvalid;
    wire [1:0]            bresp, rresp;
    wire [31:0]           rdata;

    soc_top #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .cpu_resetn(cpu_resetn),
        .s_axi_awaddr(awaddr), .s_axi_awprot(3'b0), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(3'b0), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    task axi_write;
        input [ADDR_WIDTH-1:0] addr; input [31:0] data; input [3:0] strb;
        begin
            @(negedge clk); awaddr=addr; wdata=data; wstrb=strb; awvalid=1; wvalid=1;
            do @(posedge clk); while (!(awready && wready));
            @(negedge clk); awvalid=0; wvalid=0; bready=1;
            do @(posedge clk); while (!bvalid);
            @(negedge clk); bready=0;
        end
    endtask

    task axi_read;
        input  [ADDR_WIDTH-1:0] addr; output [31:0] data;
        begin
            @(negedge clk); araddr=addr; arvalid=1;
            do @(posedge clk); while (!arready);
            @(negedge clk); arvalid=0; rready=1;
            do @(posedge clk); while (!rvalid);
            data=rdata;
            @(negedge clk); rready=0;
        end
    endtask

    reg [31:0] prog [0:255];
    reg [31:0] rd;
    initial begin #100000; $display("[SOC] >>> FAIL <<< (TIMEOUT)"); $finish; end

    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_soc);
        $display("[SOC] bring-up: PS incarca programul, porneste CPU, citeste rezultatul...");
        awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
        awaddr=0; araddr=0; wdata=0; wstrb=0;
        for (i=0;i<256;i=i+1) prog[i]=32'h00000013;     // NOP
        $readmemh(`PROG_HEX, prog);

        // 1) reset sistem + CPU tinut in reset
        rst_n=0; cpu_resetn=0; @(negedge clk); @(negedge clk); rst_n=1; @(negedge clk);

        // 2) PS incarca programul prin AXI (cat CPU e in reset)
        for (i=0;i<9;i=i+1) axi_write(i*4, prog[i], 4'hF);

        // 3) PS porneste CPU-ul
        @(negedge clk); cpu_resetn=1;

        // 4) lasa CPU sa ruleze
        for (i=0;i<150;i=i+1) @(negedge clk);

        // 5) PS citeste rezultatul de la 0x100
        axi_read(12'h100, rd);
        if (rd !== 32'd55) begin
            errors=errors+1; $display("  FAIL: 0x100 = %0d (asteptat 55)", rd);
        end

        if (errors==0) $display("[SOC] >>> PASS <<< (PS->incarcare->run->rezultat 55 via AXI)");
        else            $display("[SOC] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
