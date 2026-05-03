import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import logger_pkg::*;
import hooks_pkg::*;

class axi_master_transactor;

    virtual axi_if vif;                     // virtual interface handle
    mailbox txn_queue;                      // transaction intake queue
    analysis_port #(axi_transaction) ap;     // analysis port for completed transactions
    int unsigned max_outstanding;           // max concurrent in-flight transactions
    int unsigned outstanding_count;         // current in-flight transaction count

    // Constructor with configurable outstanding transaction limit.
    function new(int unsigned max_out = 0);
        if (max_out == 0) begin
            this.max_outstanding = MAX_OUTSTANDING_TXNS;
        end else begin
            this.max_outstanding = max_out;
        end
        this.outstanding_count = 0;
        this.txn_queue = new();
        this.ap = new();
    endfunction

    // Bind virtual interface for signal driving.
    function void set_interface(virtual axi_if vif);
        this.vif = vif;
    endfunction

    // Get analysis port for subscriber connections.
    function analysis_port #(axi_transaction) get_analysis_port();
        return this.ap;
    endfunction

    // Wait for AW channel handshake with backpressure handling.
    task automatic drive_aw_handshake();
        this.vif.AWVALID = 1'b1;
        while (!this.vif.AWREADY) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        this.vif.AWVALID = 1'b0;
    endtask

    // Wait for W channel handshake for a single beat.
    task automatic drive_w_beat_handshake();
        this.vif.WVALID = 1'b1;
        while (!this.vif.WREADY) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        this.vif.WVALID = 1'b0;
    endtask

    // Wait for B channel handshake to complete.
    task automatic wait_b_response();
        this.vif.BREADY = 1'b1;
        while (!this.vif.BVALID) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        this.vif.BREADY = 1'b0;
    endtask

    // Compute next address based on burst type, size, and beat index.
    function automatic logic [ADDR_WIDTH-1:0] calc_next_addr(
        input logic [ADDR_WIDTH-1:0] base_addr,
        input logic [2:0]            size,
        input burst_t                burst,
        input int unsigned           beat_idx,
        input logic [7:0]            len
    );
        int unsigned beat_size;
        logic [ADDR_WIDTH-1:0] wrap_boundary;

        beat_size = 1 << size;
        if (burst == FIXED) begin
            return base_addr;
        end else if (burst == INCR) begin
            return base_addr + (beat_idx * beat_size);
        end else begin
            // WRAP: wraps at boundary of len+1 beats * beat_size
            wrap_boundary = (len + 1) * beat_size;
            return (base_addr + (beat_idx * beat_size)) & (wrap_boundary - 1);
        end
    endfunction

    // Drive a complete AXI write transaction (AW + W + B).
    task automatic drive_write(axi_write_txn txn);
        logic [ADDR_WIDTH-1:0] cur_addr;
        int beat_size;
        int num_beats;
        int i;

        if (this.vif == null) begin
            logger::log(FATAL, "WRITE dispatched but interface not set");
            return;
        end

        logger::log(INFO, $sformatf("WRITE start: addr=0x%0h, id=%0d, beats=%0d", txn.addr, txn.id, txn.data.size()), txn.txn_id);

        // Drive AW channel.
        this.vif.AWID     = txn.id;
        this.vif.AWADDR   = txn.addr;
        this.vif.AWLEN    = txn.len;
        this.vif.AWSIZE   = txn.size;
        this.vif.AWBURST  = txn.burst;
        this.vif.AWLOCK   = txn.lock;
        this.vif.AWCACHE  = txn.cache;
        this.vif.AWPROT   = txn.prot;
        this.vif.AWQOS    = txn.qos;
        this.vif.AWREGION = txn.region;
        this.vif.AWUSER   = {USER_WIDTH{1'b0}};

        drive_aw_handshake();

        // Drive W channel beats.
        num_beats = txn.data.size();
        if (num_beats == 0) num_beats = 1;
        beat_size = (1 << txn.size);
        cur_addr = txn.addr;

        for (i = 0; i < num_beats; i++) begin
            logger::log(DEBUG, $sformatf("WRITE beat %0d/%0d", i, num_beats), txn.txn_id);

            if (i + 1 < num_beats) begin
                cur_addr = calc_next_addr(txn.addr, txn.size, txn.burst, i + 1, txn.len);
            end

            this.vif.WDATA = txn.data[i];
            this.vif.WSTRB = txn.strb[i];
            this.vif.WLAST = (i == num_beats - 1) ? 1'b1 : 1'b0;
            this.vif.WUSER = {USER_WIDTH{1'b0}};

            drive_w_beat_handshake();
        end

        // Wait for B response.
        wait_b_response();
        txn.resp = this.vif.BRESP;

        logger::log(INFO, $sformatf("WRITE complete: resp=%s", txn.resp.name()), txn.txn_id);

        // Publish completed transaction.
        this.ap.write(txn);
    endtask

    // Wait for AR channel handshake.
    task automatic drive_ar_handshake();
        this.vif.ARVALID = 1'b1;
        while (!this.vif.ARREADY) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        this.vif.ARVALID = 1'b0;
    endtask

    // Wait for R channel beats and capture data.
    task automatic receive_r_beats(axi_read_txn txn);
        logic [ADDR_WIDTH-1:0] cur_addr;
        int num_beats;
        int beat_size;
        int i;

        num_beats = txn.len + 1;
        if (num_beats == 0) num_beats = 1;
        beat_size = 1 << txn.size;
        cur_addr = txn.addr;

        txn.data = new[num_beats];
        txn.resp = new[num_beats];

        this.vif.RREADY = 1'b1;

        for (i = 0; i < num_beats; i++) begin
            logger::log(DEBUG, $sformatf("READ beat %0d/%0d", i, num_beats), txn.txn_id);

            while (!this.vif.RVALID) begin
                @(posedge this.vif.ACLK);
            end
            @(posedge this.vif.ACLK);

            txn.data[i] = this.vif.RDATA;
            txn.resp[i] = this.vif.RRESP;

            if (this.vif.RLAST !== 1'b1) begin
                // More beats expected — continue.
            end
        end

        this.vif.RREADY = 1'b0;

        logger::log(INFO, $sformatf("READ complete: beats=%0d", num_beats), txn.txn_id);
    endtask

    // Drive a complete AXI read transaction (AR + R).
    task automatic drive_read(axi_read_txn txn);
        logger::log(INFO, $sformatf("READ start: addr=0x%0h, id=%0d, len=%0d", txn.addr, txn.id, txn.len), txn.txn_id);

        // Drive AR channel.
        this.vif.ARID     = txn.id;
        this.vif.ARADDR   = txn.addr;
        this.vif.ARLEN    = txn.len;
        this.vif.ARSIZE   = txn.size;
        this.vif.ARBURST  = txn.burst;
        this.vif.ARLOCK   = txn.lock;
        this.vif.ARCACHE  = txn.cache;
        this.vif.ARPROT   = txn.prot;
        this.vif.ARQOS    = txn.qos;
        this.vif.ARREGION = txn.region;
        this.vif.ARUSER   = {USER_WIDTH{1'b0}};

        drive_ar_handshake();

        // Receive R channel beats.
        receive_r_beats(txn);

        // Publish completed transaction.
        this.ap.write(txn);
    endtask

    // Main scheduler loop — drains mailbox and dispatches transactions.
    task automatic run();
        axi_transaction txn;
        axi_write_txn   wtxn;
        axi_read_txn    rtxn;

        forever begin
            txn_queue.get(txn);

            // Wait if outstanding limit reached.
            while (outstanding_count >= max_outstanding) begin
                @(posedge vif.ACLK);
            end

            outstanding_count++;

            if ($cast(wtxn, txn)) begin
                fork
                    automatic axi_write_txn wt = wtxn;
                    begin
                        drive_write(wt);
                        outstanding_count--;
                    end
                join_none
            end else if ($cast(rtxn, txn)) begin
                fork
                    automatic axi_read_txn rt = rtxn;
                    begin
                        drive_read(rt);
                        outstanding_count--;
                    end
                join_none
            end else begin
                logger::log(ERROR, "Unknown transaction type in mailbox");
                outstanding_count--;
            end
        end
    endtask

endclass
