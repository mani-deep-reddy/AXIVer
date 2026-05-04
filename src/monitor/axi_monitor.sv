`ifndef AXI_MONITOR_SV
`define AXI_MONITOR_SV

import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import logger_pkg::*;
import hooks_pkg::*;

// Store entry for captured AW channel fields.
typedef struct {
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0]   id;
    logic [7:0]            len;
    logic [2:0]            size;
    burst_t                burst;
    lock_t                 lock;
    cache_t                cache;
    prot_t                 prot;
    logic [3:0]            qos;
    logic [4:0]            region;
} aw_entry_t;

// Store entry for captured W channel beats.
typedef struct {
    logic [DATA_WIDTH-1:0] data[$];
    logic [STRB_WIDTH-1:0] strb[$];
    bit                    last_received;
} w_entry_t;

// Store entry for captured B response.
typedef struct {
    logic [ID_WIDTH-1:0] id;
    resp_t               resp;
    bit                  received;
} b_entry_t;

// Store entry for captured AR channel fields.
typedef struct {
    logic [ADDR_WIDTH-1:0] addr;
    logic [ID_WIDTH-1:0]   id;
    logic [7:0]            len;
    logic [2:0]            size;
    burst_t                burst;
    lock_t                 lock;
    cache_t                cache;
    prot_t                 prot;
    logic [3:0]            qos;
    logic [4:0]            region;
} ar_entry_t;

// Store entry for captured R channel beats.
typedef struct {
    logic [DATA_WIDTH-1:0] data[$];
    resp_t                 resp[$];
    bit                    last_received;
} r_entry_t;

