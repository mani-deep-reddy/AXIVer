import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import logger_pkg::*;
import hooks_pkg::*;

class axi_slave_transactor;

    virtual axi_if vif;                                 // virtual interface handle
    analysis_port #(axi_write_txn) write_ap;            // analysis port for completed writes
    analysis_port #(axi_read_txn)  read_ap;             // analysis port for completed reads

    // Constructor.
    function new();
        this.write_ap = new();
        this.read_ap  = new();
    endfunction

    // Bind virtual interface for signal monitoring and response driving.
    function void set_interface(virtual axi_if vif);
        this.vif = vif;
    endfunction

    // Get analysis port for write transactions.
    function analysis_port #(axi_write_txn) get_write_analysis_port();
        return this.write_ap;
    endfunction

    // Get analysis port for read transactions.
    function analysis_port #(axi_read_txn) get_read_analysis_port();
        return this.read_ap;
    endfunction

    // Drive AWREADY and capture AW fields when handshake occurs.
    task automatic capture_aw(
        output logic [ADDR_WIDTH-1:0] addr,
        output logic [ID_WIDTH-1:0]   id,
        output logic [7:0]            len,
        output logic [2:0]            size,
        output burst_t                burst,
        output lock_t                 lock,
        output cache_t                cache,
        output prot_t                 prot,
        output logic [3:0]            qos,
        output logic [3:0]            region
    );
        this.vif.AWREADY = 1'b1;
        while (!this.vif.AWVALID) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        addr   = this.vif.AWADDR;
        id     = this.vif.AWID;
        len    = this.vif.AWLEN;
        size   = this.vif.AWSIZE;
        burst  = this.vif.AWBURST;
        lock   = this.vif.AWLOCK;
        cache  = this.vif.AWCACHE;
        prot   = this.vif.AWPROT;
        qos    = this.vif.AWQOS;
        region = this.vif.AWREGION;
        this.vif.AWREADY = 1'b0;
    endtask

    // Capture W channel beats until WLAST.
    task automatic capture_w_beats(
        input  logic [7:0] len,
        output logic [DATA_WIDTH-1:0] data[],
        output logic [STRB_WIDTH-1:0] strb[]
    );
        int num_beats;
        int i;

        num_beats = len + 1;
        if (num_beats == 0) num_beats = 1;
        data = new[num_beats];
        strb = new[num_beats];

        this.vif.WREADY = 1'b1;

        for (i = 0; i < num_beats; i++) begin
            while (!this.vif.WVALID) begin
                @(posedge this.vif.ACLK);
            end
            @(posedge this.vif.ACLK);
            data[i] = this.vif.WDATA;
            strb[i] = this.vif.WSTRB;
        end

        this.vif.WREADY = 1'b0;
    endtask

    // Drive B response handshake.
    task automatic drive_b_response(
        input logic [ID_WIDTH-1:0] id,
        input resp_t               resp
    );
        this.vif.BID   = id;
        this.vif.BRESP = resp;
        this.vif.BVALID = 1'b1;
        this.vif.BUSER = {USER_WIDTH{1'b0}};

        while (!this.vif.BREADY) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        this.vif.BVALID = 1'b0;
    endtask

    // Drive ARREADY and capture AR fields.
    task automatic capture_ar(
        output logic [ADDR_WIDTH-1:0] addr,
        output logic [ID_WIDTH-1:0]   id,
        output logic [7:0]            len,
        output logic [2:0]            size,
        output burst_t                burst,
        output lock_t                 lock,
        output cache_t                cache,
        output prot_t                 prot,
        output logic [3:0]            qos,
        output logic [3:0]            region
    );
        this.vif.ARREADY = 1'b1;
        while (!this.vif.ARVALID) begin
            @(posedge this.vif.ACLK);
        end
        @(posedge this.vif.ACLK);
        addr   = this.vif.ARADDR;
        id     = this.vif.ARID;
        len    = this.vif.ARLEN;
        size   = this.vif.ARSIZE;
        burst  = this.vif.ARBURST;
        lock   = this.vif.ARLOCK;
        cache  = this.vif.ARCACHE;
        prot   = this.vif.ARPROT;
        qos    = this.vif.ARQOS;
        region = this.vif.ARREGION;
        this.vif.ARREADY = 1'b0;
    endtask

    // Drive R channel beats with placeholder data.
    task automatic drive_r_beats(
        input  logic [ID_WIDTH-1:0]   id,
        input  logic [7:0]            len,
        input  logic [2:0]            size,
        input  burst_t                burst,
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data[],
        output resp_t                 resp[]
    );
        int num_beats;
        int beat_size;
        logic [ADDR_WIDTH-1:0] cur_addr;
        int i;

        num_beats = len + 1;
        if (num_beats == 0) num_beats = 1;
        beat_size = 1 << size;
        cur_addr = addr;

        data = new[num_beats];
        resp = new[num_beats];

        for (i = 0; i < num_beats; i++) begin
            data[i] = {DATA_WIDTH{1'b0}};
            resp[i] = OKAY;

            this.vif.RID   = id;
            this.vif.RDATA = data[i];
            this.vif.RRESP = resp[i];
            this.vif.RLAST = (i == num_beats - 1) ? 1'b1 : 1'b0;
            this.vif.RUSER = {USER_WIDTH{1'b0}};
            this.vif.RVALID = 1'b1;

            while (!this.vif.RREADY) begin
                @(posedge this.vif.ACLK);
            end
            @(posedge this.vif.ACLK);
            this.vif.RVALID = 1'b0;
        end
    endtask

    // Main loop — monitors AW and AR channels, captures requests, generates responses.
    task automatic run();
        logic [ADDR_WIDTH-1:0]  addr;
        logic [ID_WIDTH-1:0]    id;
        logic [7:0]             len;
        logic [2:0]             size;
        burst_t                 burst;
        lock_t                  lock;
        cache_t                 cache;
        prot_t                  prot;
        logic [3:0]             qos;
        logic [3:0]             region;
        logic [DATA_WIDTH-1:0]  data[];
        logic [STRB_WIDTH-1:0]  strb[];
        resp_t                  rresp[];
        axi_write_txn           wtxn;
        axi_read_txn            rtxn;

        if (this.vif == null) begin
            logger::log(FATAL, "SLAVE run() called but interface not set");
            return;
        end

        forever begin
            @(posedge this.vif.ACLK);

            if (this.vif.AWVALID) begin
                capture_aw(addr, id, len, size, burst, lock, cache, prot, qos, region);
                logger::log(INFO, $sformatf("SLAVE WRITE captured: addr=0x%0h, id=%0d, beats=%0d", addr, id, len + 1));

                capture_w_beats(len, data, strb);

                // Assemble write transaction.
                wtxn = new(0);
                wtxn.addr   = addr;
                wtxn.id     = id;
                wtxn.len    = len;
                wtxn.size   = size;
                wtxn.burst  = burst;
                wtxn.lock   = lock;
                wtxn.cache  = cache;
                wtxn.prot   = prot;
                wtxn.qos    = qos;
                wtxn.region = region;
                wtxn.data   = data;
                wtxn.strb   = strb;

                drive_b_response(id, OKAY);
                wtxn.resp = OKAY;
                logger::log(INFO, "SLAVE WRITE B response sent");

                this.write_ap.write(wtxn);
            end

            if (this.vif.ARVALID) begin
                capture_ar(addr, id, len, size, burst, lock, cache, prot, qos, region);
                logger::log(INFO, $sformatf("SLAVE READ captured: addr=0x%0h, id=%0d, beats=%0d", addr, id, len + 1));

                drive_r_beats(id, len, size, burst, addr, data, rresp);
                logger::log(INFO, $sformatf("SLAVE READ complete: beats=%0d", len + 1));

                // Assemble read transaction.
                rtxn = new(0);
                rtxn.addr   = addr;
                rtxn.id     = id;
                rtxn.len    = len;
                rtxn.size   = size;
                rtxn.burst  = burst;
                rtxn.lock   = lock;
                rtxn.cache  = cache;
                rtxn.prot   = prot;
                rtxn.qos    = qos;
                rtxn.region = region;
                rtxn.data   = data;
                rtxn.resp   = rresp;

                this.read_ap.write(rtxn);
            end
        end
    endtask

endclass
