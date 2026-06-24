module test_fpga_top #(
    parameter [31:0] RESET_PC = 32'h0000_0000
) (
    input clk,
    input rst_n
);
    
wire [31:0] axi_awaddr;
wire [2:0]  axi_awprot;
wire        axi_awvalid;
wire        axi_awready;
wire [31:0] axi_wdata;
wire [3:0]  axi_wstrb;
wire        axi_wvalid;
wire        axi_wready;
wire [1:0]  axi_bresp;
wire        axi_bvalid;
wire        axi_bready;
wire [31:0] axi_araddr;
wire [2:0]  axi_arprot;
wire        axi_arvalid;
wire        axi_arready;
wire [31:0] axi_rdata;
wire [1:0]  axi_rresp;
wire        axi_rvalid;
wire        axi_rready;

riscv_axi_top #(
    .RESET_PC( RESET_PC )
) i_core (
    .clk    ( clk ),
    .rst_n  ( rst_n ),

    // ---- AXI4-Lite MASTER ----
    .m_axi_awaddr   ( axi_awaddr ),
    .m_axi_awprot   ( axi_awprot ),
    .m_axi_awvalid  ( axi_awvalid ),
    .m_axi_awready  ( axi_awready ),
    .m_axi_wdata    ( axi_wdata ),
    .m_axi_wstrb    ( axi_wstrb ),
    .m_axi_wvalid   ( axi_wvalid ),
    .m_axi_wready   ( axi_wready ),
    .m_axi_bresp    ( axi_bresp ),
    .m_axi_bvalid   ( axi_bvalid ),
    .m_axi_bready   ( axi_bready ),
    .m_axi_araddr   ( axi_araddr ),
    .m_axi_arprot   ( axi_arprot ),
    .m_axi_arvalid  ( axi_arvalid ),
    .m_axi_arready  ( axi_arready ),
    .m_axi_rdata    ( axi_rdata ),
    .m_axi_rresp    ( axi_rresp ),
    .m_axi_rvalid   ( axi_rvalid ),
    .m_axi_rready   ( axi_rready )
);

(* dont_touch = "true" *) blk_mem_gen_0 i_mem (
  .rsta_busy(),          // output wire rsta_busy
  .rstb_busy(),          // output wire rstb_busy
  .s_aclk(clk),                // input wire s_aclk
  .s_aresetn(rst_n),          // input wire s_aresetn
  .s_axi_awaddr (axi_awaddr),    // input wire [31 : 0] s_axi_awaddr
  .s_axi_awvalid(axi_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(axi_awready),  // output wire s_axi_awready
  .s_axi_wdata  (axi_wdata),      // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb  (axi_wstrb),      // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid (axi_wvalid),    // input wire s_axi_wvalid
  .s_axi_wready (axi_wready),    // output wire s_axi_wready
  .s_axi_bresp  (axi_bresp),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid (axi_bvalid),    // output wire s_axi_bvalid
  .s_axi_bready (axi_bready),    // input wire s_axi_bready
  .s_axi_araddr (axi_araddr),    // input wire [31 : 0] s_axi_araddr
  .s_axi_arvalid(axi_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(axi_arready),  // output wire s_axi_arready
  .s_axi_rdata  (axi_rdata),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp  (axi_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid (axi_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready (axi_rready)    // input wire s_axi_rready
);

endmodule