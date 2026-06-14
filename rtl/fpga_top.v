`timescale 1ns / 1ps

module fpga_top #(
    parameter integer ADDR_WIDTH  = 12,
    parameter [31:0]  RESULT_ADDR = 32'h0000_0100,
    parameter         MEM_FILE    = "fpga_demo.mem"
)(
    input  wire       clk,
    input  wire       btn_reset,
    output wire [3:0] led
);
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], btn_reset};
    wire rst_n = ~rst_sync[1];

    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_we;

    riscv_core_pipe #(.RESET_PC(32'h0000_0000)) u_core (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata)
    );

    fpga_mem #(.ADDR_WIDTH(ADDR_WIDTH), .MEM_FILE(MEM_FILE)) u_mem (
        .clk(clk),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata)
    );

    reg [31:0] result_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_reg <= 32'b0;
        else if (dmem_we && (dmem_addr == RESULT_ADDR))
            result_reg <= dmem_wdata;
    end

    assign led = result_reg[3:0];
endmodule
