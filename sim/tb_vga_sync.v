// Testbench: tb_vga_sync
// Purpose: Verifies vga_sync module — checks reset behavior, h_count/v_count
//          wraparound, and hsync/vsync/video_on timing via waveform inspection
//          plus automated sanity-check assertions.

`timescale 1ns/1ps

module tb_vga_sync;
    // Testbench-driven signals (reg, since values are forced)
    reg clk;
    reg reset;

    // DUT output signals (wire, since the DUT drives them)
    wire hsync;
    wire vsync;
    wire video_on;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;

    // Instantiate the device under test (DUT) with named port mapping
    vga_sync dut (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    // Generate a fake 25MHz clock
    initial clk = 0;
    always #20 clk = ~clk;

    // Main test sequence
    initial begin
        // Check 1: Reset behavior
        reset = 1;
        #25;

        if (hsync !== 1 || vsync !== 1 || video_on !== 0)
            $display("FAIL: reset did not produce expected idle outputs at time %0t", $time);
        else
            $display("PASS: reset produced correct idle outputs");

        // Release reset, let the counters run
        reset = 0;

        // Check 2: Let one full frame (plus a bit extra) run so we can see
        //     h_count and v_count both wrap at least once ---
        // One full frame = 800 * 525 = 420,000 clock cycles = 16,800,000 ns
        
        #16800001;

        $display("Simulation reached time %0t - inspect waveform for hsync/vsync/video_on timing", $time);

        $finish;
    end

    // Check 3: Automated assertion — h_count should NEVER exceed 799
    always @(posedge clk) begin
        if (dut.h_count > 799)
            $display("FAIL: h_count exceeded 799 at time %0t, value = %0d", $time, dut.h_count);
    end

    // --- Check 4: Automated assertion — v_count should NEVER exceed 524 ---
    always @(posedge clk) begin
        if (dut.v_count > 524)
            $display("FAIL: v_count exceeded 524 at time %0t, value = %0d", $time, dut.v_count);
    end

endmodule