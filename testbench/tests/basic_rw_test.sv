// Basic read/write test — exercises the full end-to-end pipeline:
// transactor → DUT (axi_ram) → monitor → scoreboard → ref model + compare + coverage.

import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;

module basic_rw_test;

    parameter CLK_PERIOD = 10;
    parameter RESET_CYCLES = 10;

    // Clock generation.
    logic ACLK = 1'b0;
    always #(CLK_PERIOD / 2) ACLK = ~ACLK;

    // Reset generation — active low.
    logic ARESETn;
    initial begin
        ARESETn = 1'b0;
        repeat (RESET_CYCLES) @(posedge ACLK);
        ARESETn = 1'b1;
    end

    wire rst = ~ARESETn;

    // AXI4 interface.
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

    // DUT — axi_ram connected via explicit signal wiring.
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

    // Environment.
    axi_env env;

    // Helper: create a single-beat write transaction.
    function axi_write_txn make_single_write(int txn_id, logic [ADDR_WIDTH-1:0] addr, logic [DATA_WIDTH-1:0] data);
        axi_write_txn txn;
        txn = new(txn_id);
        txn.addr = addr;
        txn.id = txn_id[7:0];
        txn.len = 8'h0;       // 1 beat
        txn.size = $clog2(STRB_WIDTH); // full data width
        txn.burst = INCR;
        txn.lock = NORMAL;
        txn.data = new[1];
        txn.data[0] = data;
        txn.strb = new[1];
        txn.strb[0] = {STRB_WIDTH{1'b1}}; // full strobe
        return txn;
    endfunction

    // Helper: create a multi-beat write transaction.
    function axi_write_txn make_burst_write(int txn_id, logic [ADDR_WIDTH-1:0] addr, int num_beats);
        axi_write_txn txn;
        int i;
        txn = new(txn_id);
        txn.addr = addr;
        txn.id = txn_id[7:0];
        txn.len = num_beats - 1;
        txn.size = $clog2(STRB_WIDTH);
        txn.burst = INCR;
        txn.lock = NORMAL;
        txn.data = new[num_beats];
        txn.strb = new[num_beats];
        for (i = 0; i < num_beats; i++) begin
            txn.data[i] = 32'h100 + (txn_id * 100) + i;
            txn.strb[i] = {STRB_WIDTH{1'b1}};
        end
        return txn;
    endfunction

    // Helper: create a read transaction.
    function axi_read_txn make_read(int txn_id, logic [ADDR_WIDTH-1:0] addr, int num_beats);
        axi_read_txn txn;
        txn = new(txn_id);
        txn.addr = addr;
        txn.id = txn_id[7:0];
        txn.len = num_beats - 1;
        txn.size = $clog2(STRB_WIDTH);
        txn.burst = INCR;
        txn.lock = NORMAL;
        return txn;
    endfunction

    // Main test sequence.
    initial begin
        // Build and connect environment.
        env = new();
        env.set_interface(axi_intf);
        env.build();
        env.connect();
        env.run();

        // Wait for reset to deassert.
        @(posedge ARESETn);
        @(posedge ACLK);

        // Phase 1: Single-beat writes to 0x0, 0x4, 0x8.
        env.master.txn_queue.put(make_single_write(1, 32'h0000, 32'h0000_0100));
        env.master.txn_queue.put(make_single_write(2, 32'h0004, 32'h0000_0101));
        env.master.txn_queue.put(make_single_write(3, 32'h0008, 32'h0000_0102));

        // Phase 2: 2-beat writes starting at 0x100 and 0x200.
        env.master.txn_queue.put(make_burst_write(4, 32'h0100, 2));
        env.master.txn_queue.put(make_burst_write(5, 32'h0200, 2));

        // Phase 3: 4-beat write starting at 0x300.
        env.master.txn_queue.put(make_burst_write(6, 32'h0300, 4));

        // Allow writes to complete before issuing reads.
        repeat (50) @(posedge ACLK);

        // Phase 4: Matching reads for single-beat writes.
        env.master.txn_queue.put(make_read(10, 32'h0000, 1));
        env.master.txn_queue.put(make_read(11, 32'h0004, 1));
        env.master.txn_queue.put(make_read(12, 32'h0008, 1));

        // Phase 5: Matching reads for 2-beat writes.
        env.master.txn_queue.put(make_read(13, 32'h0100, 2));
        env.master.txn_queue.put(make_read(14, 32'h0200, 2));

        // Phase 6: Matching read for 4-beat write.
        env.master.txn_queue.put(make_read(15, 32'h0300, 4));

        // Allow reads to complete.
        repeat (100) @(posedge ACLK);

        // End-of-test report.
        env.scoreboard.report();

        // Display coverage summary.
        $display("[%0t] Coverage: type=%0.2f%% burst=%0.2f%% addr=%0.2f%% wstrb=%0.2f%%",
            $time,
            env.coverage.cg.cp_txn_type.get_coverage(),
            env.coverage.cg.cp_burst_len.get_coverage(),
            env.coverage.cg.cp_addr_lo.get_coverage(),
            env.coverage.cg.cp_wstrb.get_coverage());

        $display("[%0t] TEST basic_rw_test: FINISHED", $time);
        #100;
        $finish;
    end

    // Simulation timeout.
    initial begin
        #100000;
        $display("[%0t] TIMEOUT: Simulation exceeded max time", $time);
        $finish;
    end

endmodule
