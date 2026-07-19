// Testbench: tb_ball_control
// Purpose: Verifies ball_control.v — reset position, and that
//          both ball_x and ball_y correctly bounce (reverse
//          direction) at all four screen walls over a run long
//          enough to guarantee multiple bounces on each axis.
`timescale 1ns/1ps

module tb_ball_control;

    localparam BALL_SIZE     = 8;
    localparam SCREEN_WIDTH  = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam STEP          = 4;
    localparam START_X       = 316;
    localparam START_Y       = 236;
    localparam MAX_X         = SCREEN_WIDTH  - BALL_SIZE;
    localparam MAX_Y         = SCREEN_HEIGHT - BALL_SIZE;

    reg clk, reset, vsync;
    wire [9:0] ball_x, ball_y;

    ball_control #(
        .BALL_SIZE(BALL_SIZE),
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .STEP(STEP),
        .START_X(START_X),
        .START_Y(START_Y)
    ) dut (
        .clk(clk),
        .reset(reset),
        .vsync(vsync),
        .ball_x(ball_x),
        .ball_y(ball_y)
    );

    // 25 MHz fake clock
    always #20 clk = ~clk;

    // Synchronous fake vsync (same fix as tb_paddle_control — driven off
    // clk directly, never a free-running #delay, so no race condition)
    localparam FRAME_PERIOD = 2;
    reg [7:0] frame_counter;

    always @(posedge clk) begin
        if (reset) begin
            frame_counter <= 8'd0;
            vsync         <= 1'b0;
        end else if (frame_counter == FRAME_PERIOD - 1) begin
            frame_counter <= 8'd0;
            vsync         <= 1'b1;
        end else begin
            frame_counter <= frame_counter + 1'b1;
            vsync         <= 1'b0;
        end
    end

    // Tripwires: ball must never leave the legal screen region on either axis
    always @(posedge clk) begin
        if (ball_x > MAX_X)
            $display("FAIL @ %0t: ball_x = %0d exceeds MAX_X = %0d", $time, ball_x, MAX_X);
        if (ball_y > MAX_Y)
            $display("FAIL @ %0t: ball_y = %0d exceeds MAX_Y = %0d", $time, ball_y, MAX_Y);
    end

    // Bounce-detection: watch for ball_x / ball_y hitting each of the
    // four exact wall values at least once during the run
    reg saw_left, saw_right, saw_top, saw_bottom;

    always @(posedge clk) begin
        if (reset) begin
            saw_left   <= 1'b0;
            saw_right  <= 1'b0;
            saw_top    <= 1'b0;
            saw_bottom <= 1'b0;
        end else begin
            if (ball_x == 10'd0)        saw_left   <= 1'b1;
            if (ball_x == MAX_X[9:0])   saw_right  <= 1'b1;
            if (ball_y == 10'd0)        saw_top    <= 1'b1;
            if (ball_y == MAX_Y[9:0])   saw_bottom <= 1'b1;
        end
    end

    initial begin
        clk = 0; reset = 1;
        #100;
        if (ball_x !== START_X || ball_y !== START_Y)
            $display("FAIL: reset position wrong — ball_x=%0d ball_y=%0d, expected (%0d,%0d)",
                       ball_x, ball_y, START_X, START_Y);
        else
            $display("PASS: ball correctly reset to (%0d,%0d)", ball_x, ball_y);
        reset = 0;

        // Run long enough to guarantee several bounces on both axes.
        // Longest single traversal (center to a wall and back) is roughly
        // (MAX_X/STEP) frames worst-case; give generous margin.
        #400000;

        if (saw_left && saw_right && saw_top && saw_bottom)
            $display("PASS: ball bounced off all four walls at least once");
        else
            $display("FAIL: missing wall contact — left=%0d right=%0d top=%0d bottom=%0d",
                       saw_left, saw_right, saw_top, saw_bottom);

        $display("Simulation complete.");
        $stop;
    end

endmodule