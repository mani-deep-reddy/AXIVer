// AXI-Stream parameterized interface for unidirectional data transfer.

interface axi_stream_if #(
    parameter DATA_WIDTH = 32,
    parameter USER_WIDTH = 0
)(
    input logic ACLK,
    input logic ARESETn
);

    localparam KEEP_WIDTH = DATA_WIDTH / 8;

    // Stream data and control signals.
    logic [DATA_WIDTH-1:0] TDATA;    // stream data
    logic                  TVALID;   // data valid
    logic                  TREADY;   // data ready
    logic                  TLAST;    // last transfer in packet
    logic [KEEP_WIDTH-1:0] TKEEP;    // byte keep (valid bytes)
    logic [KEEP_WIDTH-1:0] TSTRB;    // byte strobe
    // verilator lint_off ASCRANGE
    logic [USER_WIDTH-1:0] TUSER;    // user-defined sideband
    // verilator lint_on ASCRANGE

    // Master clocking block — drives stream data, samples ready.
    clocking master_cb @(posedge ACLK);
        output TDATA, TVALID, TLAST, TKEEP, TSTRB, TUSER;
        input  TREADY;
    endclocking

    // Slave clocking block — drives ready, samples stream data.
    clocking slave_cb @(posedge ACLK);
        output TREADY;
        input  TDATA, TVALID, TLAST, TKEEP, TSTRB, TUSER;
    endclocking

    // Monitor clocking block — samples all signals, no drive.
    clocking monitor_cb @(posedge ACLK);
        input TDATA, TVALID, TREADY, TLAST, TKEEP, TSTRB, TUSER;
    endclocking

    // Master modport — used by testbench stream drivers.
    modport MASTER (
        output TDATA, TVALID, TLAST, TKEEP, TSTRB, TUSER,
        input  TREADY
    );

    // Slave modport — used by DUT and stream sinks.
    modport SLAVE (
        output TREADY,
        input  TDATA, TVALID, TLAST, TKEEP, TSTRB, TUSER
    );

    // Monitor modport — used by monitors and scoreboards.
    modport MONITOR (
        input TDATA, TVALID, TREADY, TLAST, TKEEP, TSTRB, TUSER
    );

endinterface
