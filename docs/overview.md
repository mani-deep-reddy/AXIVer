# AXIVer Overview

## Motivation

Verifying AXI4-based designs requires significant infrastructure: bus functional models to drive traffic, monitors to observe activity, protocol checkers to validate compliance, and scoreboards to compare expected vs. actual behavior. Building this from scratch for every project is error-prone and time-consuming.

AXIVer provides a reusable, parameterized, and extensible verification framework that handles the common AXI verification pipeline so you can focus on your DUT's unique behavior.

## Verification Pipeline

AXIVer implements a complete verification pipeline:

1. **Stimulus Generation** — Test sequences create transaction objects and send them to the master transactor
2. **Protocol Compliance Checking** — SVA assertions continuously verify AXI protocol rules on all channels
3. **Passive Monitoring** — Monitors observe interface signals and reconstruct high-level transaction objects without driving the bus
4. **Reference Modeling** — A golden model mirrors the DUT's internal state and produces expected responses
5. **Scoreboarding** — Expected transactions from the reference model are compared against actual transactions from the DUT
6. **Functional Coverage** — Coverage hooks collect metrics on exercised transaction types, burst patterns, and address ranges

## Supported Protocols

| Protocol | Configuration Value | Key Characteristics |
|----------|-------------------|---------------------|
| AXI4 Full | `AXI_TYPE = "FULL"` | 5 independent channels, burst support (INCR/FIXED/WRAP), out-of-order transaction support via ID tracking, all optional signaling (LOCK, CACHE, PROT, QOS, REGION) |
| AXI4-Lite | `AXI_TYPE = "LITE"` | Single-beat transfers only, no burst, reduced signal set, simpler interface |
| AXI-Stream | `AXI_TYPE = "STREAM"` | Single channel with TDATA/TKEEP/TSTRB/TLAST/TUSER, continuous streaming handshake |

The protocol mode is selected by setting the `AXI_TYPE` parameter in `config/axi_config.sv`.

## Key Features

- **Highly Parameterized** — Address width, data width, ID width, and user width are configurable. Feature flags enable or disable optional AXI signaling (burst, lock, cache, protection, QoS, region).
- **UVM-Like Pub/Sub Infrastructure** — Analysis ports and subscribers decouple transaction producers (monitors) from consumers (scoreboard, reference model, coverage).
- **SVA Protocol Assertions** — 20+ built-in SystemVerilog assertions covering handshake rules, signal stability, reset behavior, illegal X/Z values, and channel ordering.
- **Out-of-Order Transaction Support** — ID-keyed associative arrays in the monitor and scoreboard enable tracking of multiple in-flight transactions with different IDs.
- **Structured Logging** — Severity-based logging (DEBUG, INFO, WARN, ERROR, FATAL) with global runtime level control and optional transaction ID correlation.
- **Functional Coverage** — Extensible coverage hooks with pre-defined coverpoints for transaction type, burst length, address alignment, and write strobe patterns.
- **Single-Source-of-Truth Build** — `scripts/filelist.f` defines the compilation order for all source files, referenced by both the Makefile and shell script.
