# Integration Guide

This guide explains how to configure AXIVer for your target protocol, connect your DUT, extend the verification components, and run simulations.

## 1. Configuration

Open `config/axi_config.sv` and set the parameters for your design:

```systemverilog
parameter AXI_TYPE     = "FULL";     // "FULL", "LITE", or "STREAM"
parameter ADDR_WIDTH   = 32;         // Address bus width
parameter DATA_WIDTH   = 32;         // Data bus width
parameter ID_WIDTH     = 4;          // Transaction ID width
parameter USER_WIDTH   = 1;          // User-sideband width
```

### Feature Flags

Enable or disable optional AXI signaling:

```systemverilog
parameter HAS_BURST  = 1;  // Burst support (required for FULL)
parameter HAS_LOCK   = 1;  // Exclusive access
parameter HAS_CACHE  = 1;  // Cache attributes
parameter HAS_PROT   = 1;  // Protection attributes
parameter HAS_QOS    = 1;  // Quality of Service
parameter HAS_REGION = 1;  // Region addressing
```

### System Limits

```systemverilog
parameter MAX_OUTSTANDING_TXNS = 16;   // Max in-flight transactions
parameter MAX_BURST_LEN        = 256;  // Max burst length
parameter SUPPORTS_NARROW_BURST = 1;  // Sub-word transfers
parameter SUPPORTS_UNALIGNED    = 0;  // Unaligned access
```

## 2. Connecting Your DUT

### Option A: Replace the Existing DUT in tb_top.sv

Open `testbench/tb_top.sv` and replace the `axi_ram` DUT instantiation with your own:

```systemverilog
// Replace this:
axi_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(16),
    .ID_WIDTH(ID_WIDTH)
) dut ( ... );

// With your DUT:
your_dut #(
    .DATA_WIDTH(DATA_WIDTH),
    // ... your parameters
) dut (
    // AXI interface signals from axi_intf:
    .aclk      (axi_intf.ACLK),
    .aresetn   (axi_intf.ARESETn),
    .awid      (axi_intf.AWID),
    .awaddr    (axi_intf.AWADDR),
    .awlen     (axi_intf.AWLEN),
    .awsize    (axi_intf.AWSIZE),
    .awburst   (axi_intf.AWBURST),
    .awvalid   (axi_intf.AWVALID),
    .awready   (axi_intf.AWREADY),
    .wdata     (axi_intf.WDATA),
    .wstrb     (axi_intf.WSTRB),
    .wlast     (axi_intf.WLAST),
    .wvalid    (axi_intf.WVALID),
    .wready    (axi_intf.WREADY),
    .bid       (axi_intf.BID),
    .bresp     (axi_intf.BRESP),
    .bvalid    (axi_intf.BVALID),
    .bready    (axi_intf.BREADY),
    .arid      (axi_intf.ARID),
    .araddr    (axi_intf.ARADDR),
    .arlen     (axi_intf.ARLEN),
    .arsize    (axi_intf.ARSIZE),
    .arburst   (axi_intf.ARBURST),
    .arvalid   (axi_intf.ARVALID),
    .arready   (axi_intf.ARREADY),
    .rid       (axi_intf.RID),
    .rdata     (axi_intf.RDATA),
    .rresp     (axi_intf.RRESP),
    .rlast     (axi_intf.RLAST),
    .rvalid    (axi_intf.RVALID),
    .rready    (axi_intf.RREADY)
);
```

### Option B: Create a Custom Testbench

Copy `testbench/tb_top.sv` and customize it. Ensure:
- Clock and reset generation match your DUT's requirements
- The `axi_if` interface is instantiated with matching parameters
- SVA assertions are bound (optional but recommended)
- The `axi_env` is constructed and run

## 3. Extending the Reference Model

The reference model in `user_extensions/reference_model/axi_ref_model.sv` is a golden memory model that should mirror your DUT's behavior. To customize:

