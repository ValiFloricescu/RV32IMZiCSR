`timescale 1ns / 1ps

module axi4lite_mem #(
    parameter integer ADDR_WIDTH = 12               // 4 KB => 1024 cuvinte
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // ---- port CPU (citire asincrona, scriere sincrona) ----
    input  wire [31:0]            imem_addr,
    output wire [31:0]            imem_rdata,
    input  wire [31:0]            dmem_addr,
    input  wire [31:0]            dmem_wdata,
    input  wire [3:0]             dmem_wstrb,
    input  wire                   dmem_we,
    output wire [31:0]            dmem_rdata,

    // ---- port AXI4-Lite slave (PS) ----
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

    localparam integer IDX_HI = ADDR_WIDTH - 1;      // bit superior index cuvant
    localparam integer WORDS  = (1 << (ADDR_WIDTH - 2));
    reg [31:0] mem [0:WORDS-1];

    // index de cuvant (adresa pe octeti, /4)
    wire [ADDR_WIDTH-3:0] imem_idx = imem_addr[IDX_HI:2];
    wire [ADDR_WIDTH-3:0] dmem_idx = dmem_addr[IDX_HI:2];

    // ---- port CPU: citiri asincrone ----
    assign imem_rdata = mem[imem_idx];
    assign dmem_rdata = mem[dmem_idx];

    // ============================================================
    //  AXI4-Lite: canal de SCRIERE
    // ============================================================
    reg                  awready_r, wready_r, bvalid_r;
    // acceptam adresa si datele impreuna (AXI4-Lite simplu)
    wire wr_accept = ~awready_r & s_axi_awvalid & s_axi_wvalid & ~bvalid_r;
    wire [ADDR_WIDTH-3:0] axi_waddr_idx = s_axi_awaddr[IDX_HI:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready_r <= 1'b0; wready_r <= 1'b0; bvalid_r <= 1'b0;
        end else begin
            awready_r <= wr_accept;          // puls de 1 ciclu
            wready_r  <= wr_accept;
            if (wr_accept)                     bvalid_r <= 1'b1;
            else if (bvalid_r & s_axi_bready)  bvalid_r <= 1'b0;
        end
    end

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_bresp   = 2'b00;

    // ============================================================
    //  AXI4-Lite: canal de CITIRE
    // ============================================================
    reg                  arready_r, rvalid_r;
    reg [31:0]           rdata_r;
    wire rd_accept = ~arready_r & s_axi_arvalid & ~rvalid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arready_r <= 1'b0; rvalid_r <= 1'b0; rdata_r <= 32'b0;
        end else begin
            arready_r <= rd_accept;
            if (rd_accept) begin
                rdata_r  <= mem[s_axi_araddr[IDX_HI:2]];
                rvalid_r <= 1'b1;
            end else if (rvalid_r & s_axi_rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

    assign s_axi_arready = arready_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rvalid  = rvalid_r;
    assign s_axi_rresp   = 2'b00;

    // ============================================================
    //  SCRIERE in memorie: CPU (dmem_we) sau AXI (wr_accept), cu strobe.
    //  In uz normal sunt excluse temporal (CPU in reset cat incarca PS).
    // ============================================================
    always @(posedge clk) begin
        if (dmem_we) begin
            if (dmem_wstrb[0]) mem[dmem_idx][7:0]   <= dmem_wdata[7:0];
            if (dmem_wstrb[1]) mem[dmem_idx][15:8]  <= dmem_wdata[15:8];
            if (dmem_wstrb[2]) mem[dmem_idx][23:16] <= dmem_wdata[23:16];
            if (dmem_wstrb[3]) mem[dmem_idx][31:24] <= dmem_wdata[31:24];
        end
        if (wr_accept) begin
            if (s_axi_wstrb[0]) mem[axi_waddr_idx][7:0]   <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) mem[axi_waddr_idx][15:8]  <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) mem[axi_waddr_idx][23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) mem[axi_waddr_idx][31:24] <= s_axi_wdata[31:24];
        end
    end

endmodule
