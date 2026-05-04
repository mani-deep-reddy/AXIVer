`ifndef SCOREBOARD_TXN_TRACKER_SV
`define SCOREBOARD_TXN_TRACKER_SV

import axi_config_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import logger_pkg::*;

// Protocol-aware transaction alignment and buffering engine.

class txn_tracker #(
    string AXI_TYPE_PARAM = AXI_TYPE,
    type T = axi_transaction
);

    // AXI4 Full buffers: per-protocol-ID associative arrays with FIFO queues for ordering.
    T exp_full[int][$];
    T act_full[int][$];

    // AXI4-Lite / AXI-Stream buffers: global FIFO queues.
    T exp_fifo[$];
    T act_fifo[$];

    // Extract AXI protocol ID from transaction via $cast. Returns txn_id as fallback.
    // Only used in Full mode where transactions are write_txn or read_txn (both have .id).
    local function int unsigned get_protocol_id(T txn);
        axi_write_txn write_txn;
        axi_read_txn  read_txn;
        if ($cast(write_txn, txn)) return write_txn.id;
        if ($cast(read_txn,  txn)) return read_txn.id;
        return txn.txn_id; // fallback for stream or unknown types
    endfunction

    // Add expected transaction to the appropriate buffer based on protocol mode.
    function void add_expected(T txn);
        if (AXI_TYPE_PARAM == AXI_FULL) begin
            int unsigned id = get_protocol_id(txn);
            exp_full[id].push_back(txn);
            logger::log(DEBUG, $sformatf("Tracker: expected ID:%0d buffered (Full)", id));
        end else begin
            exp_fifo.push_back(txn);
            logger::log(DEBUG, $sformatf("Tracker: expected TXN:%0d buffered (FIFO)", txn.txn_id));
        end
    endfunction

    // Add actual transaction to the appropriate buffer based on protocol mode.
    function void add_actual(T txn);
        if (AXI_TYPE_PARAM == AXI_FULL) begin
            int unsigned id = get_protocol_id(txn);
            act_full[id].push_back(txn);
            logger::log(DEBUG, $sformatf("Tracker: actual ID:%0d buffered (Full)", id));
        end else begin
            act_fifo.push_back(txn);
            logger::log(DEBUG, $sformatf("Tracker: actual TXN:%0d buffered (FIFO)", txn.txn_id));
        end
    endfunction

    // Check if a pair is ready for comparison.
    // AXI4 Full: matching ID exists on both sides. Lite/Stream: both queues non-empty.
    function bit is_ready();
        if (AXI_TYPE_PARAM == AXI_FULL) begin
            int id;
            if (exp_full.num() == 0) return 1'b0;
            id = exp_full.first();
            do begin
                if (act_full.exists(id)) return 1'b1;
            end while (exp_full.next(id));
            return 1'b0;
        end else begin
            return (exp_fifo.size() > 0) && (act_fifo.size() > 0);
        end
    endfunction

    // Get the next ready pair for comparison. Caller must check is_ready() first.
    function void get_pair(output T expected, output T actual);
        int id;
        if (AXI_TYPE_PARAM == AXI_FULL) begin
            id = exp_full.first();
            do begin
                if (act_full.exists(id)) break;
            end while (exp_full.next(id));
            expected = exp_full[id].pop_front();
            if (exp_full[id].size() == 0) exp_full.delete(id);
            actual = act_full[id].pop_front();
            if (act_full[id].size() == 0) act_full.delete(id);
        end else begin
            expected = exp_fifo.pop_front();
            actual = act_fifo.pop_front();
        end
    endfunction

    // Return all remaining unmatched expected transactions.
    function void get_unmatched_expected(output T unmatched[$]);
        unmatched = {};
        if (AXI_TYPE_PARAM == AXI_FULL) begin
            int id;
            if (exp_full.num() > 0) begin
                id = exp_full.first();
                do begin
                    unmatched = {unmatched, exp_full[id]};
                end while (exp_full.next(id));
            end
        end else begin
            unmatched = exp_fifo;
        end
    endfunction

    // Return all remaining unmatched actual transactions.
    function void get_unmatched_actual(output T unmatched[$]);
        unmatched = {};
        if (AXI_TYPE_PARAM == AXI_FULL) begin
            int id;
            if (act_full.num() > 0) begin
                id = act_full.first();
                do begin
                    unmatched = {unmatched, act_full[id]};
                end while (act_full.next(id));
            end
        end else begin
            unmatched = act_fifo;
        end
    endfunction

endclass

`endif
