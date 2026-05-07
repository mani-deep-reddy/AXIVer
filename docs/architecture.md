# Architecture

## Data Flow

```
Test Sequence (basic_rw_test)
       │
       │  puts transaction objects into
       ▼
Master Transactor (mailbox-based BFM)
       │
       │  drives VALID/READY handshake on
       ▼
  ┌─────────────────────────────────────┐
  │          axi_if / axi_stream_if      │
  │  (AW, W, B, AR, R / TDATA, TVALID)  │
  └──────┬──────────────────────┬────────┘
         │                      │
         ▼                      ▼
     DUT (axi_ram)          Monitor (passive observer)
                                │
                                │  publishes reconstructed
                                │  transactions via analysis_port
                                ▼
                    analysis_port ────┬───→ Reference Model (axi_ref_model)
                                      │         │
                                      │         │  publishes expected data
                                      │         │  via exp_port
                                      │         ▼
                                      │    Scoreboard (expected subscriber)
                                      │
                                      └───→ Scoreboard (actual subscriber)
                                                │
                                                │  txn_tracker aligns by
                                                │  ID (FULL) or FIFO (LITE/STREAM)
                                                ▼
                                          user_compare.compare()
                                                │
                                          PASS / FAIL + report
```

## Component Architecture

### Configuration (`config/`)

- **`axi_config_pkg`** (`axi_config.sv`) — Top-level parameter definitions: `AXI_TYPE`, `ADDR_WIDTH`, `DATA_WIDTH`, `ID_WIDTH`, `USER_WIDTH`, feature flags (`HAS_BURST`, `HAS_LOCK`, `HAS_CACHE`, `HAS_PROT`, `HAS_QOS`, `HAS_REGION`), and system limits (`MAX_OUTSTANDING_TXNS`, `MAX_BURST_LEN`).
- **`axi_types_pkg`** (`axi_types.sv`) — Enumerated types (`resp_t`, `burst_t`, `lock_t`, `txn_dir_t`) and packed structs (`prot_t`, `cache_t`).

### Transaction Objects (`src/transaction/`)

Object-oriented transaction model with a base abstract class and three concrete implementations:

- **`axi_transaction`** (abstract) — Defines the interface: `clone()`, `compare()`, `print()`. Each transaction carries a unique `txn_id` for tracking.
- **`axi_write_txn`** — Write channel transaction covering AW (address, burst attributes) + W (data beats, strobes) + B (response).
- **`axi_read_txn`** — Read channel transaction covering AR (address, burst attributes) + R (data beats, response).
- **`axi_stream_txn`** — AXI-Stream frame with data, keep, strobe, user, and last indicators.

### Transactors (`src/transactor/`)

Bus Functional Models that drive AXI protocol signaling:

- **`axi_master_transactor`** — Mailbox-driven master. Accepts transaction objects, drives AW/W/AR channels, receives B/R responses. Supports INCR, FIXED, and WRAP bursts. Configurable outstanding transaction limit. Uses `fork...join_none` for parallel in-flight tracking.
- **`axi_slave_transactor`** — Responds to AW/W/AR, drives B/R. Publishes captured transactions via analysis ports.
- **`axi_stream_transactor`** — Drives and receives AXI-Stream frames with TLAST/TKEEP/TSTRB/TUSER support.

### Monitor (`src/monitor/`)

Passive observers that reconstruct transactions from signal activity:

- **`axi_monitor`** — Spawns 5 concurrent sampling tasks (AW, W, B, AR, R). Uses ID-keyed associative arrays to track out-of-order transactions. W channel uses FIFO ordering per AXI specification. Supports reset state clearing.
- **`axi_stream_monitor`** — Observes AXI-Stream interface and reconstructs frame objects from signal-level activity.

### Protocol Checks (`src/protocol_checks/`)

SVA assertions bound to interface instances at compile time:

- **`axi_assertions`** — 20+ assertions covering: VALID persistence (must remain asserted until READY), payload `$stable` during wait states, reset behavior (all VALIDs deasserted), X/Z checks on all data and control signals, response count ≤ request count per ID, per-ID ordering preservation.
- **`axi_stream_checks`** — AXI-Stream assertions: TVALID persistence, data/TLAST stability during stall, TLAST requires VALID, reset and X/Z checks.

Assertions are bound to interface instances using SystemVerilog `bind` in `testbench/tb_top.sv`.

### Scoreboard (`src/scoreboard/`)

Expected-vs-actual comparison infrastructure:

