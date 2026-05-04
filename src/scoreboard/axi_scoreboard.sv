`ifndef SCOREBOARD_AXI_SCOREBOARD_SV
`define SCOREBOARD_AXI_SCOREBOARD_SV

import hooks_pkg::*;
import logger_pkg::*;
import axi_config_pkg::*;
import axi_transaction_pkg::*;
import scoreboard_pkg::*;

// Scoreboard — subscribes to analysis ports, feeds aligned pairs to the tracker, and calls user comparison logic.

// Inner subscriber class — forwards expected transactions to the tracker.
class axi_expected_subscriber #(
    string AXI_TYPE_PARAM = AXI_TYPE,
    type T = axi_transaction
) extends analysis_subscriber #(T);

    local txn_tracker #(AXI_TYPE_PARAM, T) ref_tracker;

    function new(txn_tracker #(AXI_TYPE_PARAM, T) t);
        this.ref_tracker = t;
    endfunction

    function void write(T txn);
        ref_tracker.add_expected(txn);
    endfunction

endclass

// Inner subscriber class — forwards actual transactions to the tracker.
class axi_actual_subscriber #(
    string AXI_TYPE_PARAM = AXI_TYPE,
    type T = axi_transaction
) extends analysis_subscriber #(T);

    local txn_tracker #(AXI_TYPE_PARAM, T) ref_tracker;

    function new(txn_tracker #(AXI_TYPE_PARAM, T) t);
        this.ref_tracker = t;
    endfunction

    function void write(T txn);
        ref_tracker.add_actual(txn);
    endfunction

endclass

class axi_scoreboard #(
    string AXI_TYPE_PARAM = AXI_TYPE,
    type T = axi_transaction
);

    local txn_tracker #(AXI_TYPE_PARAM, T) tracker;

    compare_if #(T) compare_impl;

    int unsigned cmp_total;
    int unsigned cmp_pass;
    int unsigned cmp_fail;

    axi_expected_subscriber #(AXI_TYPE_PARAM, T) exp_sub;
    axi_actual_subscriber #(AXI_TYPE_PARAM, T) act_sub;

    function new();
        this.tracker = new();
        this.exp_sub = new(tracker);
        this.act_sub = new(tracker);
        this.cmp_total = 0;
        this.cmp_pass = 0;
        this.cmp_fail = 0;
        logger::log(INFO, "Scoreboard initialized");
    endfunction

    // Set the user-provided comparison implementation.
    function void set_compare_if(compare_if #(T) impl);
        this.compare_impl = impl;
        logger::log(INFO, "Scoreboard: compare_if connected");
    endfunction

    // Return the expected subscriber for testbench connection to reference model analysis_port.
    function analysis_subscriber #(T) get_expected_subscriber();
        return exp_sub;
    endfunction

    // Return the actual subscriber for testbench connection to monitor analysis_port.
    function analysis_subscriber #(T) get_actual_subscriber();
        return act_sub;
    endfunction

    // Process all ready pairs — dequeue from tracker and invoke user comparison.
    task run_compare();
        T expected;
        T actual;
        bit result;
        string msg;

        while (tracker.is_ready()) begin
            tracker.get_pair(expected, actual);
            if (compare_impl == null) begin
                logger::log(WARN, $sformatf("Scoreboard: no compare_if set, skipping TXN:%0d", expected.txn_id));
                continue;
            end
            result = compare_impl.compare(expected, actual);
            cmp_total++;
            if (result) begin
                cmp_pass++;
                logger::log(INFO, $sformatf("Scoreboard: TXN:%0d PASS", expected.txn_id));
            end else begin
                cmp_fail++;
                logger::log(WARN, $sformatf("Scoreboard: TXN:%0d FAIL", expected.txn_id));
            end
        end
    endtask

    // End-of-test report — log summary stats and unmatched transactions.
    function void report();
        string msg;
        T unmatched[$];
        int i;

        msg = $sformatf("Scoreboard report: %0d total, %0d pass, %0d fail", cmp_total, cmp_pass, cmp_fail);
        logger::log(INFO, msg);

        tracker.get_unmatched_expected(unmatched);
        if (unmatched.size() > 0) begin
            logger::log(WARN, $sformatf("Scoreboard: %0d unmatched expected transactions", unmatched.size()));
            for (i = 0; i < unmatched.size(); i++) begin
                logger::log(WARN, $sformatf("  Unmatched expected TXN:%0d", unmatched[i].txn_id));
            end
        end

        unmatched = {};
        tracker.get_unmatched_actual(unmatched);
        if (unmatched.size() > 0) begin
            logger::log(WARN, $sformatf("Scoreboard: %0d unmatched actual transactions", unmatched.size()));
            for (i = 0; i < unmatched.size(); i++) begin
                logger::log(WARN, $sformatf("  Unmatched actual TXN:%0d", unmatched[i].txn_id));
            end
        end

        if (cmp_fail > 0) begin
            logger::log(WARN, "Scoreboard: comparison failures detected");
        end
    endfunction

endclass

`endif
