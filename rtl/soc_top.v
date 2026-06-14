`timescale 1ns / 1ps

module soc_top #(
    parameter integer ADDR_WIDTH = 12
)(
    input  wire                   clk,
    input  wire                   rst_n,        // reset de sistem (AXI + memorie)
    input  wire                   cpu_resetn,   // reset CPU controlat de PS

    // ---- AXI4-Lite slave (spre PS) ----
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [2:0]             s_axi_awprot,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,
    input  wire [31:0]            s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [2:0]             s_axi_arprot,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,
    output wire [31:0]            s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready
);

    // resetul nucleului: sistem + control PS
    wire core_rst_n = rst_n & cpu_resetn;

    // magistrale CPU <-> memorie
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_we;

    riscv_core_pipe u_core (
        .clk(clk), .rst_n(core_rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata)
    );

    axi4lite_mem #(.ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
        .dmem_we(dmem_we), .dmem_rdata(dmem_rdata),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready)
    );

endmodule
