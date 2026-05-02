`ifndef AXI_READ_TXN_SV
`define AXI_READ_TXN_SV

import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_transaction_pkg::*;
import utils_pkg::*;

package axi_read_txn_pkg;

    class axi_read_txn extends axi_transaction;
        // AR channel fields
        logic [ADDR_WIDTH-1:0] addr;  // start address
        logic [ID_WIDTH-1:0] id;      // transaction ID
        logic [7:0] len;              // burst length (AXI encoded)
        logic [2:0] size;             // bytes per beat (AXI encoded)
        burst_t burst;                // burst type
        lock_t lock;                  // lock type
        cache_t cache;                // cache attributes
        prot_t prot;                  // protection type
        logic [3:0] qos;              // quality of service
        logic [4:0] region;           // region identifier

        // R channel fields
        logic [DATA_WIDTH-1:0] data[]; // read data beats
        resp_t resp[];                 // response per beat

        function new(int unsigned txn_id);
            super.new(txn_id);
            this.len = 8'h0;
            this.size = 3'h0;
            this.burst = FIXED;
            this.lock = NORMAL;
            this.cache = '{default: 1'b0};
            this.prot = '{default: 1'b0};
            this.qos = 4'h0;
            this.region = 5'h0;
        endfunction

        // Deep copy of read transaction including data[] and resp[] arrays.
        function axi_transaction clone();
            axi_read_txn copy;
            int i;
            copy = new(this.txn_id);
            copy.addr = this.addr;
            copy.id = this.id;
            copy.len = this.len;
            copy.size = this.size;
            copy.burst = this.burst;
            copy.lock = this.lock;
            copy.cache = this.cache;
            copy.prot = this.prot;
            copy.qos = this.qos;
            copy.region = this.region;
            copy.data = new[this.data.size()];
            copy.resp = new[this.resp.size()];
            for (i = 0; i < this.data.size(); i++) begin
                copy.data[i] = this.data[i];
            end
            for (i = 0; i < this.resp.size(); i++) begin
                copy.resp[i] = this.resp[i];
            end
            return copy;
        endfunction

        // Compare all fields of two read transactions. Returns 1 if match, 0 otherwise.
        function bit compare(axi_transaction other);
            axi_read_txn rhs;
            int i;

            if (!$cast(rhs, other)) return 1'b0;
            if (this.data.size() != this.resp.size()) return 1'b0;
            if (rhs.data.size()  != rhs.resp.size()) return 1'b0;
            if (this.addr !== rhs.addr) return 1'b0;
            if (this.id !== rhs.id) return 1'b0;
            if (this.len !== rhs.len) return 1'b0;
            if (this.size !== rhs.size) return 1'b0;
            if (this.burst !== rhs.burst) return 1'b0;
            if (this.lock !== rhs.lock) return 1'b0;
            if (this.cache !== rhs.cache) return 1'b0;
            if (this.prot !== rhs.prot) return 1'b0;
            if (this.qos !== rhs.qos) return 1'b0;
            if (this.region !== rhs.region) return 1'b0;
            if (this.data.size() !== rhs.data.size()) return 1'b0;
            if (this.resp.size() !== rhs.resp.size()) return 1'b0;
            for (i = 0; i < this.data.size(); i++) begin
                if (this.data[i] !== rhs.data[i]) return 1'b0;
            end
            for (i = 0; i < this.resp.size(); i++) begin
                if (this.resp[i] !== rhs.resp[i]) return 1'b0;
            end
            return 1'b1;
        endfunction

        // Debug dump of read transaction fields and data beats with per-beat response.
        function void print();
            int i;
            $display("=== READ TXN [ID=%0d] ===", this.txn_id);
            /* verilator lint_off WIDTHEXPAND */
            $display("  addr = %s", to_hex_string_0x(this.addr));
            $display("  id   = %0d", this.id);
            $display("  len  = %0d, size = %0d, burst = %s", this.len, this.size, this.burst.name());
            $display("  data[%0d beats]:", this.data.size());
            for (i = 0; i < this.data.size(); i++) begin
                $display("    [%0d] data = %s, resp = %s", i, to_hex_string_0x(this.data[i]), this.resp[i].name());
            end
            /* verilator lint_on WIDTHEXPAND */
            $display("=======================");
        endfunction
    endclass

endpackage

`endif
