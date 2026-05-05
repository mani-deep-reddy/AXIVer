`ifndef USER_COVERAGE_SV
`define USER_COVERAGE_SV

import axi_config_pkg::*;
import axi_types_pkg::*;
import axi_transaction_pkg::*;
import axi_write_txn_pkg::*;
import axi_read_txn_pkg::*;
import hooks_pkg::*;
import logger_pkg::*;

// Functional coverage — samples transaction type, burst length, address lower bits,
// and WSTRB pattern count from observed transactions.

class user_coverage extends analysis_subscriber #(axi_transaction);

    // Sample fields for covergroup.
    int txn_type;          // 0=read, 1=write
    int burst_len_bins;    // bin index: 1=0, 2=1, 4=3, 8+=7+
    logic [7:0] addr_lo;   // lower 8 bits of address
    int wstrb_count;       // enabled byte count in first beat

    covergroup cg;
        cp_txn_type: coverpoint txn_type {
            bins read  = {0};
            bins write = {1};
        }
        cp_burst_len: coverpoint burst_len_bins {
            bins len_1  = {0};   // len=0 → 1 beat
            bins len_2  = {1};   // len=1 → 2 beats
            bins len_4  = {2};   // len=3 → 4 beats
            bins len_8p = {3};   // len>=7 → 8+ beats
        }
        cp_addr_lo: coverpoint addr_lo {
            bins lo[] = {[0:255]};
        }
        cp_wstrb: coverpoint wstrb_count {
            bins none  = {0};
            bins half  = {[1:STRB_WIDTH/2]};
            bins most  = {[STRB_WIDTH/2+1:STRB_WIDTH-1]};
            bins full  = {STRB_WIDTH};
        }
    endgroup

    function new();
        cg = new();
        logger::log(INFO, "Coverage hook initialized");
    endfunction

    // Determine burst length bin index from AXI-encoded len field.
    function int burst_len_to_bin(logic [7:0] len);
        if (len == 0)       burst_len_to_bin = 0;   // 1 beat
        else if (len == 1)  burst_len_to_bin = 1;   // 2 beats
        else if (len == 3)  burst_len_to_bin = 2;   // 4 beats
        else                burst_len_to_bin = 3;   // 8+ beats
    endfunction

    // Count enabled bytes in a strobe value (population count).
    function int count_strobe_bits(logic [STRB_WIDTH-1:0] strb);
        int i;
        count_strobe_bits = 0;
        for (i = 0; i < STRB_WIDTH; i++) begin
            if (strb[i]) count_strobe_bits++;
        end
    endfunction

    // Sample transaction attributes into covergroup.
    function void write(axi_transaction txn);
        axi_write_txn w_txn;

        addr_lo = txn.txn_id[7:0]; // fallback; overridden below

        if ($cast(w_txn, txn)) begin
            txn_type = 1; // write
            burst_len_bins = burst_len_to_bin(w_txn.len);
            addr_lo = w_txn.addr[7:0];
            wstrb_count = (w_txn.strb.size() > 0) ? count_strobe_bits(w_txn.strb[0]) : 0;
        end
        else begin
            axi_read_txn r_txn;
            if ($cast(r_txn, txn)) begin
                txn_type = 0; // read
                burst_len_bins = burst_len_to_bin(r_txn.len);
                addr_lo = r_txn.addr[7:0];
                wstrb_count = 0; // reads have no strobe
            end
            else begin
                txn_type = 0;
                burst_len_bins = 0;
                wstrb_count = 0;
            end
        end

        cg.sample();
    endfunction

endclass

`endif
