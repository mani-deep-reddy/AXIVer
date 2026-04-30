package axi_types_pkg;


    typedef enum bit [1:0] {
        OKAY   = 2'b00,  // Normal successful transaction
        EXOKAY = 2'b01,  // Exclusive access successful
        SLVERR = 2'b10,  // Slave generated error
        DECERR = 2'b11   // Decode error (invalid address)
    } resp_t;

    typedef enum bit [1:0] {
        FIXED = 2'b00,  // Address remains constant
        INCR  = 2'b01,  // Address increments each beat
        WRAP  = 2'b10   // Address wraps around boundary
    } burst_t;

    typedef enum bit {
        NORMAL    = 1'b0,  // Normal access
        EXCLUSIVE = 1'b1   // Exclusive access (atomic operation)
    } lock_t;

    typedef enum bit {
        READ  = 1'b0,  // Read transaction
        WRITE = 1'b1   // Write transaction
    } txn_dir_t;

    // Protection type: privileged (access level), secure (security level), instr_data (instruction or data)
    typedef struct packed {
        logic privileged;   // Access level (privileged/unprivileged)
        logic secure;       // Secure or non-secure access
        logic instr_data;   // Whether access is instruction or data
    } prot_t;

    // Cache type (ARCACHE/AWCACHE): bufferable, cacheable, allocate hints
    typedef struct packed {
        logic bufferable;   // Write buffering allowed
        logic modifiable;   // Cacheable region
        logic read_alloc;   // Allocation policy hint (read)
        logic write_alloc;  // Allocation policy hint (write)
    } cache_t;

endpackage
