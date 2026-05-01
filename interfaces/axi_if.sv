// AXI4 Full/Lite parameterized interface with role-based modports.

interface axi_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter USER_WIDTH = 1,
    parameter HAS_BURST  = 1
)(
    input logic ACLK,
    input logic ARESETn
);

    import axi_types_pkg::resp_t;
    import axi_types_pkg::burst_t;
    import axi_types_pkg::lock_t;
    import axi_types_pkg::prot_t;
    import axi_types_pkg::cache_t;

    localparam STRB_WIDTH = DATA_WIDTH / 8;

    // Derived widths for optional signals — evaluate to 0 when feature is off.
    localparam ID_W       = (ID_WIDTH > 0) ? ID_WIDTH : 0;
    localparam LEN_W      = HAS_BURST ? 8 : 0;
    localparam SZ_W       = HAS_BURST ? 3 : 0;
    localparam LAST_W     = HAS_BURST ? 1 : 0;

    // verilator lint_off ASCRANGE

    // Write Address Channel (AW)
    logic [ID_W-1:0]       AWID;       // transaction ID
    logic [ADDR_WIDTH-1:0] AWADDR;     // write address
    logic [LEN_W-1:0]      AWLEN;      // burst length
    logic [SZ_W-1:0]       AWSIZE;     // burst size
    burst_t                AWBURST;    // burst type
    lock_t                 AWLOCK;     // exclusive access
    cache_t                AWCACHE;    // cache attribute
    prot_t                 AWPROT;     // protection type
    logic [3:0]            AWQOS;      // quality of service
    logic [3:0]            AWREGION;   // region identifier
    logic                  AWVALID;    // write address valid
    logic                  AWREADY;    // write address ready
    logic [USER_WIDTH-1:0] AWUSER;     // write address user

    // Write Data Channel (W)
    logic [DATA_WIDTH-1:0] WDATA;      // write data
    logic [STRB_WIDTH-1:0] WSTRB;      // write strobe
    logic [LAST_W-1:0]     WLAST;      // write last
    logic                  WVALID;     // write data valid
    logic                  WREADY;     // write data ready
    logic [USER_WIDTH-1:0] WUSER;      // write data user

    // Write Response Channel (B)
    logic [ID_W-1:0]       BID;        // response ID
    resp_t                 BRESP;      // write response
    logic                  BVALID;     // write response valid
    logic                  BREADY;     // write response ready
    logic [USER_WIDTH-1:0] BUSER;      // write response user

    // Read Address Channel (AR)
    logic [ID_W-1:0]       ARID;       // transaction ID
    logic [ADDR_WIDTH-1:0] ARADDR;     // read address
    logic [LEN_W-1:0]      ARLEN;      // burst length
    logic [SZ_W-1:0]       ARSIZE;     // burst size
    burst_t                ARBURST;    // burst type
    lock_t                 ARLOCK;     // exclusive access
    cache_t                ARCACHE;    // cache attribute
    prot_t                 ARPROT;     // protection type
    logic [3:0]            ARQOS;      // quality of service
    logic [3:0]            ARREGION;   // region identifier
    logic                  ARVALID;    // read address valid
    logic                  ARREADY;    // read address ready
    logic [USER_WIDTH-1:0] ARUSER;     // read address user

    // Read Data Channel (R)
    logic [ID_W-1:0]       RID;        // read ID
    logic [DATA_WIDTH-1:0] RDATA;      // read data
    resp_t                 RRESP;      // read response
    logic [LAST_W-1:0]     RLAST;      // read last
    logic                  RVALID;     // read data valid
    logic                  RREADY;     // read data ready
    logic [USER_WIDTH-1:0] RUSER;      // read data user

    // verilator lint_on ASCRANGE

    // Master clocking block — drives commands, samples responses.
    clocking master_cb @(posedge ACLK);
        output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWVALID, AWUSER;
        output WDATA, WSTRB, WLAST, WVALID, WUSER;
        output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARVALID, ARUSER;
        output BREADY, RREADY;
        input  AWREADY, WREADY, BID, BRESP, BUSER, BVALID;
        input  ARREADY, RID, RDATA, RRESP, RUSER, RLAST, RVALID;
    endclocking

    // Slave clocking block — drives responses, samples commands.
    clocking slave_cb @(posedge ACLK);
        output AWREADY, WREADY;
        output BID, BRESP, BUSER, BVALID;
        output ARREADY;
        output RVALID, RDATA, RRESP, RLAST, RUSER;
        input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWVALID, AWUSER;
        input  WDATA, WSTRB, WLAST, WVALID, WUSER;
        input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARVALID, ARUSER;
        input  BREADY, RREADY;
    endclocking

    // Monitor clocking block — samples all signals, no drive.
    clocking monitor_cb @(posedge ACLK);
        input AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWVALID, AWREADY, AWUSER;
        input WDATA, WSTRB, WLAST, WVALID, WREADY, WUSER;
        input BID, BRESP, BVALID, BREADY, BUSER;
        input ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARVALID, ARREADY, ARUSER;
        input RID, RDATA, RRESP, RLAST, RVALID, RREADY, RUSER;
    endclocking

    // Master modport — used by testbench drivers and masters.
    modport MASTER (
        output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWVALID, AWUSER,
        output WDATA, WSTRB, WLAST, WVALID, WUSER,
        output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARVALID, ARUSER,
        output BREADY, RREADY,
        input  AWREADY, WREADY,
        input  BID, BRESP, BUSER, BVALID,
        input  ARREADY,
        input  RID, RDATA, RRESP, RUSER, RLAST, RVALID
    );

    // Slave modport — used by DUT and slave models.
    modport SLAVE (
        output AWREADY, WREADY,
        output BID, BRESP, BUSER, BVALID,
        output ARREADY,
        output RVALID, RDATA, RRESP, RLAST, RUSER,
        input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWVALID, AWUSER,
        input  WDATA, WSTRB, WLAST, WVALID, WUSER,
        input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARVALID, ARUSER,
        input  BREADY, RREADY
    );

    // Monitor modport — used by monitors and scoreboards.
    modport MONITOR (
        input AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWVALID, AWREADY, AWUSER,
        input WDATA, WSTRB, WLAST, WVALID, WREADY, WUSER,
        input BID, BRESP, BVALID, BREADY, BUSER,
        input ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARVALID, ARREADY, ARUSER,
        input RID, RDATA, RRESP, RLAST, RVALID, RREADY, RUSER
    );

endinterface
