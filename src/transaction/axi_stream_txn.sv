`ifndef AXI_STREAM_TXN_SV
`define AXI_STREAM_TXN_SV

import axi_config_pkg::*;
import axi_transaction_pkg::*;
import utils_pkg::*;

package axi_stream_txn_pkg;

    class axi_stream_txn extends axi_transaction;
        // Data payload per beat
        logic [DATA_WIDTH-1:0] data[];
        // Byte qualifiers per beat
        logic [STRB_WIDTH-1:0] keep[];
        // End-of-frame indicator per beat
        bit last[];
        // Optional user sideband per beat (only meaningful when USER_WIDTH > 0)
        logic [USER_WIDTH-1:0] user[];

        function new(int txn_id);
            super.new(txn_id);
        endfunction

        // Deep copy of stream transaction including all arrays.
        function axi_transaction clone();
            axi_stream_txn copy;
            int i;
            copy = new(this.txn_id);
            copy.data = new[this.data.size()];
            copy.keep = new[this.keep.size()];
            copy.last = new[this.last.size()];
            if (USER_WIDTH > 0) begin
                copy.user = new[this.user.size()];
            end
            for (i = 0; i < this.data.size(); i++) begin
                copy.data[i] = this.data[i];
            end
            for (i = 0; i < this.keep.size(); i++) begin
                copy.keep[i] = this.keep[i];
            end
            for (i = 0; i < this.last.size(); i++) begin
                copy.last[i] = this.last[i];
            end
            if (USER_WIDTH > 0) begin
                for (i = 0; i < this.user.size(); i++) begin
                    copy.user[i] = this.user[i];
                end
            end
            return copy;
        endfunction

        // Compare all fields of two stream transactions. Returns 1 if match, 0 otherwise.
        function bit compare(axi_transaction other);
            axi_stream_txn rhs;
            int i;

            if (!$cast(rhs, other)) return 1'b0;
            if (this.data.size() !== rhs.data.size()) return 1'b0;
            if (this.keep.size() !== rhs.keep.size()) return 1'b0;
            if (this.last.size() !== rhs.last.size()) return 1'b0;
            if (USER_WIDTH > 0) begin
                if (this.user.size() !== rhs.user.size()) return 1'b0;
            end
            for (i = 0; i < this.data.size(); i++) begin
                if (this.data[i] !== rhs.data[i]) return 1'b0;
            end
            for (i = 0; i < this.keep.size(); i++) begin
                if (this.keep[i] !== rhs.keep[i]) return 1'b0;
            end
            for (i = 0; i < this.last.size(); i++) begin
                if (this.last[i] !== rhs.last[i]) return 1'b0;
            end
            if (USER_WIDTH > 0) begin
                for (i = 0; i < this.user.size(); i++) begin
                    if (this.user[i] !== rhs.user[i]) return 1'b0;
                end
            end
            return 1'b1;
        endfunction

        // Debug dump of stream frame contents with per-beat details.
        function void print();
            int i;
            $display("=== STREAM TXN [ID=%0d] ===", this.txn_id);
            $display("  beats[%0d]:", this.data.size());
            /* verilator lint_off WIDTHEXPAND */
            for (i = 0; i < this.data.size(); i++) begin
                if (USER_WIDTH > 0) begin
                    $display("    [%0d] data = %s, keep = %h, last = %b, user = %h",
                        i, to_hex_string_0x(this.data[i]), this.keep[i], this.last[i], this.user[i]);
                end else begin
                    $display("    [%0d] data = %s, keep = %h, last = %b",
                        i, to_hex_string_0x(this.data[i]), this.keep[i], this.last[i]);
                end
            end
            /* verilator lint_on WIDTHEXPAND */
            $display("=======================");
        endfunction
    endclass

endpackage

`endif
