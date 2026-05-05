# CONFIG
../config/axi_config.sv
../config/axi_types.sv

# COMMON
../src/common/logger.sv
../src/common/utils.sv
../src/common/typedefs.sv

# INTERFACES
../interfaces/axi_if.sv
../interfaces/axi_stream_if.sv

# TRANSACTIONS
../src/transaction/axi_transaction.sv
../src/transaction/axi_write_txn.sv
../src/transaction/axi_read_txn.sv
../src/transaction/axi_stream_txn.sv

# HOOKS
../src/hooks/analysis_port.sv
../src/hooks/coverage_hook.sv

# TRANSACTORS
../src/transactor/axi_master_transactor.sv
../src/transactor/axi_slave_transactor.sv
../src/transactor/axi_stream_transactor.sv

# MONITOR
../src/monitor/axi_monitor.sv
../src/monitor/axi_stream_monitor.sv

# SCOREBOARD
../src/scoreboard/axi_scoreboard.sv
../src/scoreboard/txn_tracker.sv
../src/scoreboard/compare_if.sv

# PROTOCOL CHECKS
../src/protocol_checks/axi_assertions.sv
../src/protocol_checks/axi_stream_checks.sv

# USER EXTENSIONS
../user_extensions/reference_model/axi_ref_model.sv
../user_extensions/custom_compare/user_compare.sv
../user_extensions/coverage/user_coverage.sv

# ENV
../testbench/env/axi_env.sv

# DUT
../examples/axi_ram_demo/rtl/axi_ram.sv

# TEST
../testbench/tests/basic_rw_test.sv