// Passive AXI4 Full/Lite monitor — observes all 5 channels, reconstructs
// complete write and read transactions, publishes via analysis_port.
class axi_monitor;

    virtual axi_if vif;                                 // virtual interface handle
    analysis_port #(axi_transaction) ap;                // analysis port for published transactions

    // ID-keyed intermediate stores for transaction correlation.
    aw_entry_t aw_store[int];
    w_entry_t  w_store[int];
    b_entry_t  b_store[int];
    ar_entry_t ar_store[int];
    r_entry_t  r_store[int];

    int aw_pending_ids[$];                            // AW acceptance order (FIFO for W channel ordering)

    int unsigned next_txn_id;                           // monotonic ID for published transactions

    function new();
        this.ap = new();
        this.next_txn_id = 0;
    endfunction

    // Bind virtual interface for signal observation.
    function void set_interface(virtual axi_if vif);
        this.vif = vif;
    endfunction

    // Get analysis port for subscriber connections.
    function analysis_port #(axi_transaction) get_analysis_port();
        return this.ap;
    endfunction

    // Clear all intermediate stores, logging discarded partial transactions at DEBUG.
    function void reset_state();
        int id;

        // Log discarded write transactions.
        foreach (aw_store[id]) begin
            if (id inside {w_store} && id inside {b_store}) begin
                logger::log(DEBUG, $sformatf("Dropped write ID=%0d: AW + %0d/%0d W beats + B pending",
                    id, w_store[id].data.size(), aw_store[id].len + 1));
            end else if (id inside {w_store}) begin
                logger::log(DEBUG, $sformatf("Dropped write ID=%0d: AW + %0d/%0d W beats, no B",
                    id, w_store[id].data.size(), aw_store[id].len + 1));
            end else begin
                logger::log(DEBUG, $sformatf("Dropped write ID=%0d: AW only, no W or B", id));
            end
        end

        // Log discarded read transactions.
        foreach (ar_store[id]) begin
            if (id inside {r_store}) begin
                logger::log(DEBUG, $sformatf("Dropped read ID=%0d: AR + %0d/%0d R beats pending",
                    id, r_store[id].data.size(), ar_store[id].len + 1));
            end else begin
                logger::log(DEBUG, $sformatf("Dropped read ID=%0d: AR only, no R beats", id));
            end
        end

        aw_store.delete();
        w_store.delete();
        b_store.delete();
        ar_store.delete();
        r_store.delete();
        aw_pending_ids.delete();
    endfunction

    // Sample AW channel — captures write address on handshake.
    task automatic sample_aw();
        int id;
        forever begin
            @(posedge vif.monitor_cb);
            if (vif.monitor_cb.AWVALID && vif.monitor_cb.AWREADY) begin
                id = vif.monitor_cb.AWID;
                aw_store[id].addr  = vif.monitor_cb.AWADDR;
                aw_store[id].id    = vif.monitor_cb.AWID;
                aw_store[id].len   = vif.monitor_cb.AWLEN;
                aw_store[id].size  = vif.monitor_cb.AWSIZE;
                aw_store[id].burst = vif.monitor_cb.AWBURST;
                aw_store[id].lock  = vif.monitor_cb.AWLOCK;
                aw_store[id].cache = vif.monitor_cb.AWCACHE;
                aw_store[id].prot  = vif.monitor_cb.AWPROT;
                aw_store[id].qos   = vif.monitor_cb.AWQOS;
                aw_store[id].region = vif.monitor_cb.AWREGION;
                aw_pending_ids.push_back(id);
            end
        end
    endtask

    // Sample W channel — collects write data beats until WLAST.
    // W channel has no ID; beats belong to the oldest uncompleted AW (FIFO order).
    task automatic sample_w();
        int id;
        forever begin
            @(posedge vif.monitor_cb);
            if (vif.monitor_cb.WVALID && vif.monitor_cb.WREADY) begin
                if (aw_pending_ids.size() == 0) continue;
                id = aw_pending_ids[0];

                if (!(id inside {w_store})) begin
                    w_store[id].last_received = 1'b0;
                end
                w_store[id].data.push_back(vif.monitor_cb.WDATA);
                w_store[id].strb.push_back(vif.monitor_cb.WSTRB);
                if (vif.monitor_cb.WLAST || !HAS_BURST) begin
                    w_store[id].last_received = 1'b1;
                    aw_pending_ids.pop_front();
                end
                // Check if write transaction can be completed.
                try_complete_write(id);
            end
        end
    endtask

    // Sample B channel — captures write response.
    task automatic sample_b();
        int id;
        forever begin
            @(posedge vif.monitor_cb);
            if (vif.monitor_cb.BVALID && vif.monitor_cb.BREADY) begin
                id = vif.monitor_cb.BID;
                if (!(id inside {b_store})) begin
                    b_store[id].received = 1'b0;
                end
                b_store[id].id = vif.monitor_cb.BID;
                b_store[id].resp = vif.monitor_cb.BRESP;
                b_store[id].received = 1'b1;
                // Check if write transaction can be completed.
                try_complete_write(id);
            end
        end
    endtask

    // Sample AR channel — captures read address on handshake.
    task automatic sample_ar();
        int id;
        forever begin
            @(posedge vif.monitor_cb);
            if (vif.monitor_cb.ARVALID && vif.monitor_cb.ARREADY) begin
                id = vif.monitor_cb.ARID;
                ar_store[id].addr  = vif.monitor_cb.ARADDR;
                ar_store[id].id    = vif.monitor_cb.ARID;
                ar_store[id].len   = vif.monitor_cb.ARLEN;
                ar_store[id].size  = vif.monitor_cb.ARSIZE;
                ar_store[id].burst = vif.monitor_cb.ARBURST;
                ar_store[id].lock  = vif.monitor_cb.ARLOCK;
                ar_store[id].cache = vif.monitor_cb.ARCACHE;
                ar_store[id].prot  = vif.monitor_cb.ARPROT;
                ar_store[id].qos   = vif.monitor_cb.ARQOS;
                ar_store[id].region = vif.monitor_cb.ARREGION;
            end
        end
    endtask

    // Sample R channel — collects read data beats until RLAST.
    task automatic sample_r();
        int id;
        forever begin
            @(posedge vif.monitor_cb);
            if (vif.monitor_cb.RVALID && vif.monitor_cb.RREADY) begin
                id = vif.monitor_cb.RID;
                if (!(id inside {r_store})) begin
                    r_store[id].last_received = 1'b0;
                end
                r_store[id].data.push_back(vif.monitor_cb.RDATA);
                r_store[id].resp.push_back(vif.monitor_cb.RRESP);
                if (vif.monitor_cb.RLAST || !HAS_BURST) begin
                    r_store[id].last_received = 1'b1;
                end
                // Check if read transaction can be completed.
                try_complete_read(id);
            end
        end
    endtask

    // Check if all components for a write transaction are available and emit if complete.
    function void try_complete_write(int id);
        axi_write_txn txn;
        int i;

        if (!(id inside {aw_store})) return;
        if (!(id inside {w_store})) return;
        if (!w_store[id].last_received) return;
        if (!(id inside {b_store})) return;
        if (!b_store[id].received) return;

        // All components available — construct transaction.
        txn = new(this.next_txn_id++);
        txn.addr  = aw_store[id].addr;
        txn.id    = aw_store[id].id;
        txn.len   = aw_store[id].len;
        txn.size  = aw_store[id].size;
        txn.burst = aw_store[id].burst;
        txn.lock  = aw_store[id].lock;
        txn.cache = aw_store[id].cache;
        txn.prot  = aw_store[id].prot;
        txn.qos   = aw_store[id].qos;
        txn.region = aw_store[id].region;
        txn.resp  = b_store[id].resp;

        // Copy W channel data.
        txn.data = new[w_store[id].data.size()];
        txn.strb = new[w_store[id].strb.size()];
        for (i = 0; i < w_store[id].data.size(); i++) begin
            txn.data[i] = w_store[id].data[i];
            txn.strb[i] = w_store[id].strb[i];
        end

        logger::log(INFO, $sformatf("WRITE complete: addr=0x%0h, id=%0d, beats=%0d, resp=%s",
            txn.addr, txn.id, txn.data.size(), txn.resp.name()), txn.txn_id);

        ap.write(txn);

        // Clean up stores.
        aw_store.delete(id);
        w_store.delete(id);
        b_store.delete(id);
    endfunction

    // Check if all components for a read transaction are available and emit if complete.
    function void try_complete_read(int id);
        axi_read_txn txn;
        int i;

        if (!(id inside {ar_store})) return;
        if (!(id inside {r_store})) return;
        if (!r_store[id].last_received) return;

        // All components available — construct transaction.
        txn = new(this.next_txn_id++);
        txn.addr  = ar_store[id].addr;
        txn.id    = ar_store[id].id;
        txn.len   = ar_store[id].len;
        txn.size  = ar_store[id].size;
        txn.burst = ar_store[id].burst;
        txn.lock  = ar_store[id].lock;
        txn.cache = ar_store[id].cache;
        txn.prot  = ar_store[id].prot;
        txn.qos   = ar_store[id].qos;
        txn.region = ar_store[id].region;

        // Copy R channel data.
        txn.data = new[r_store[id].data.size()];
        txn.resp = new[r_store[id].resp.size()];
        for (i = 0; i < r_store[id].data.size(); i++) begin
            txn.data[i] = r_store[id].data[i];
            txn.resp[i] = r_store[id].resp[i];
        end

        logger::log(INFO, $sformatf("READ complete: addr=0x%0h, id=%0d, beats=%0d",
            txn.addr, txn.id, txn.data.size()), txn.txn_id);

        ap.write(txn);

        // Clean up stores.
        ar_store.delete(id);
        r_store.delete(id);
    endfunction

    // Main monitor loop — launches sampler tasks and handles reset.
    task automatic run();
        if (this.vif == null) begin
            logger::log(FATAL, "AXI monitor run() called but interface not set");
            return;
        end

        fork
            sample_aw();
            sample_w();
            sample_b();
            sample_ar();
            sample_r();
        join_none

        // Monitor reset — clear state on ARESETn deassertion.
        forever begin
            @(posedge vif.ACLK);
            if (vif.ARESETn === 1'b0) begin
                reset_state();
            end
        end
    endtask

endclass

`endif
