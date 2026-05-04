`ifndef AXI_STREAM_MONITOR_SV
`define AXI_STREAM_MONITOR_SV

import axi_config_pkg::*;
import axi_transaction_pkg::*;
import axi_stream_txn_pkg::*;
import logger_pkg::*;
import hooks_pkg::*;

// Passive AXI-Stream monitor — observes TDATA/TVALID/TREADY/TLAST,
// reconstructs complete stream frames, publishes via analysis_port.
class axi_stream_monitor;

    virtual axi_stream_if vif;                          // virtual interface handle
    analysis_port #(axi_stream_txn) ap;                 // analysis port for published transactions

    // Beat buffer arrays for accumulating a stream frame.
    logic [DATA_WIDTH-1:0] data[$];
    logic [STRB_WIDTH-1:0] keep[$];
    bit                    last[$];
    logic [USER_WIDTH-1:0] user[$];                     // only used when USER_WIDTH > 0

    int unsigned next_txn_id;                           // monotonic ID for published transactions

    function new();
        this.ap = new();
        this.next_txn_id = 0;
    endfunction

    // Bind virtual interface for signal observation.
    function void set_interface(virtual axi_stream_if vif);
        this.vif = vif;
    endfunction

    // Get analysis port for subscriber connections.
    function analysis_port #(axi_stream_txn) get_analysis_port();
        return this.ap;
    endfunction

    // Clear beat buffers, optionally logging discarded partial frame.
    function void reset_state();
        if (data.size() > 0) begin
            logger::log(DEBUG, $sformatf("Dropped stream frame: %0d beats accumulated, no TLAST", data.size()));
        end
        data.delete();
        keep.delete();
        last.delete();
        if (USER_WIDTH > 0) begin
            user.delete();
        end
    endfunction

    // Main monitor loop — samples beats on TVALID && TREADY, emits frames on TLAST.
    task automatic run();
        axi_stream_txn txn;
        int i;

        if (this.vif == null) begin
            logger::log(FATAL, "AXI-Stream monitor run() called but interface not set");
            return;
        end

        forever begin
            @(posedge vif.monitor_cb);

            if (vif.monitor_cb.TVALID && vif.monitor_cb.TREADY) begin
                // Accumulate beat data.
                data.push_back(vif.monitor_cb.TDATA);
                keep.push_back(vif.monitor_cb.TKEEP);
                last.push_back(vif.monitor_cb.TLAST);
                if (USER_WIDTH > 0) begin
                    user.push_back(vif.monitor_cb.TUSER);
                end

                // TLAST asserted — frame complete, emit transaction.
                if (vif.monitor_cb.TLAST) begin
                    txn = new(this.next_txn_id++);

                    txn.data = new[data.size()];
                    txn.keep = new[keep.size()];
                    txn.last = new[last.size()];
                    for (i = 0; i < data.size(); i++) begin
                        txn.data[i] = data[i];
                        txn.keep[i] = keep[i];
                        txn.last[i] = last[i];
                    end
                    if (USER_WIDTH > 0) begin
                        txn.user = new[user.size()];
                        for (i = 0; i < user.size(); i++) begin
                            txn.user[i] = user[i];
                        end
                    end

                    logger::log(INFO, $sformatf("STREAM frame complete: %0d beats", data.size()), txn.txn_id);

                    ap.write(txn);

                    // Clear buffers for next frame.
                    data.delete();
                    keep.delete();
                    last.delete();
                    if (USER_WIDTH > 0) begin
                        user.delete();
                    end
                end
            end

            // Handle reset — discard partial frame.
            if (vif.ARESETn === 1'b0) begin
                reset_state();
            end
        end
    endtask

endclass

`endif
