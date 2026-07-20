// Testbench: tb_collision
// Purpose: Verifies collision.v — confirms hit_left/hit_right
//          pulse exactly once on contact, stay low while no
//          contact exists, and correctly reflect paddle_y
//          position (ball can miss a paddle vertically even
//          while horizontally aligned).
`timescale 1ns/1ps

module tb_collision;

    localparam BALL_SIZE      = 8;
    localparam PADDLE_WIDTH   = 10;
    localparam PADDLE_HEIGHT  = 60;
    localparam PADDLE_X_LEFT  = 20;
    localparam PADDLE_X_RIGHT = 610;

    reg clk, reset;
    reg [9:0] ball_x, ball_y, paddle_y_left, paddle_y_right;
    wire hit_left, hit_right;

    collision #(
        .BALL_SIZE(BALL_SIZE),
        .PADDLE_WIDTH(PADDLE_WIDTH),
        .PADDLE_HEIGHT(PADDLE_HEIGHT),
        .PADDLE_X_LEFT(PADDLE_X_LEFT),
        .PADDLE_X_RIGHT(PADDLE_X_RIGHT)
    ) dut (
        .clk(clk),
        .reset(reset),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .paddle_y_left(paddle_y_left),
        .paddle_y_right(paddle_y_right),
        .hit_left(hit_left),
        .hit_right(hit_right)
    );

    always #20 clk = ~clk;

    // Count how many cycles hit_left/hit_right are high, to confirm
    // "pulses exactly once" rather than staying high for the whole overlap
    integer hit_left_count, hit_right_count;
    always @(posedge clk) begin
        if (reset) begin
            hit_left_count  <= 0;
            hit_right_count <= 0;
        end else begin
            if (hit_left)  hit_left_count  <= hit_left_count + 1;
            if (hit_right) hit_right_count <= hit_right_count + 1;
        end
    end

    initial begin
        clk = 0; reset = 1;
        ball_x = 0; ball_y = 0;
        paddle_y_left = 200; paddle_y_right = 200;
        #100;
        reset = 0;

        // --- Case 1: ball far from both paddles, no hit expected ---
        ball_x = 300; ball_y = 200;
        #100;
        if (hit_left || hit_right)
            $display("FAIL: unexpected hit with ball at center screen");
        else
            $display("PASS: no false hit when ball is away from paddles");

        // --- Case 2: ball horizontally aligned with left paddle,
        //             but vertically MISSED (paddle is elsewhere) ---
        ball_x = PADDLE_X_LEFT;
        ball_y = paddle_y_left + PADDLE_HEIGHT + 50;  // well below paddle
        #100;
        if (hit_left)
            $display("FAIL: false hit_left — ball is horizontally aligned but should miss vertically");
        else
            $display("PASS: correctly no hit — horizontal alignment alone isn't enough");

        // --- Case 3: real overlap with left paddle ---
        ball_x = PADDLE_X_LEFT;
        ball_y = paddle_y_left;   // dead-center overlap
        #100;   // stays here for multiple clk edges on purpose
        if (hit_left_count == 1)
            $display("PASS: hit_left pulsed exactly once during sustained overlap (count=%0d)", hit_left_count);
        else
            $display("FAIL: hit_left_count = %0d, expected exactly 1", hit_left_count);

        // Move away, then re-enter — should generate a second distinct pulse
        ball_x = 300; ball_y = 300;
        #100;
        ball_x = PADDLE_X_LEFT;
        ball_y = paddle_y_left;
        #100;
        if (hit_left_count == 2)
            $display("PASS: hit_left pulsed a second time on re-entry (count=%0d)", hit_left_count);
        else
            $display("FAIL: hit_left_count = %0d, expected exactly 2 after re-entry", hit_left_count);

        // --- Case 4: real overlap with right paddle ---
        ball_x = PADDLE_X_RIGHT;
        ball_y = paddle_y_right;
        #100;
        if (hit_right_count == 1)
            $display("PASS: hit_right pulsed exactly once (count=%0d)", hit_right_count);
        else
            $display("FAIL: hit_right_count = %0d, expected exactly 1", hit_right_count);

        $display("Simulation complete.");
        $stop;
    end

endmodule