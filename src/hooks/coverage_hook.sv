`ifndef COVERAGE_HOOK_SV
`define COVERAGE_HOOK_SV

// Convenience base class for user-defined coverage — extends analysis_subscriber
// with an empty write() that users override with coverage logic.

import hooks_pkg::*;

package coverage_hook_pkg;

    class coverage_hook #(type T = int) extends analysis_subscriber #(T);
        function void write(T txn);
            // Override with user-defined coverage behavior
        endfunction
    endclass

endpackage

`endif
