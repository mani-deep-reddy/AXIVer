# AXI RAM Demo — Example Integration

## Quick Start

From the project root:

### Option 1 (Recommended)
```bash
cd scripts
make
```

### Option 2 (Fallback)
```bash
cd scripts
chmod +x run.sh
./run.sh
```

## What This Runs

This executes the `basic_rw_test`, which validates the full AXI verification flow:

- Master transactor drives transactions
- DUT (AXI RAM) responds
- Monitor reconstructs transactions
- Reference model generates expected results
- Scoreboard compares expected vs actual
- Coverage is collected

## Expected Output

On success, the simulation will:

- Complete without errors
- Print:
```
TEST basic_rw_test: FINISHED
```
- Generate:
  - `compile.log`
  - `run.log`

Check `run.log` for:
- Errors (`ERROR`, `FATAL`)
- Scoreboard results
- Coverage summary

## Troubleshooting

- If compilation fails → check `compile.log`
- If simulation fails → check `run.log`
- Ensure Cadence `xrun` is available in your environment
