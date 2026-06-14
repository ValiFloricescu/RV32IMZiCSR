`timescale 1ns / 1ps
`include "riscv_defs.vh"
// ============================================================
//  tb_compliance.v  -  Harness de conformitate (riscv-tests / riscof)
// ------------------------------------------------------------
//  Model de executie compatibil cu riscv-arch-test:
//    - incarca testul (hex) in memorie unificata (von Neumann);
//    - ruleaza pana cand CPU scrie la adresa TOHOST (semnal de halt);
//      valoarea 1 = trecut, altceva = cod de esec (riscv-tests);
//    - exporta regiunea de semnatura [SIG_BEGIN, SIG_END) intr-un
//      fisier, cate un cuvant pe linie (%08x), pentru comparatie riscof.
//
//  Adresele vin din simbolurile testului compilat (begin_signature,
//  end_signature, tohost) si se pot suprascrie la compilare prin -D.
// ============================================================
`ifndef PROG_HEX
 `define PROG_HEX "sw/compliance_demo.hex"
`endif
`ifndef SIG_FILE
 `define SIG_FILE "sim/DUT.signature"
`endif
`ifndef SIG_BEGIN
 `define SIG_BEGIN 32'h00000200
`endif
`ifndef SIG_END
 `define SIG_END   32'h00000208
`endif
`ifndef TOHOST
 `define TOHOST    32'h00000300
`endif
`ifndef MAX_CYCLES
 `define MAX_CYCLES 100000
`endif
`ifndef RESET_PC_TB
 `define RESET_PC_TB `RESET_PC
`endif
`ifndef WORDS_TB
 `define WORDS_TB 65536
`endif
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_compliance.vcd"
`endif

module tb_compliance;

    localparam WORDS = `WORDS_TB;  // dimensionata dupa binarul testului (run_dut.sh)
    reg         clk = 1'b0, rst_n;
    integer     cyc = 0;
    always #5 clk = ~clk;

    // ---- memorie unificata ----
    reg [31:0] mem [0:WORDS-1];
    wire [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_we;
    wire [31:0] iidx = imem_addr[31:2];
    wire [31:0] didx = dmem_addr[31:2];

    assign imem_rdata = mem[iidx & (WORDS-1)];
    assign dmem_rdata = mem[didx & (WORDS-1)];

    always @(posedge clk) if (dmem_we) begin
        if (dmem_wstrb[0]) mem[didx & (WORDS-1)][7:0]   <= dmem_wdata[7:0];
        if (dmem_wstrb[1]) mem[didx & (WORDS-1)][15:8]  <= dmem_wdata[15:8];
        if (dmem_wstrb[2]) mem[didx & (WORDS-1)][23:16] <= dmem_wdata[23:16];
        if (dmem_wstrb[3]) mem[didx & (WORDS-1)][31:24] <= dmem_wdata[31:24];
    end

    riscv_core_pipe #(.RESET_PC(`RESET_PC_TB)) dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata)
    );

    // ---- export semnatura ----
    task dump_signature;
        integer fd, a;
        begin
            fd = $fopen(`SIG_FILE, "w");
            for (a = `SIG_BEGIN; a < `SIG_END; a = a + 4)
                $fwrite(fd, "%08x\n", mem[(a[31:2]) & (WORDS-1)]);
            $fclose(fd);
            $display("[COMPLIANCE] semnatura exportata in %s", `SIG_FILE);
        end
    endtask

    // ---- detectie halt: scriere la TOHOST ----
    integer k;
    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_compliance);
        for (k = 0; k < WORDS; k = k + 1) mem[k] = `RV_NOP;
        $readmemh(`PROG_HEX, mem);
        $display("[COMPLIANCE] rulez %s ...", `PROG_HEX);
        rst_n = 1'b0; @(negedge clk); @(negedge clk); rst_n = 1'b1;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cyc <= cyc + 1;
            if (dmem_we && (didx & (WORDS-1)) == ((`TOHOST >> 2) & (WORDS-1))) begin
                if (dmem_wdata == 32'd1)
                    $display("[COMPLIANCE] >>> PASS <<< (tohost=1)");
                else
                    $display("[COMPLIANCE] >>> FAIL <<< (tohost=%0d, test #%0d)",
                             dmem_wdata, dmem_wdata >> 1);
                dump_signature;
                $finish;
            end
            if (cyc > `MAX_CYCLES) begin
                $display("[COMPLIANCE] >>> FAIL <<< (TIMEOUT dupa %0d cicluri)", cyc);
                dump_signature;
                $finish;
            end
        end
    end

endmodule