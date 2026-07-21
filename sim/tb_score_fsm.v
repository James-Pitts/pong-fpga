`timescale 1ns/1ps

module tb_score_fsm;

    // This module has no analog VGA timing dependency, so the exact
    // clock period doesn't matter -- 20ns is arbitrary, just a stand-in
    // for whatever clk domain this ends up living in after integration.
    reg clk;
    reg reset;
    reg hit_left;
    reg hit_right;

    wire [3:0] score_left;
    wire [3:0] score_right;
    wire       ball_reset;
    wire       game_over;
    wire [1:0] state;

    localparam WIN_SCORE = 3; // small on purpose, so sim reaches GAME_OVER quickly

    score_fsm #(.WIN_SCORE(WIN_SCORE)) dut (
        .clk         (clk),
        .reset       (reset),
        .hit_left    (hit_left),
        .hit_right   (hit_right),
        .score_left  (score_left),
        .score_right (score_right),
        .ball_reset  (ball_reset),
        .game_over   (game_over),
        .state       (state)
    );

    // ---- clock ----
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // ---- sticky flag ----
    reg saw_game_over;
    always @(posedge clk) if (game_over) saw_game_over <= 1'b1;

    // ---- tripwire: scores must never exceed WIN_SCORE ----
    always @(posedge clk) begin
        if (score_left > WIN_SCORE)
            $display("FAIL (t=%0t): score_left exceeded WIN_SCORE, value=%0d", $time, score_left);
        if (score_right > WIN_SCORE)
            $display("FAIL (t=%0t): score_right exceeded WIN_SCORE, value=%0d", $time, score_right);
    end

    // ---- cycle counter: confirm ball_reset pulses exactly 1 cycle per score event ----
    integer ball_reset_cycles;
    always @(posedge clk) if (ball_reset) ball_reset_cycles = ball_reset_cycles + 1;

    // ---- tasks: apply a single-cycle synchronous pulse on a hit signal ----
    task pulse_hit_left;
        begin
            @(negedge clk); hit_left = 1'b1;
            @(negedge clk); hit_left = 1'b0;
        end
    endtask

    task pulse_hit_right;
        begin
            @(negedge clk); hit_right = 1'b1;
            @(negedge clk); hit_right = 1'b0;
        end
    endtask

    integer errors;

    initial begin
        errors            = 0;
        saw_game_over     = 1'b0;
        ball_reset_cycles = 0;
        hit_left          = 1'b0;
        hit_right         = 1'b0;
        reset             = 1'b1;

        repeat (3) @(negedge clk);
        reset = 1'b0;

        // ---- Check 1: reset check ----
        @(negedge clk);
        if (state !== 2'd1) begin
            $display("FAIL: state did not reach PLAY after reset deassert, state=%0d", state);
            errors = errors + 1;
        end
        if (score_left !== 4'd0 || score_right !== 4'd0) begin
            $display("FAIL: scores not zero after reset");
            errors = errors + 1;
        end

        // ---- Check 2: hit_right increments score_left, ball_reset pulses once ----
        ball_reset_cycles = 0;
        pulse_hit_right;
        repeat (4) @(negedge clk);
        if (score_left !== 4'd1) begin
            $display("FAIL: score_left did not increment on hit_right, got %0d", score_left);
            errors = errors + 1;
        end
        if (ball_reset_cycles !== 1) begin
            $display("FAIL: ball_reset did not pulse exactly once, got %0d", ball_reset_cycles);
            errors = errors + 1;
        end

        // ---- Check 3: hit_left increments score_right ----
        ball_reset_cycles = 0;
        pulse_hit_left;
        repeat (4) @(negedge clk);
        if (score_right !== 4'd1) begin
            $display("FAIL: score_right did not increment on hit_left, got %0d", score_right);
            errors = errors + 1;
        end
        if (ball_reset_cycles !== 1) begin
            $display("FAIL: ball_reset did not pulse exactly once on hit_left case, got %0d", ball_reset_cycles);
            errors = errors + 1;
        end

        // ---- Check 4: simultaneous hit_left + hit_right -> hit_left priority ----
        @(negedge clk);
        hit_left = 1'b1; hit_right = 1'b1;
        @(negedge clk);
        hit_left = 1'b0; hit_right = 1'b0;
        repeat (4) @(negedge clk);
        if (score_right !== 4'd2) begin
            $display("FAIL: simultaneous hit did not resolve to hit_left priority, score_right=%0d", score_right);
            errors = errors + 1;
        end

        // ---- Check 5: drive score_left to WIN_SCORE, confirm GAME_OVER ----
        repeat (WIN_SCORE - score_left) pulse_hit_right;
        repeat (4) @(negedge clk);
        if (state !== 2'd3 || !game_over) begin
            $display("FAIL: GAME_OVER not reached at WIN_SCORE, state=%0d game_over=%0b", state, game_over);
            errors = errors + 1;
        end

        // GAME_OVER must hold even against a stray hit pulse
        pulse_hit_left;
        repeat (4) @(negedge clk);
        if (state !== 2'd3) begin
            $display("FAIL: GAME_OVER state did not hold against a hit pulse");
            errors = errors + 1;
        end

        if (!saw_game_over) begin
            $display("FAIL: sticky saw_game_over flag never latched");
            errors = errors + 1;
        end

        // ---- Check 6: reset recovers cleanly from GAME_OVER ----
        reset = 1'b1;
        repeat (2) @(negedge clk);
        reset = 1'b0;
        @(negedge clk);
        if (state !== 2'd1 || score_left !== 0 || score_right !== 0 || game_over !== 1'b0) begin
            $display("FAIL: FSM did not cleanly recover from GAME_OVER after reset");
            errors = errors + 1;
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else              $display("%0d TEST(S) FAILED", errors);

        $stop;
    end

endmodule