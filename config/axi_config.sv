package axi_config_pkg;

    // Protocol variant: FULL (AXI4), LITE (AXI4-Lite), STREAM (AXI-Stream)
    parameter AXI_TYPE = "FULL";

    localparam AXI_FULL   = "FULL";
    localparam AXI_LITE   = "LITE";
    localparam AXI_STREAM = "STREAM";

    // Width of the address bus
    parameter ADDR_WIDTH = 32;

    // Width of the data bus
    parameter DATA_WIDTH = 32;

    // Width of the transaction ID for ordering and matching responses
    parameter ID_WIDTH = 4;

    // Width of optional user-defined sideband signals
    parameter USER_WIDTH = 1;

    // Byte strobe width (DATA_WIDTH / 8), indicates valid bytes per beat
    localparam STRB_WIDTH = DATA_WIDTH / 8;

    // Enables burst transactions (required for AXI4 Full)
    parameter HAS_BURST = 1;

    // Enables exclusive access (atomic operations)
    parameter HAS_LOCK = 1;

    // Enables cache attribute signaling (ARCACHE/AWCACHE)
    parameter HAS_CACHE = 1;

    // Enables protection signaling (ARPROT/AWPROT)
    parameter HAS_PROT = 1;

    // Enables Quality-of-Service signaling
    parameter HAS_QOS = 1;

    // Enables region-based addressing support
    parameter HAS_REGION = 1;

    // Maximum number of concurrent in-flight transactions
    parameter MAX_OUTSTANDING_TXNS = 16;

    // Maximum burst length (AXI4 allows up to 256 beats)
    parameter MAX_BURST_LEN = 256;

    // Allows transfers smaller than DATA_WIDTH
    parameter SUPPORTS_NARROW_BURST = 1;

    // Allows unaligned memory accesses
    parameter SUPPORTS_UNALIGNED = 0;

endpackage
