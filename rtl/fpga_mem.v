`timescale 1ns / 1ps

module fpga_mem #(
    parameter integer ADDR_WIDTH = 12,
    parameter         MEM_FILE   = "fpga_demo.mem"
)(
    input  wire        clk,
    // port instructiuni (citire combinationala)
    input  wire [31:0] imem_addr,
    output wire [31:0] imem_rdata,
    // port date (citire combinationala, scriere sincrona)
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire [3:0]  dmem_wstrb,
    input  wire        dmem_we,
    output wire [31:0] dmem_rdata
);
    localparam integer IDX_HI = ADDR_WIDTH - 1;
    localparam integer WORDS  = (1 << (ADDR_WIDTH - 2));

    reg [31:0] mem [0:WORDS-1];

    integer k;
    initial begin
        for (k = 0; k < WORDS; k = k + 1) mem[k] = 32'h0000_0013; // NOP
        $readmemh(MEM_FILE, mem);
    end

    wire [ADDR_WIDTH-3:0] iidx = imem_addr[IDX_HI:2];
    wire [ADDR_WIDTH-3:0] didx = dmem_addr[IDX_HI:2];

    assign imem_rdata = mem[iidx];
    assign dmem_rdata = mem[didx];

    always @(posedge clk) if (dmem_we) begin
        if (dmem_wstrb[0]) mem[didx][7:0]   <= dmem_wdata[7:0];
        if (dmem_wstrb[1]) mem[didx][15:8]  <= dmem_wdata[15:8];
        if (dmem_wstrb[2]) mem[didx][23:16] <= dmem_wdata[23:16];
        if (dmem_wstrb[3]) mem[didx][31:24] <= dmem_wdata[31:24];
    end
endmodule
