// AXI-Stream protocol assertion module — passive, bound externally to axi_stream_if.

// verilator lint_off ASCRANGE
module axi_stream_checks #(
    parameter DATA_WIDTH = 32,
    parameter USER_WIDTH = 0
)(
    input logic ACLK,
    input logic ARESETn,
    input logic [DATA_WIDTH-1:0] TDATA,
    input logic                  TVALID,
    input logic                  TREADY,
    input logic                  TLAST,
    input logic [(DATA_WIDTH/8)-1:0] TKEEP,
    input logic [(DATA_WIDTH/8)-1:0] TSTRB,
    input logic [USER_WIDTH-1:0] TUSER
);
// verilator lint_on ASCRANGE

    // Reset Behavior Rules: TVALID deasserted during active reset.
    rst_tvalid_low: assert property(@(posedge ACLK) !ARESETn |-> !TVALID);

    // Handshake Rule: TVALID must remain asserted until TREADY.
    property p_tvalid_hold;
        @(posedge ACLK) disable iff (!ARESETn)
        TVALID && !TREADY |=> TVALID;
    endproperty
    tvalid_hold: assert property (p_tvalid_hold);

    // Data Stability Rules: TDATA and TLAST hold when stalled.
    property p_tdata_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        TVALID && !TREADY |=> $stable(TDATA);
    endproperty
    tdata_stable: assert property (p_tdata_stable);

    property p_tlast_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        TVALID && !TREADY |=> $stable(TLAST);
    endproperty
    tlast_stable: assert property (p_tlast_stable);

    // TLAST Rules: TLAST only asserted when TVALID is high.
    tlast_requires_valid: assert property(@(posedge ACLK) disable iff (!ARESETn)
        TLAST |-> TVALID
    );

    // No Unknown (X/Z) Rules.
    no_xz_tvalid: assert property(@(posedge ACLK) disable iff (!ARESETn) $isunknown(TVALID) == 0);
    no_xz_tdata:  assert property(@(posedge ACLK) disable iff (!ARESETn) TVALID |-> $isunknown(TDATA) == 0);
    no_xz_tlast:  assert property(@(posedge ACLK) disable iff (!ARESETn) $isunknown(TLAST) == 0);

endmodule
