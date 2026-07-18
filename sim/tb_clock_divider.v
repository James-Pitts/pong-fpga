// Testbench: tb_clock_divider
// Purpose: Feed a fake 50 MHz clock into clock_divider and
//          watch the output to confirm it toggles at 25 MHz.

`timescale 1ns / 1ps   // sets the time units used below (1ns = 1 nanosecond)

module tb_clock_divider;
    // Testbench-driven signals (reg, since values are forced)
    reg clk;
    reg reset;

    //UUT output signals
    wire clk_out;

    // Instantiate the device
    clock_divider UUT (
        .clk(clk),
        .reset(reset),
        .clk_out(clk_out)
    );

    // Generate the fake 50 MHz clock
    initial clk = 0;
    always #10 clk = ~clk;

    // Main test sequence
    initial begin
        reset = 1;        // start in reset
        #25;               // wait 25ns
        reset = 0;         // release reset, let the divider run

        #500;              // let the simulation run long enough to see several cycles

        $stop;              // end the simulation
    end

endmodule