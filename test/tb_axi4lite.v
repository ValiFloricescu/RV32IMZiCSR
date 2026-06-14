`timescale 1ns / 1ps
// ============================================================
//  tb_axi4lite.v  -  BFM master AXI4-Lite pentru axi4lite_mem
// ------------------------------------------------------------
//  Verifica: scriere AXI, citire AXI, raspunsuri OKAY, byte-strobe,
//  si accesul prin portul CPU (back-door) la aceeasi memorie.
// ============================================================
`ifndef DUMP_FILE
 `define DUMP_FILE "waveform/tb_axi4lite.vcd"
`endif

module tb_axi4lite;

    localparam ADDR_WIDTH = 12;
    reg clk = 1'b0, rst_n;
    integer errors = 0;
    always #5 clk = ~clk;

    reg  [ADDR_WIDTH-1:0] awaddr, araddr;
    reg  [31:0]           wdata;
    reg  [3:0]            wstrb;
    reg                   awvalid, wvalid, bready, arvalid, rready;
    wire                  awready, wready, bvalid, arready, rvalid;
    wire [1:0]            bresp, rresp;
    wire [31:0]           rdata;

    reg  [31:0] imem_addr, dmem_addr, dmem_wdata;
    reg  [3:0]  dmem_wstrb;
    reg         dmem_we;
    wire [31:0] imem_rdata, dmem_rdata;

    axi4lite_mem #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
        .dmem_we(dmem_we), .dmem_rdata(dmem_rdata),
        .s_axi_awaddr(awaddr), .s_axi_awprot(3'b0), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(3'b0), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    // ---- scriere AXI4-Lite (faza adresa/date, apoi faza raspuns) ----
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [31:0]           data;
        input [3:0]            strb;
        begin
            @(negedge clk);
            awaddr = addr; wdata = data; wstrb = strb;
            awvalid = 1'b1; wvalid = 1'b1;
            do @(posedge clk); while (!(awready && wready));
            @(negedge clk); awvalid = 1'b0; wvalid = 1'b0;
            bready = 1'b1;                       // bready inainte de a astepta bvalid
            do @(posedge clk); while (!bvalid);  // se stinge la acest front (bvalid&bready)
            if (bresp !== 2'b00) begin
                errors = errors + 1; $display("  FAIL: BRESP=%b la addr=%h", bresp, addr);
            end
            @(negedge clk); bready = 1'b0;
        end
    endtask

    // ---- citire AXI4-Lite ----
    task axi_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [31:0]           data;
        begin
            @(negedge clk);
            araddr = addr; arvalid = 1'b1;
            do @(posedge clk); while (!arready);
            @(negedge clk); arvalid = 1'b0;
            rready = 1'b1;                        // ready abia in faza R
            do @(posedge clk); while (!rvalid);   // slave-ul tine rvalid pana la rready
            data = rdata;
            if (rresp !== 2'b00) begin
                errors = errors + 1; $display("  FAIL: RRESP=%b la addr=%h", rresp, addr);
            end
            @(negedge clk); rready = 1'b0;
        end
    endtask

    task chk; input integer id; input [31:0] got, exp; begin
        if (got !== exp) begin
            errors = errors + 1;
            $display("  FAIL test %0d: got=%h exp=%h", id, got, exp);
        end
    end endtask

    // watchdog: nu lasa simularea sa atarne
    initial begin #50000; $display("[AXI4LITE] >>> FAIL <<< (TIMEOUT)"); $finish; end

    reg [31:0] rd;
    initial begin
        $dumpfile(`DUMP_FILE);
        $dumpvars(0, tb_axi4lite);
        $display("[AXI4LITE] pornire teste...");
        awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
        awaddr=0; araddr=0; wdata=0; wstrb=0;
        imem_addr=0; dmem_addr=0; dmem_wdata=0; dmem_wstrb=0; dmem_we=0;
        rst_n = 1'b0; @(negedge clk); @(negedge clk); rst_n = 1'b1; @(negedge clk);

        // 1) scriere + citire AXI
        axi_write(12'h000, 32'hDEADBEEF, 4'hF);
        axi_write(12'h004, 32'h12345678, 4'hF);
        axi_read (12'h000, rd); chk(1, rd, 32'hDEADBEEF);
        axi_read (12'h004, rd); chk(2, rd, 32'h12345678);

        // 2) PS scrie program -> CPU il citeste prin portul de instructiuni
        axi_write(12'h010, 32'h00A00093, 4'hF);
        @(negedge clk); imem_addr = 32'h010;
        @(negedge clk); chk(3, imem_rdata, 32'h00A00093);

        // 3) CPU scrie (store) -> PS citeste prin AXI
        @(negedge clk);
        dmem_addr = 32'h020; dmem_wdata = 32'hCAFEF00D; dmem_wstrb = 4'hF; dmem_we = 1'b1;
        @(negedge clk); dmem_we = 1'b0;
        axi_read(12'h020, rd); chk(4, rd, 32'hCAFEF00D);

        // 4) byte-strobe
        axi_write(12'h030, 32'h00000000, 4'hF);
        axi_write(12'h030, 32'h0000AB00, 4'b0010);
        axi_read (12'h030, rd); chk(5, rd, 32'h0000AB00);
        axi_write(12'h030, 32'hFF000000, 4'b1000);
        axi_read (12'h030, rd); chk(6, rd, 32'hFF00AB00);

        if (errors == 0) $display("[AXI4LITE] >>> PASS <<< (protocol AXI4-Lite + back-door CPU OK)");
        else             $display("[AXI4LITE] >>> FAIL <<< (%0d erori)", errors);
        $finish;
    end

endmodule
