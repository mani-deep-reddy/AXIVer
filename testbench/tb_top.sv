// Top-level testbench module — structural wiring of the full verification system.

import axi_config_pkg::*;

// Bind AXI4 protocol assertions to every axi_if instance.
bind axi_if axi_assertions #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .USER_WIDTH(USER_WIDTH),
    .HAS_BURST(HAS_BURST)
) assertions_i (.*);

// Bind AXI-Stream protocol assertions to every axi_stream_if instance.
bind axi_stream_if axi_stream_checks #(
    .DATA_WIDTH(DATA_WIDTH),
    .USER_WIDTH(USER_WIDTH)
) stream_assertions_i (.*);

module tb_top;

    // Clock and reset parameters.
    parameter CLK_PERIOD = 10;
    parameter RESET_CYCLES = 10;

    // Clock generation.
    logic ACLK = 1'b0;
    always #(CLK_PERIOD / 2) ACLK = ~ACLK;

    // Reset generation — active low, asserted for RESET_CYCLES then deasserted.
    logic ARESETn;
    initial begin
        ARESETn = 1'b0;
        repeat (RESET_CYCLES) @(posedge ACLK);
        ARESETn = 1'b1;
    end

    // Inverted reset for DUT (axi_ram uses active-high rst).
    wire rst = ~ARESETn;

    // AXI4 Full/Lite interface instantiation.
    axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .HAS_BURST(HAS_BURST)
    ) axi_intf (
        .ACLK(ACLK),
        .ARESETn(ARESETn)
    );

    // DUT instantiation — axi_ram connected to interface signals.
    axi_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(16),
        .ID_WIDTH(ID_WIDTH)
    ) dut (
        .clk(ACLK),
        .rst(rst),
        .s_axi_awid(axi_intf.AWID),
        .s_axi_awaddr(axi_intf.AWADDR),
        .s_axi_awlen(axi_intf.AWLEN),
        .s_axi_awsize(axi_intf.AWSIZE),
        .s_axi_awburst(axi_intf.AWBURST),
        .s_axi_awlock(axi_intf.AWLOCK),
        .s_axi_awcache(axi_intf.AWCACHE),
        .s_axi_awprot(axi_intf.AWPROT),
        .s_axi_awvalid(axi_intf.AWVALID),
        .s_axi_awready(axi_intf.AWREADY),
        .s_axi_wdata(axi_intf.WDATA),
        .s_axi_wstrb(axi_intf.WSTRB),
        .s_axi_wlast(axi_intf.WLAST),
        .s_axi_wvalid(axi_intf.WVALID),
        .s_axi_wready(axi_intf.WREADY),
        .s_axi_bid(axi_intf.BID),
        .s_axi_bresp(axi_intf.BRESP),
        .s_axi_bvalid(axi_intf.BVALID),
        .s_axi_bready(axi_intf.BREADY),
        .s_axi_arid(axi_intf.ARID),
        .s_axi_araddr(axi_intf.ARADDR),
        .s_axi_arlen(axi_intf.ARLEN),
        .s_axi_arsize(axi_intf.ARSIZE),
        .s_axi_arburst(axi_intf.ARBURST),
        .s_axi_arlock(axi_intf.ARLOCK),
        .s_axi_arcache(axi_intf.ARCACHE),
        .s_axi_arprot(axi_intf.ARPROT),
        .s_axi_arvalid(axi_intf.ARVALID),
        .s_axi_arready(axi_intf.ARREADY),
        .s_axi_rid(axi_intf.RID),
        .s_axi_rdata(axi_intf.RDATA),
        .s_axi_rresp(axi_intf.RRESP),
        .s_axi_rlast(axi_intf.RLAST),
        .s_axi_rvalid(axi_intf.RVALID),
        .s_axi_rready(axi_intf.RREADY)
    );

    // Environment — assembled in initial block, runs verification components.
    axi_env env;

    initial begin
        env = new();
        env.set_interface(axi_intf);
        env.build();
        env.connect();
        env.run();
    end

    // Simulation timeout — ensures clean termination.
    initial begin
        #100000;
        $display("[%0t] TIMEOUT: Simulation exceeded max time", $time);
        $finish;
    end

endmodule
