// Top-level testbench module — binds protocol assertions to interfaces.

// Bind AXI4 protocol assertions to every axi_if instance.
bind axi_if axi_assertions #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .USER_WIDTH(USER_WIDTH),
    .HAS_BURST(HAS_BURST)
) assertions_i (.*);

// Bind AXI-Stream protocol assertions to every axi_stream_if instance.
bind axi_stream_if axi_stream_checks #(
    .DATA_WIDTH(DATA_WIDTH),
    .USER_WIDTH(USER_WIDTH)
) stream_assertions_i (.*);

module tb_top;

    // Testbench top-level placeholder.
    // Interfaces, DUT, transactors, monitors, and scoreboards are wired here.

endmodule
