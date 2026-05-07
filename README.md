# AXIVer

AXI Verification Framework — a modular, SystemVerilog-based verification framework for AXI4 (Full/Lite) and AXI-Stream protocol designs. AXIVer provides a reusable, configurable, and extensible verification environment modeled after UVM concepts, tailored specifically for the AMBA AXI protocol family.

## Supported Protocols

- **AXI4 Full** — Complete AXI4 interface with all 5 channels (AW, W, B, AR, R), burst support, out-of-order transaction handling, and all optional signaling (LOCK, CACHE, PROT, QOS, REGION)
- **AXI4-Lite** — Lightweight subset with single-beat transfers and no burst support
- **AXI-Stream** — Streaming interface with TDATA, TKEEP, TSTRB, TLAST, TUSER, and TVALID/TREADY handshake

## Key Features

| Feature | Description |
|---------|-------------|
| **Parameterization** | Configurable ADDR_WIDTH, DATA_WIDTH, ID_WIDTH, USER_WIDTH, AXI_TYPE, feature flags, and system limits — all in `config/axi_config.sv` |
| **Transaction Objects** | Object-oriented transaction model with `clone()`, `compare()`, `print()`; derived classes for write, read, and stream transactions |
| **Master / Slave Transactors** | Mailbox-driven AXI4 BFMs supporting all burst types (INCR, FIXED, WRAP), configurable outstanding transaction limits, parallel in-flight tracking |
| **Stream Transactor** | AXI-Stream BFM with TLAST, TKEEP, TSTRB, TUSER support |
| **Passive Monitor** | Signal-level observation reconstructing complete AXI transactions from all 5 channels; ID-keyed associative arrays for out-of-order support |
| **Protocol Assertions** | 20+ SVA assertions covering handshake rules, payload stability, reset behavior, X/Z checking, and per-ID ordering |
| **Scoreboard** | Expected-vs-actual comparison with ID-based or FIFO transaction alignment, pass/fail reporting, and unmatched transaction diagnostics |
| **Reference Model** | Word-addressable memory mirror (golden model) supporting INCR and FIXED bursts with WSTRB-per-byte write masking |
| **Functional Coverage** | Coverage hooks with configurable coverpoints (txn_type, burst_len, address, wstrb) |
| **Analysis Port / Subscriber** | UVM-style pub/sub infrastructure — monitors publish transactions; scoreboard, reference model, and coverage subscribe |
| **Structured Logging** | Severity-filtered (DEBUG/INFO/WARN/ERROR/FATAL) logging with optional transaction ID correlation |
| **Build System** | Makefile + shell script for Cadence Xcelium; single-source-of-truth file list |

## Directory Structure

```
AXIVer/
├── config/                  # AXI parameters (axi_config.sv) and type definitions (axi_types.sv)
├── src/
│   ├── common/              # Shared utilities: logger, type definitions, helper functions
│   ├── transaction/         # Base and derived transaction data objects
│   ├── hooks/               # Analysis port / subscriber pub/sub infrastructure
│   ├── transactor/          # AXI4 master, slave, and AXI-Stream bus functional models
│   ├── monitor/             # Passive signal observers for AXI4 and AXI-Stream
│   ├── protocol_checks/     # SVA assertions for protocol compliance
│   └── scoreboard/          # Transaction comparison, tracking, and reporting
├── interfaces/              # SystemVerilog interface definitions (axi_if, axi_stream_if)
├── testbench/
│   ├── tb_top.sv            # Structural top: clock, reset, interface, DUT, env wiring
│   ├── env/                 # Environment class (build, connect, run phases)
│   ├── tests/               # Test cases (basic_rw_test, etc.)
│   └── sequences/           # Sequence library (example_seq)
├── examples/
│   └── axi_ram_demo/        # Quick-start demo: AXI RAM DUT integration example
├── rtl/                     # Provided RTL (axi_ram.v — Alex Forencich's open-source AXI RAM)
├── scripts/                 # Build system: Makefile, run.sh, filelist.f, xrun_args.sh
├── user_extensions/
│   ├── reference_model/     # Golden reference model (mirrors DUT behavior)
│   ├── custom_compare/      # Concrete comparator for scoreboard comparison
│   └── coverage/            # Functional coverage hook implementation
└── docs/                    # Documentation
    ├── overview.md          # High-level project overview and motivation
    ├── architecture.md      # Block-level architecture and data flow
    └── integration_guide.md # Step-by-step DUT integration instructions
```

## Prerequisites

- **Cadence Xcelium** (`xrun`) — required for full simulation
- **Verilator 5.020+** — optional, for linting assertion modules only
- GNU `make` and `bash`

## Quick Start

### Option 1 — Make (recommended)

```bash
cd scripts
make
```

This runs the full pipeline: `clean → compile → run → check`.

### Option 2 — Shell fallback

```bash
cd scripts
chmod +x run.sh
./run.sh
```

### Make Targets

| Target | Description |
|--------|-------------|
| `make clean` | Removes `xrun.*`, `*.log`, `waves.shm` |
| `make compile` | Compiles all SystemVerilog sources with `xrun` |
| `make run` | Runs the simulation |
| `make check` | Greps `run.log` for ERROR/FATAL |
| `make all` (default) | clean → compile → run → check |

## What Runs by Default

The default simulation executes `basic_rw_test`, which validates the full verification pipeline:

1. Master transactor drives write and read transactions via mailbox
2. DUT (`axi_ram.v`) responds as an AXI4 slave
3. Monitor passively observes all 5 channels and reconstructs transactions
4. Reference model mirrors DUT memory and generates expected read data
5. Scoreboard compares expected vs. actual transactions
6. Coverage collects functional coverage metrics
7. End-of-test report with scoreboard summary and coverage statistics

## Documentation

- [Overview](docs/overview.md) — What AXIVer is, why it exists, supported protocols
- [Architecture](docs/architecture.md) — Component design, data flow, parameterization
- [Integration Guide](docs/integration_guide.md) — How to configure, extend, and use AXIVer with your own DUT

## Extending AXIVer

To integrate AXIVer with your own DUT:

1. Wire your DUT to the `axi_if` interface in `testbench/tb_top.sv`
2. Customize the reference model in `user_extensions/reference_model/axi_ref_model.sv` to match your DUT's behavior
3. Modify the comparator in `user_extensions/custom_compare/user_compare.sv` if your DUT has custom response logic
4. Update the coverage hooks in `user_extensions/coverage/user_coverage.sv`
5. Add test files in `testbench/tests/` and register them in `scripts/filelist.f`

See the [Integration Guide](docs/integration_guide.md) for detailed instructions.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
