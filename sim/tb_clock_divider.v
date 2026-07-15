// ============================================================
// Testbench: tb_clock_divider
// Purpose: Feed a fake 50 MHz clock into clock_divider and
//          watch the output to confirm it toggles at 25 MHz.
// ============================================================

`timescale 1ns / 1ps   // sets the time units used below (1ns = 1 nanosecond)

module tb_clock_divider;

    // These are the signals we control and observe.
    // Testbenches use "reg" for anything WE drive (like a fake clock),
    // and "wire" for anything the module under test drives back to us.
    reg clk;
    reg reset;
    wire clk_out;

    // Create one instance of your module, wired to our test signals.
    // This is called "instantiation" -- think of it as placing one
    // physical copy of your clock_divider chip on a breadboard.
    clock_divider UUT (
        .clk(clk),
        .reset(reset),
        .clk_out(clk_out)
    );

    // ---- Generate the fake 50 MHz clock ----
    // A 50 MHz clock has a period of 20ns (1 / 50,000,000 sec = 20ns).
    // So it should flip every 10ns (half the period).
    initial clk = 0;
    always #10 clk = ~clk;

    // ---- Test sequence ----
    initial begin
        reset = 1;        // start in reset
        #25;               // wait 25ns
        reset = 0;         // release reset, let the divider run

        #500;              // let the simulation run long enough to see several cycles

        $stop;              // end the simulation
    end

endmodule