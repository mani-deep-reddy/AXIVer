`ifndef USER_COMPARE_SV
`define USER_COMPARE_SV

import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import scoreboard_pkg::*;
import logger_pkg::*;

// Concrete comparator — dispatches to transaction built-in compare() methods
// and logs mismatch context (address, ID, beat index).

class user_compare extends compare_if #(axi_transaction);

    function bit compare(axi_transaction expected, axi_transaction actual);
        axi_write_txn exp_w, act_w;
        axi_read_txn  exp_r, act_r;
        bit result;
        string msg;

        if ($cast(exp_w, expected)) begin
            if (!$cast(act_w, actual)) begin
                msg = $sformatf("Compare: type mismatch — expected write TXN:%0d, got different type TXN:%0d", expected.txn_id, actual.txn_id);
                logger::log(ERROR, msg);
                return 1'b0;
            end
            result = exp_w.compare(act_w);
            if (!result) begin
                msg = $sformatf("Compare: write mismatch TXN:%0d addr=%0h id=%0d", expected.txn_id, exp_w.addr, exp_w.id);
                logger::log(ERROR, msg);
            end
            return result;
        end
        else if ($cast(exp_r, expected)) begin
            if (!$cast(act_r, actual)) begin
                msg = $sformatf("Compare: type mismatch — expected read TXN:%0d, got different type TXN:%0d", expected.txn_id, actual.txn_id);
                logger::log(ERROR, msg);
                return 1'b0;
            end
            result = exp_r.compare(act_r);
            if (!result) begin
                msg = $sformatf("Compare: read mismatch TXN:%0d addr=%0h id=%0d", expected.txn_id, exp_r.addr, exp_r.id);
                logger::log(ERROR, msg);
            end
            return result;
        end
        else begin
            msg = $sformatf("Compare: unknown expected type TXN:%0d", expected.txn_id);
            logger::log(ERROR, msg);
            return 1'b0;
        end
    endfunction

endclass

`endif