- **`scoreboard_pkg`** (`compare_if.sv`) — Virtual class defining the comparison contract.
- **`txn_tracker`** — Transaction alignment container. Uses per-ID associative arrays for AXI4 Full, single FIFO for AXI4-Lite and AXI-Stream. Tracks matched vs. unmatched transactions.
- **`axi_scoreboard`** — Orchestrator that subscribes to expected and actual analysis ports, runs `run_compare()` in a loop, and produces end-of-test pass/fail report with unmatched transaction diagnostics.

### Analysis Port / Subscriber (`src/hooks/`)

UVM-style pub/sub decoupling infrastructure:

- **`analysis_port`** — Publish endpoint. Monitors push reconstructed transactions via `write()`.
- **`analysis_subscriber`** — Subscribe endpoint. Receives transactions via `write()`. Multiple subscribers can connect to one port.
- **`coverage_hook`** — Convenience subscriber base class with coverage sampling infrastructure.

### Reference Model (`user_extensions/reference_model/`)

Golden reference model that mirrors DUT behavior:

- **`axi_ref_model`** — Word-addressable associative array memory. Supports INCR and FIXED bursts with WSTRB-per-byte write masking. WRAP bursts are logged as WARN and skipped. Publishes expected read data via `exp_port` for scoreboard consumption.

### Custom Compare (`user_extensions/custom_compare/`)

- **`user_compare`** — Concrete comparator class. Delegates to transaction built-in `compare()` method. Can be customized for DUT-specific comparison logic.

### Coverage (`user_extensions/coverage/`)

- **`user_coverage`** — Functional coverage implementation with covergroup containing coverpoints for: `txn_type` (read/write), `burst_len` (1/2/4/8+ beats), address low bits, WSTRB population count.

### Environment (`testbench/env/`)

- **`axi_env`** — Top-level environment class with build, connect, and run phases. Constructs and wires all verification components.

### Testbench Top (`testbench/tb_top.sv`)

Structural top module that:
1. Generates clock and reset
2. Instantiates the `axi_if` interface
3. Instantiates the DUT and wires it to the interface
4. Binds SVA assertions to the interface
5. Constructs and runs the `axi_env`

## Parameterization

All protocol parameters are defined in `config/axi_config.sv` and control interface width, protocol mode, and feature enablement:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `AXI_TYPE` | `"FULL"` | Protocol variant: FULL, LITE, or STREAM |
| `ADDR_WIDTH` | 32 | Address bus width in bits |
| `DATA_WIDTH` | 32 | Data bus width in bits |
| `ID_WIDTH` | 4 | Transaction ID width for ordering |
| `USER_WIDTH` | 1 | User-defined sideband signal width |
| `HAS_BURST` | 1 | Enable burst transactions |
| `HAS_LOCK` | 1 | Enable exclusive access signaling |
| `HAS_CACHE` | 1 | Enable cache attribute signaling |
| `HAS_PROT` | 1 | Enable protection signaling |
| `HAS_QOS` | 1 | Enable Quality-of-Service signaling |
| `HAS_REGION` | 1 | Enable region-based addressing |
| `MAX_OUTSTANDING_TXNS` | 16 | Max concurrent in-flight transactions |
| `MAX_BURST_LEN` | 256 | Max burst length (AXI4 max is 256) |

## File Organization and Build Order

The compilation order is defined in `scripts/filelist.f`, which serves as the single source of truth. It is used by both the Makefile and shell script:

1. **Config** — `axi_config.sv`, `axi_types.sv`
2. **Common** — `logger.sv`, `utils.sv`, `typedefs.sv`
3. **Interfaces** — `axi_if.sv`, `axi_stream_if.sv`
4. **Transactions** — `axi_transaction.sv`, `axi_write_txn.sv`, `axi_read_txn.sv`, `axi_stream_txn.sv`
5. **Hooks** — `analysis_port.sv`, `coverage_hook.sv`
6. **Transactors** — `axi_master_transactor.sv`, `axi_slave_transactor.sv`, `axi_stream_transactor.sv`
7. **Monitors** — `axi_monitor.sv`, `axi_stream_monitor.sv`
8. **Scoreboard** — `axi_scoreboard.sv`, `txn_tracker.sv`, `compare_if.sv`
9. **Protocol Checks** — `axi_assertions.sv`, `axi_stream_checks.sv`
10. **User Extensions** — `axi_ref_model.sv`, `user_compare.sv`, `user_coverage.sv`
11. **Environment** — `axi_env.sv`
12. **DUT** — `axi_ram.sv` (from examples)
13. **Tests** — `basic_rw_test.sv`
