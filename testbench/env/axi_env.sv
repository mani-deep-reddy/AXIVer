// AXI environment — central coordination layer for verification components.

import axi_config_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import hooks_pkg::*;
import logger_pkg::*;
import scoreboard_pkg::*;

class axi_env;

    // Component handles.
    axi_master_transactor master;
    axi_slave_transactor  slave;
    axi_monitor           monitor;
    axi_scoreboard        scoreboard;

    // Virtual interface for distribution to components.
    virtual axi_if vif;

    // Constructor.
    function new();
        logger::log(INFO, "AXI environment created");
    endfunction

    // Store virtual interface handle for later distribution.
    function void set_interface(virtual axi_if vif);
        this.vif = vif;
    endfunction

    // Build phase — construct all component instances.
    function void build();
        logger::log(INFO, "Environment: build phase");
        this.master    = new();
        this.slave     = new();
        this.monitor   = new();
        this.scoreboard = new();
    endfunction

    // Connect phase — distribute interfaces and wire analysis ports.
    function void connect();
        logger::log(INFO, "Environment: connect phase");

        // Distribute virtual interface to master and monitor.
        master.set_interface(this.vif);
        monitor.set_interface(this.vif);

        // Slave transactor intentionally NOT connected to interface.
        // The DUT (axi_ram) handles slave-side AXI behavior; connecting
        // the slave transactor would create multiple drivers on the same
        // signals (AWREADY, WREADY, BVALID, etc.).
        // Slave is available for future loopback-mode testing without a DUT.
        logger::log(INFO, "Environment: slave transactor not connected (DUT handles slave side)");

        // Wire monitor analysis port to scoreboard actual subscriber.
        // The monitor publishes observed transactions; the scoreboard
        // receives them as "actual" data for comparison.
        monitor.get_analysis_port().connect(scoreboard.get_actual_subscriber());

        logger::log(INFO, "Environment: monitor → scoreboard connected");
    endfunction

    // Run phase — launch all active components concurrently.
    task run();
        logger::log(INFO, "Environment: run phase — launching components");

        fork
            master.run();
            monitor.run();
            scoreboard.run_compare();
        join_none

        // Slave transactor intentionally excluded from run().
        // Since it is not connected to the interface (DUT handles slave side),
        // calling run() would hit a FATAL log for null interface.
        // In loopback mode (no DUT), call slave.set_interface(vif) and
        // add slave.run() to the fork block above.
    endtask

endclass
