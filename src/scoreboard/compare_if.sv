`ifndef SCOREBOARD_COMPARE_IF_SV
`define SCOREBOARD_COMPARE_IF_SV

import hooks_pkg::*;
import axi_transaction_pkg::*;

// User-defined comparison contract — extends analysis_subscriber for consistency with hook patterns.

package scoreboard_pkg;

    // Virtual comparison interface — users extend this class and implement compare().
    virtual class compare_if #(type T = axi_transaction) extends analysis_subscriber #(T);

        // Pure virtual comparison method — returns 1 for pass, 0 for fail.
        pure virtual function bit compare(T expected, T actual);

        // Empty stub — satisfies analysis_subscriber contract. Intake is handled by scoreboard subscribers.
        function void write(T txn);
        endfunction

    endclass

endpackage

`endif