1. Modify the internal state representation (currently a word-addressable associative array)
2. Update the `write_beat()` task to match your DUT's write behavior (WSTRB masking, address wrapping, etc.)
3. Update the `read_beat()` task to match your DUT's read behavior
4. The model publishes expected read data via `exp_port` for scoreboard comparison

### Reference Model Architecture

```
write_beat(addr, data, wstrb, burst_type, burst_len)
    → updates internal memory array

read_beat(addr, burst_type, burst_len)
    → looks up internal memory array
    → publishes expected data via exp_port
```

## 4. Customizing the Comparator

The comparator in `user_extensions/custom_compare/user_compare.sv` determines when an expected transaction matches an actual transaction. It delegates to each transaction's built-in `compare()` method by default.

Customize `compare()` if your DUT has specific response behavior (e.g., expected vs. actual addresses might differ due to address translation).

## 5. Configuring Coverage Hooks

The coverage implementation in `user_extensions/coverage/user_coverage.sv` samples functional coverage on each transaction. Modify the covergroup to add or change coverpoints:

```systemverilog
covergroup axi_cg;
    txn_type_cp  : coverpoint txn.txn_dir;      // read / write
    burst_len_cp : coverpoint txn.burst_len;     // 1, 2, 4, 8+ beats
    addr_cp      : coverpoint txn.addr[3:0];     // low address bits
    wstrb_cp     : coverpoint $countones(txn.wstrb); // strobe pattern
endgroup
```

## 6. Writing Tests

Create a new test file in `testbench/tests/`:

```systemverilog
class my_custom_test;
    axi_env env;

    function new();
        env = new();
    endfunction

    task run();
        axi_write_txn wtxn;
        axi_read_txn  rtxn;

        env.build();
        env.connect();

        // Create and send a write transaction
        wtxn = new(0);
        wtxn.addr = 32'h1000;
        wtxn.data = '{32'hDEAD_BEEF};
        wtxn.burst_len = 1;
        env.master.put(wtxn);

        // Create and send a read transaction
        rtxn = new(1);
        rtxn.addr = 32'h1000;
        rtxn.burst_len = 1;
        env.master.put(rtxn);

        // Run the simulation
        env.run();
    endtask
endclass
```

Then register the test in `scripts/filelist.f`:

```
# Add your test file before the test entry
../testbench/tests/my_custom_test.sv
../testbench/tests/basic_rw_test.sv
```

## 7. Building and Running

### Using Make (recommended)

```bash
cd scripts
make              # clean → compile → run → check
```

### Using the Shell Script

```bash
cd scripts
chmod +x run.sh
./run.sh
```

### Make Targets

| Command | Description |
|---------|-------------|
| `make clean` | Remove build artifacts |
| `make compile` | Compile all sources |
| `make run` | Run the simulation |
| `make check` | Check for errors |
| `make all` | Full pipeline (default) |

### Output Files

| File | Description |
|------|-------------|
| `compile.log` | Compilation output |
| `run.log` | Simulation output |
| `waves.shm` | Waveform database (enabled by default) |

## 8. Adding Your DUT's RTL Sources

Add your DUT's RTL files to `scripts/filelist.f` before the test entries:

```
# User DUT
../rtl/my_dut.sv

# AXIVer framework (keep existing entries)
../config/axi_config.sv
...
```

## 9. Protocol-Specific Considerations

| Protocol | Interface | Monitor | Transactor | Assertions |
|----------|-----------|---------|------------|------------|
| AXI4 Full | `axi_if` | `axi_monitor` | `axi_master_transactor` | `axi_assertions` |
| AXI4-Lite | `axi_if` | `axi_monitor` | `axi_master_transactor` | `axi_assertions` |
| AXI-Stream | `axi_stream_if` | `axi_stream_monitor` | `axi_stream_transactor` | `axi_stream_checks` |

For AXI4-Lite: set `AXI_TYPE = "LITE"` and `HAS_BURST = 0`. The monitor and scoreboard use FIFO ordering (no ID tracking).

For AXI-Stream: use `axi_stream_if` interface and `axi_stream_transactor`. Protocol checks are in `axi_stream_checks.sv`.
