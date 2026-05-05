`ifndef AXI_REF_MODEL_SV
`define AXI_REF_MODEL_SV

import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import hooks_pkg::*;
import logger_pkg::*;

// Golden reference model — mirrors axi_ram.v behavior with word-addressable memory.
// Matches DUT structure: VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH).

package ref_model_pkg;

    class axi_ref_model extends analysis_subscriber #(axi_transaction);

        localparam int VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);

        // Word-addressable memory — same structure as axi_ram.v.
        logic [DATA_WIDTH-1:0] mem[logic [VALID_ADDR_WIDTH-1:0]];

        // Analysis port for publishing expected read transactions.
        analysis_port #(axi_transaction) exp_port;

        function new();
            this.exp_port = new();
            logger::log(INFO, "Reference model initialized");
        endfunction

        // Return analysis port for testbench connection to scoreboard expected subscriber.
        function analysis_port #(axi_transaction) get_analysis_port();
            return exp_port;
        endfunction

        // Convert byte address to word address (same as DUT: shift by log2(STRB_WIDTH)).
        localparam int WORD_ADDR_SHIFT = $clog2(STRB_WIDTH);

        function logic [VALID_ADDR_WIDTH-1:0] to_word_addr(logic [ADDR_WIDTH-1:0] byte_addr);
            to_word_addr = byte_addr >> WORD_ADDR_SHIFT;
        endfunction

        // Compute address for a given beat in a burst.
        function logic [ADDR_WIDTH-1:0] calc_burst_addr(logic [ADDR_WIDTH-1:0] base, int beat_idx, logic [2:0] size, burst_t burst);
            int offset;
            offset = beat_idx * (1 << size);
            if (burst == INCR) begin
                calc_burst_addr = base + offset;
            end
            // FIXED: address stays at base (handled by returning base).
            else begin
                calc_burst_addr = base;
            end
        endfunction

        // Subscriber write method — dispatch to write/read path via $cast.
        function void write(axi_transaction txn);
            axi_write_txn w_txn;
            axi_read_txn  r_txn;

            if ($cast(w_txn, txn)) begin
                process_write(w_txn);
            end
            else if ($cast(r_txn, txn)) begin
                process_read(r_txn);
            end
            else begin
                logger::log(WARN, $sformatf("Ref model: unknown transaction type TXN:%0d", txn.txn_id));
            end
        endfunction

        // Write path — iterate beats, apply WSTRB masking per byte.
        function void process_write(axi_write_txn txn);
            int i, b;
            logic [ADDR_WIDTH-1:0] addr;
            logic [VALID_ADDR_WIDTH-1:0] w_addr;

            if (txn.burst == WRAP) begin
                logger::log(WARN, $sformatf("Ref model: WRAP burst not supported, skipping TXN:%0d", txn.txn_id));
                return;
            end

            for (i = 0; i < txn.data.size(); i++) begin
                addr = calc_burst_addr(txn.addr, i, txn.size, txn.burst);
                w_addr = to_word_addr(addr);

                for (b = 0; b < STRB_WIDTH; b++) begin
                    if (txn.strb[i][b]) begin
                        mem[w_addr][(b*8) +: 8] = txn.data[i][(b*8) +: 8];
                    end
                end
            end

            logger::log(INFO, $sformatf("Ref model: write TXN:%0d addr=%0h len=%0d beats=%0d", txn.txn_id, txn.addr, txn.len, txn.data.size()));
        endfunction

        // Read path — allocate expected read, populate data from memory.
        function void process_read(axi_transaction txn);
            axi_read_txn r_txn;
            int i;
            logic [ADDR_WIDTH-1:0] addr;
            logic [VALID_ADDR_WIDTH-1:0] w_addr;

            if (!$cast(r_txn, txn)) begin
                logger::log(WARN, $sformatf("Ref model: failed to cast read TXN:%0d", txn.txn_id));
                return;
            end

            if (r_txn.burst == WRAP) begin
                logger::log(WARN, $sformatf("Ref model: WRAP burst not supported, skipping TXN:%0d", r_txn.txn_id));
                return;
            end

            r_txn.data = new[r_txn.len + 1];
            r_txn.resp = new[r_txn.len + 1];

            for (i = 0; i < r_txn.data.size(); i++) begin
                addr = calc_burst_addr(r_txn.addr, i, r_txn.size, r_txn.burst);
                w_addr = to_word_addr(addr);
                r_txn.data[i] = mem[w_addr];
                r_txn.resp[i] = OKAY;
            end

            exp_port.write(r_txn);
            logger::log(INFO, $sformatf("Ref model: read TXN:%0d addr=%0h len=%0d beats=%0d", r_txn.txn_id, r_txn.addr, r_txn.len, r_txn.data.size()));
        endfunction

    endclass

endpackage

`endif
