`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV

package axi_transaction_pkg;

    virtual class axi_transaction;
        int txn_id; // unique identifier for tracking and debug

        function new(int id);
            this.txn_id = id;
        endfunction

        pure virtual function axi_transaction clone();

        pure virtual function bit compare(axi_transaction other);

        pure virtual function void print();
    endclass

endpackage

`endif
