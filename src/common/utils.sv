`ifndef COMMON_UTILS_SV
`define COMMON_UTILS_SV

// Reusable helper functions — no shared state, all free functions.

package utils_pkg;

    // Align address down to nearest power-of-two boundary.
    function automatic longint align_addr(
        input longint addr,
        input int     boundary
    );
        align_addr = addr & ~((longint'(boundary) - 1));
    endfunction

    // Calculate total transfer size from data width (bytes) and burst length.
    function automatic int calc_burst_size(
        input int data_width_bytes,
        input int burst_len
    );
        calc_burst_size = data_width_bytes * burst_len;
    endfunction

    // Convert value to hex string without "0x" prefix.
    function automatic string to_hex_string(
        input longint unsigned value
    );
        to_hex_string = $sformatf("%0h", value);
    endfunction

    // Convert value to hex string with "0x" prefix.
    function automatic string to_hex_string_0x(
        input longint unsigned value
    );
        to_hex_string_0x = $sformatf("0x%0h", value);
    endfunction

endpackage

`endif
