// AXI4 protocol assertion module — passive, bound externally to axi_if.

// verilator lint_off ASCRANGE
module axi_assertions #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter USER_WIDTH = 1,
    parameter HAS_BURST  = 1
)(
    input logic ACLK,
    input logic ARESETn,
    // Write Address Channel
    input logic [((ID_WIDTH > 0) ? ID_WIDTH : 0)-1:0] AWID,
    input logic [ADDR_WIDTH-1:0]                      AWADDR,
    input logic [(HAS_BURST ? 8 : 0)-1:0]             AWLEN,
    input logic [(HAS_BURST ? 3 : 0)-1:0]             AWSIZE,
    input axi_types_pkg::burst_t                      AWBURST,
    input axi_types_pkg::lock_t                       AWLOCK,
    input axi_types_pkg::cache_t                      AWCACHE,
    input axi_types_pkg::prot_t                       AWPROT,
    input logic [3:0]                                 AWQOS,
    input logic [3:0]                                 AWREGION,
    input logic                                       AWVALID,
    input logic                                       AWREADY,
    input logic [USER_WIDTH-1:0]                      AWUSER,
    // Write Data Channel
    input logic [DATA_WIDTH-1:0]                      WDATA,
    input logic [(DATA_WIDTH/8)-1:0]                  WSTRB,
    input logic [(HAS_BURST ? 1 : 0)-1:0]             WLAST,
    input logic                                       WVALID,
    input logic                                       WREADY,
    input logic [USER_WIDTH-1:0]                      WUSER,
    // Write Response Channel
    input logic [((ID_WIDTH > 0) ? ID_WIDTH : 0)-1:0] BID,
    input axi_types_pkg::resp_t                       BRESP,
    input logic                                       BVALID,
    input logic                                       BREADY,
    input logic [USER_WIDTH-1:0]                      BUSER,
    // Read Address Channel
    input logic [((ID_WIDTH > 0) ? ID_WIDTH : 0)-1:0] ARID,
    input logic [ADDR_WIDTH-1:0]                      ARADDR,
    input logic [(HAS_BURST ? 8 : 0)-1:0]             ARLEN,
    input logic [(HAS_BURST ? 3 : 0)-1:0]             ARSIZE,
    input axi_types_pkg::burst_t                      ARBURST,
    input axi_types_pkg::lock_t                       ARLOCK,
    input axi_types_pkg::cache_t                      ARCACHE,
    input axi_types_pkg::prot_t                       ARPROT,
    input logic [3:0]                                 ARQOS,
    input logic [3:0]                                 ARREGION,
    input logic                                       ARVALID,
    input logic                                       ARREADY,
    input logic [USER_WIDTH-1:0]                      ARUSER,
    // Read Data Channel
    input logic [((ID_WIDTH > 0) ? ID_WIDTH : 0)-1:0] RID,
    input logic [DATA_WIDTH-1:0]                      RDATA,
    input axi_types_pkg::resp_t                       RRESP,
    input logic [(HAS_BURST ? 1 : 0)-1:0]             RLAST,
    input logic                                       RVALID,
    input logic                                       RREADY,
    input logic [USER_WIDTH-1:0]                      RUSER
);
// verilator lint_on ASCRANGE

    // Total transaction counters for channel relationship checks.
    int unsigned aw_txn_count;
    int unsigned w_txn_count;
    int unsigned ar_txn_count;

    // Per-ID counters for ordering checks.
    int unsigned aw_id_count[int];
    int unsigned b_id_count[int];
    int unsigned ar_id_count[int];
    int unsigned r_id_count[int];

    // verilator lint_off WIDTHEXPAND
    // Transaction and ID counters updated on each handshake.
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            aw_txn_count <= 0;
            w_txn_count <= 0;
            ar_txn_count <= 0;
            aw_id_count.delete();
            b_id_count.delete();
            ar_id_count.delete();
            r_id_count.delete();
        end else begin
            if (AWVALID && AWREADY) begin
                aw_txn_count <= aw_txn_count + 1;
                aw_id_count[AWID] <= aw_id_count[AWID] + 1;
            end
            if (WVALID && WREADY) begin
                w_txn_count <= w_txn_count + 1;
            end
            if (BVALID && BREADY) begin
                b_id_count[BID] <= b_id_count[BID] + 1;
            end
            if (ARVALID && ARREADY) begin
                ar_txn_count <= ar_txn_count + 1;
                ar_id_count[ARID] <= ar_id_count[ARID] + 1;
            end
            if (RVALID && RREADY) begin
                if (!HAS_BURST || RLAST) begin
                    r_id_count[RID] <= r_id_count[RID] + 1;
                end
            end
        end
    end
    // verilator lint_on WIDTHEXPAND

    // Handshake Rules: VALID must remain asserted until READY.
    property p_aw_valid_hold;
        @(posedge ACLK) disable iff (!ARESETn)
        AWVALID && !AWREADY |=> AWVALID;
    endproperty
    aw_valid_hold: assert property (p_aw_valid_hold);

    property p_w_valid_hold;
        @(posedge ACLK) disable iff (!ARESETn)
        WVALID && !WREADY |=> WVALID;
    endproperty
    w_valid_hold: assert property (p_w_valid_hold);

    property p_b_valid_hold;
        @(posedge ACLK) disable iff (!ARESETn)
        BVALID && !BREADY |=> BVALID;
    endproperty
    b_valid_hold: assert property (p_b_valid_hold);

    property p_ar_valid_hold;
        @(posedge ACLK) disable iff (!ARESETn)
        ARVALID && !ARREADY |=> ARVALID;
    endproperty
    ar_valid_hold: assert property (p_ar_valid_hold);

    property p_r_valid_hold;
        @(posedge ACLK) disable iff (!ARESETn)
        RVALID && !RREADY |=> RVALID;
    endproperty
    r_valid_hold: assert property (p_r_valid_hold);

    // Payload Stability Rules: signals must hold when VALID && !READY.
    property p_aw_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        AWVALID && !AWREADY |=> $stable({AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION});
    endproperty
    aw_payload_stable: assert property (p_aw_stable);

    property p_w_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        WVALID && !WREADY |=> $stable({WDATA, WSTRB, WLAST});
    endproperty
    w_payload_stable: assert property (p_w_stable);

    property p_ar_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        ARVALID && !ARREADY |=> $stable({ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION});
    endproperty
    ar_payload_stable: assert property (p_ar_stable);

    // Reset Behavior Rules: all VALID deasserted during active reset.
    rst_awvalid_low: assert property(@(posedge ACLK) !ARESETn |-> !AWVALID);
    rst_wvalid_low:  assert property(@(posedge ACLK) !ARESETn |-> !WVALID);
    rst_bvalid_low:  assert property(@(posedge ACLK) !ARESETn |-> !BVALID);
    rst_arvalid_low: assert property(@(posedge ACLK) !ARESETn |-> !ARVALID);
    rst_rvalid_low:  assert property(@(posedge ACLK) !ARESETn |-> !RVALID);

    // No handshake in the first cycle after reset deassertion.
    rst_no_immediate_txn: assert property(@(posedge ACLK) $rose(ARESETn) |=> !(
        (AWVALID && AWREADY) || (WVALID && WREADY) || (BVALID && BREADY) ||
        (ARVALID && ARREADY) || (RVALID && RREADY)
    ));

    // No Unknown (X/Z) Rules: VALID/READY signals.
    no_xz_aw_vr: assert property(@(posedge ACLK) disable iff (!ARESETn) $isunknown({AWVALID, AWREADY}) == 0);
    no_xz_w_vr:  assert property(@(posedge ACLK) disable iff (!ARESETn) $isunknown({WVALID, WREADY}) == 0);
    no_xz_b_vr:  assert property(@(posedge ACLK) disable iff (!ARESETn) $isunknown({BVALID, BREADY}) == 0);
    no_xz_ar_vr: assert property(@(posedge ACLK) disable iff (!ARESETn) $isunknown({ARVALID, ARREADY}) == 0);
    no_xz_r_vr:  assert property(@(posedge ACLK) disable iff (!ARESETn) $isunknown({RVALID, RREADY}) == 0);

    // No Unknown (X/Z) Rules: address signals when VALID.
    no_xz_awaddr: assert property(@(posedge ACLK) disable iff (!ARESETn) AWVALID |-> $isunknown(AWADDR) == 0);
    no_xz_araddr: assert property(@(posedge ACLK) disable iff (!ARESETn) ARVALID |-> $isunknown(ARADDR) == 0);

    // No Unknown (X/Z) Rules: data signals when VALID.
    no_xz_wdata: assert property(@(posedge ACLK) disable iff (!ARESETn) WVALID |-> $isunknown(WDATA) == 0);
    no_xz_rdata: assert property(@(posedge ACLK) disable iff (!ARESETn) RVALID |-> $isunknown(RDATA) == 0);

    // No Unknown (X/Z) Rules: key control signals.
    no_xz_aw_ctrl: assert property(@(posedge ACLK) disable iff (!ARESETn) AWVALID |-> $isunknown({AWBURST, AWQOS, AWREGION}) == 0);
    no_xz_ar_ctrl: assert property(@(posedge ACLK) disable iff (!ARESETn) ARVALID |-> $isunknown({ARBURST, ARQOS, ARREGION}) == 0);
    no_xz_bresp:   assert property(@(posedge ACLK) disable iff (!ARESETn) BVALID |-> $isunknown(BRESP) == 0);
    no_xz_rresp:   assert property(@(posedge ACLK) disable iff (!ARESETn) RVALID |-> $isunknown(RRESP) == 0);

    // Channel Relationship Rules: B response requires prior AW+W, R response requires prior AR.
    b_follows_aw_w: assert property(@(posedge ACLK) disable iff (!ARESETn)
        (BVALID && BREADY) |-> (aw_txn_count > 0 && w_txn_count > 0)
    );

    r_follows_ar: assert property(@(posedge ACLK) disable iff (!ARESETn)
        (RVALID && RREADY) |-> (ar_txn_count > 0)
    );

    // Ordering Rules: same-ID responses must not exceed same-ID requests (gated on ID_WIDTH).
    // verilator lint_off WIDTHEXPAND
    generate
        if (ID_WIDTH > 0) begin : gen_ordering
            b_id_order: assert property(@(posedge ACLK) disable iff (!ARESETn)
                (BVALID && BREADY) |-> (b_id_count[BID] <= aw_id_count[BID])
            );

            r_id_order: assert property(@(posedge ACLK) disable iff (!ARESETn)
                (RVALID && RREADY && (!HAS_BURST || RLAST)) |-> (r_id_count[RID] <= ar_id_count[RID])
            );
        end
    endgenerate
    // verilator lint_on WIDTHEXPAND

endmodule
