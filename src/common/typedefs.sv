`ifndef COMMON_TYPEDEFS_SV
`define COMMON_TYPEDEFS_SV

// Shared framework types used across all modules. No AXI-specific types.

package common_pkg;

    // Transaction metadata for tracking and log correlation.
    typedef struct {
        int     txn_id;    // unique identifier
        time    timestamp; // simulation time of creation
    } txn_meta_t;

    // Final verification result of a transaction.
    typedef enum {
        TXN_PASS,     // correct behavior
        TXN_FAIL,     // failed
        TXN_TIMEOUT,  // no response received
        TXN_MISMATCH  // data mismatch
    } txn_status_e;

endpackage

`endif
