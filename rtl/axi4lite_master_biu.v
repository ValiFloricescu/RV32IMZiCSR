`timescale 1ns / 1ps
//
// axi4lite_master_biu.v
// Bus Interface Unit: traduce cererile nucleului (fetch + load/store) intr-un
// singur master AXI4-Lite. Pe fiecare "pas" al pipeline-ului serializeaza:
//   (1) operatia de date din MEM, daca exista (scriere AW+W+B sau citire AR+R)
//   (2) fetch-ul instructiunii de la imem_addr (AR+R)
// apoi elibereaza pipeline-ul un ciclu (mem_stall=0). Cat dureaza, mem_stall=1
// ingheata tot nucleul (inclusiv muldiv).
//
module axi4lite_master_biu (
    input  wire        clk,
    input  wire        rst_n,

    // ---- interfata catre nucleu (handshake valid/ready) ----
    input  wire [31:0] imem_addr,
    input  wire        imem_valid,   // nucleul cere fetch
    output wire [31:0] imem_rdata,
    output wire        imem_ready,   // instructiunea e valida acum
    input  wire        dmem_valid,   // MEM cere acces (load sau store)
    input  wire        dmem_we,      // 1 = store, 0 = load
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire [3:0]  dmem_wstrb,
    output wire [31:0] dmem_rdata,
    output wire        dmem_ready,   // accesul de date s-a incheiat acum

    // ---- AXI4-Lite MASTER (spre magistrala) ----
    output wire [31:0] m_axi_awaddr,
    output wire [2:0]  m_axi_awprot,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    output wire [31:0] m_axi_araddr,
    output wire [2:0]  m_axi_arprot,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready
);

    localparam [2:0] S_START = 3'd0,  // decide: date sau direct fetch
                     S_AW    = 3'd1,  // store: adresa + date
                     S_B     = 3'd2,  // store: raspuns
                     S_DAR   = 3'd3,  // load: adresa
                     S_DR    = 3'd4,  // load: date
                     S_IAR   = 3'd5,  // fetch: adresa
                     S_IR    = 3'd6,  // fetch: date
                     S_DONE  = 3'd7;  // eliberare (1 ciclu)

    reg [2:0]  state;
    reg [31:0] imem_rdata_r, dmem_rdata_r;
    reg        aw_done, w_done;

    wire aw_hs = m_axi_awvalid & m_axi_awready;
    wire w_hs  = m_axi_wvalid  & m_axi_wready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_START; imem_rdata_r <= 32'b0; dmem_rdata_r <= 32'b0;
            aw_done <= 1'b0; w_done <= 1'b0;
        end else begin
            case (state)
                S_START: begin
                    if (dmem_valid) begin
                        if (dmem_we) begin aw_done <= 1'b0; w_done <= 1'b0; state <= S_AW; end
                        else                                                state <= S_DAR;
                    end else                                                state <= S_IAR;
                end
                S_AW: begin
                    if (aw_hs) aw_done <= 1'b1;
                    if (w_hs)  w_done  <= 1'b1;
                    if ((aw_done | aw_hs) & (w_done | w_hs)) state <= S_B;
                end
                S_B:   if (m_axi_bvalid)  state <= S_IAR;
                S_DAR: if (m_axi_arready) state <= S_DR;
                S_DR:  if (m_axi_rvalid) begin dmem_rdata_r <= m_axi_rdata; state <= S_IAR; end
                S_IAR: if (m_axi_arready) state <= S_IR;
                S_IR:  if (m_axi_rvalid) begin imem_rdata_r <= m_axi_rdata; state <= S_DONE; end
                S_DONE: state <= S_START;
                default: state <= S_START;
            endcase
        end
    end

    // ---- canal scriere ----
    assign m_axi_awaddr  = dmem_addr;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awvalid = (state == S_AW) & ~aw_done;
    assign m_axi_wdata   = dmem_wdata;
    assign m_axi_wstrb   = dmem_wstrb;
    assign m_axi_wvalid  = (state == S_AW) & ~w_done;
    assign m_axi_bready  = (state == S_B);

    // ---- canal citire (date sau fetch) ----
    assign m_axi_araddr  = (state == S_DAR) ? dmem_addr : imem_addr;
    assign m_axi_arprot  = (state == S_IAR) ? 3'b100 : 3'b000;  // 100 = fetch
    assign m_axi_arvalid = (state == S_DAR) | (state == S_IAR);
    assign m_axi_rready  = (state == S_DR)  | (state == S_IR);

    // ---- inapoi catre nucleu: ready pulseaza un ciclu (S_DONE), dupa ce
    //      atat datele cat si fetch-ul s-au incheiat; rdata sunt tinute stabile ----
    assign imem_rdata = imem_rdata_r;
    assign dmem_rdata = dmem_rdata_r;
    assign imem_ready = (state == S_DONE);
    assign dmem_ready = (state == S_DONE);

endmodule
