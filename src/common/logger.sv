`ifndef COMMON_LOGGER_SV
`define COMMON_LOGGER_SV

// Structured logging with severity filtering and optional transaction ID.

package logger_pkg;

    // Log severity levels in ascending order.
    typedef enum {
        DEBUG,  // detailed internal info
        INFO,   // normal operation
        WARN,   // unusual but non-fatal
        ERROR,  // incorrect behavior
        FATAL   // critical issue
    } log_level_e;

    // Convert log level enum to string.
    function string level_to_string(log_level_e level);
        case (level)
            DEBUG: return "DEBUG";
            INFO:  return "INFO";
            WARN:  return "WARN";
            ERROR: return "ERROR";
            FATAL: return "FATAL";
            default: return "UNKNOWN";
        endcase
    endfunction

    // Static logger class — access via logger::log() without instantiation.
    class logger;

        // Global log level filter — any module can change this at runtime.
        static log_level_e current_level = DEBUG;

        // Print message if level >= current_level. txn_id=-1 means omit.
        static function void log(
            input log_level_e level,
            input string    message,
            input int       txn_id = -1
        );
            string level_str;
            string log_msg;

            if (level < current_level) return;

            level_str = level_to_string(level);

            if (txn_id >= 0) begin
                $sformat(log_msg, "[%0t][%s][TXN:%0d] %s", $time, level_str, txn_id, message);
            end else begin
                $sformat(log_msg, "[%0t][%s] %s", $time, level_str, message);
            end

            $display(log_msg);
        endfunction
    endclass

endpackage

`endif
