import axi_config_pkg::*;
import axi_stream_txn_pkg::*;
import logger_pkg::*;
import hooks_pkg::*;

localparam KEEP_WIDTH = DATA_WIDTH / 8;

class axi_stream_transactor;

    virtual axi_stream_if vif;                    // virtual stream interface handle
    mailbox #(axi_stream_txn) txn_queue;          // transaction intake queue
    analysis_port #(axi_stream_txn) ap;           // analysis port for completed transactions

    // Constructor.
    function new();
        this.txn_queue = new();
        this.ap = new();
    endfunction

    // Bind virtual stream interface for signal driving.
    function void set_stream_interface(virtual axi_stream_if vif);
        this.vif = vif;
    endfunction

    // Get analysis port for subscriber connections.
    function analysis_port #(axi_stream_txn) get_analysis_port();
        return this.ap;
    endfunction

    // Drive a single stream beat with TREADY handshake.
    task automatic drive_beat(
        input  logic [DATA_WIDTH-1:0] tdata,
        input  logic [KEEP_WIDTH-1:0] tkeep,
        input  logic [KEEP_WIDTH-1:0] tstrb,
        input  bit                    tlast,
        input  logic [USER_WIDTH-1:0] tuser
    );
        this.vif.TDATA  = tdata;
        this.vif.TKEEP  = tkeep;
        this.vif.TSTRB  = tstrb;
        this.vif.TLAST  = tlast ? 1'b1 : 1'b0;
        if (USER_WIDTH > 0) begin
            this.vif.TUSER = tuser;
        end
        this.vif.TVALID = 1'b1;

        while (!this.vif.TREADY) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        this.vif.TVALID = 1'b0;
    endtask

    // Drive a complete stream packet from a transaction.
    task automatic drive_packet(axi_stream_txn txn);
        int num_beats;
        int i;
        bit is_last;

        num_beats = txn.data.size();
        if (num_beats == 0) return;

        logger::log(INFO, $sformatf("STREAM start: beats=%0d", num_beats), txn.txn_id);

        for (i = 0; i < num_beats; i++) begin
            is_last = (i == num_beats - 1) ? 1'b1 : txn.last[i];

            logger::log(DEBUG, $sformatf("STREAM beat %0d/%0d", i, num_beats), txn.txn_id);

            drive_beat(txn.data[i], txn.keep[i], txn.strb[i], is_last,
                       (USER_WIDTH > 0) ? txn.user[i] : {USER_WIDTH{1'b0}});
        end

        logger::log(INFO, $sformatf("STREAM complete: beats=%0d", num_beats), txn.txn_id);

        this.ap.write(txn);
    endtask

    // Main loop — drains mailbox and drives stream packets.
    task automatic run();
        axi_stream_txn txn;

        if (this.vif == null) begin
            logger::log(FATAL, "STREAM run() called but interface not set");
            return;
        end

        forever begin
            txn_queue.get(txn);
            drive_packet(txn);
        end
    endtask

endclass
