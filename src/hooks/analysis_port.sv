`ifndef ANALYSIS_PORT_SV
`define ANALYSIS_PORT_SV

// Passive transaction observation — pub/sub mechanism for monitors to broadcast
// completed transactions to external subscribers (coverage, reference models, etc.).

package hooks_pkg;

    // Subscriber contract — all subscribers must implement write().
    virtual class analysis_subscriber #(type T = int);
        pure virtual function void write(T txn);
    endclass

    // Publisher — collects subscribers and broadcasts transactions to all of them.
    class analysis_port #(type T = int);
        protected analysis_subscriber #(T) subscribers[$]; // connected subscribers

        function void connect(analysis_subscriber #(T) sub);
            subscribers.push_back(sub);
        endfunction

        function void write(T txn);
            foreach (subscribers[i])
                subscribers[i].write(txn);
        endfunction
    endclass

endpackage

`endif
