`timescale 1ns/1ps

// Testbench: tb_pong_top
// Purpose: Full-system integration verification. Individual
//          modules are already verified standalone (Milestones
//          1-6) -- this testbench checks WIRING correctness
//          across module boundaries only: that a signal leaving
//          one block reaches the right port on the next block
//          with the right meaning.
//
// Technique: uses Verilog force/release to jump ball_x/ball_y/
// paddle_y_right/x_dir directly to interesting positions instead
// of waiting for a real ~420,000-cycle VGA frame to walk the ball
// there naturally. Every bounce/score/reset event checked below
// is still produced by real hardware reacting to the forced
// value -- force is only used to skip travel time, never to fake
// the response itself.

module tb_pong_top;

    reg clk_50mhz;
    reg reset;
    reg btn_up_left, btn_down_left, btn_up_right, btn_down_right;

    wire hsync, vsync;
    wire [3:0] vga_red, vga_green, vga_blue;

    localparam S_RESET     = 2'd0;
    localparam S_PLAY      = 2'd1;
    localparam S_SCORE     = 2'd2;
    localparam S_GAME_OVER = 2'd3;

    localparam WIN_SCORE = 5;
    localparam MAX_X     = 632;
    localparam START_X   = 316;
    localparam START_Y   = 236;

    pong_top dut (
        .clk_50mhz      (clk_50mhz),
        .reset          (reset),
        .btn_up_left    (btn_up_left),
        .btn_down_left  (btn_down_left),
        .btn_up_right   (btn_up_right),
        .btn_down_right (btn_down_right),
        .hsync          (hsync),
        .vsync          (vsync),
        .vga_red        (vga_red),
        .vga_green      (vga_green),
        .vga_blue       (vga_blue)
    );

    // ---- 50MHz external clock (drives clock_divider only) ----
    initial clk_50mhz = 1'b0;
    always #10 clk_50mhz = ~clk_50mhz;

    // ---- sticky flags (level-sensitive: safe to sample on either clock) ----
    reg saw_paddle_bounce, saw_score_left, saw_score_right, saw_game_over;

    always @(posedge clk_50mhz) begin
        if (dut.paddle_hit_right) saw_paddle_bounce <= 1'b1;
        if (dut.score_left  > 0)  saw_score_left    <= 1'b1;
        if (dut.score_right > 0)  saw_score_right   <= 1'b1;
        if (dut.game_over)        saw_game_over     <= 1'b1;
    end

    always @(posedge clk_50mhz) begin
        if (dut.ball_x > MAX_X)
            $display("FAIL (t=%0t): ball_x out of bounds, val=%0d", $time, dut.ball_x);
        if (dut.score_left > WIN_SCORE || dut.score_right > WIN_SCORE)
            $display("FAIL (t=%0t): a score exceeded WIN_SCORE", $time);
    end

    // ---- cycle counter: must sample on clk_25mhz -- game_reset is held
    // high for one clk_25mhz period, which spans TWO clk_50mhz posedges.
    // Sampling on clk_50mhz would double-count every real pulse.
    integer game_reset_cycles;
    always @(posedge dut.clk_25mhz) if (dut.game_reset) game_reset_cycles = game_reset_cycles + 1;

    integer errors;
    reg [9:0] paddle_y_before;

    // ---- helper: one synchronized "manual frame_tick" via a forced vsync pulse ----
    // Waits are on dut.clk_25mhz -- that's the clock paddle_control/ball_control
    // actually register frame_tick on.
    task force_one_frame_tick;
        begin
            @(negedge dut.clk_25mhz); force dut.vsync = 1'b0;
            @(negedge dut.clk_25mhz); force dut.vsync = 1'b1;
            @(negedge dut.clk_25mhz); release dut.vsync;
        end
    endtask

    task force_wall_hit_right;
        begin
            force dut.u_ball_control.ball_x = MAX_X[9:0];
            force dut.u_ball_control.x_dir  = 1'b1;
            repeat (3) @(negedge dut.clk_25mhz);
            release dut.u_ball_control.ball_x;
            release dut.u_ball_control.x_dir;
            repeat (4) @(negedge dut.clk_25mhz);
        end
    endtask

    initial begin
        errors             = 0;
        saw_paddle_bounce   = 1'b0;
        saw_score_left      = 1'b0;
        saw_score_right     = 1'b0;
        saw_game_over       = 1'b0;
        game_reset_cycles   = 0;
        btn_up_left    = 1'b0; btn_down_left  = 1'b0;
        btn_up_right   = 1'b0; btn_down_right = 1'b0;
        reset = 1'b1;

        // reset hold: clk_25mhz is frozen (held low) the whole time reset
        // is asserted, so this wait MUST stay on clk_50mhz or it would hang.
        repeat (5) @(negedge clk_50mhz);
        reset = 1'b0;
        // now clk_25mhz is free-running again -- switch to it for settle time
        repeat (3) @(negedge dut.clk_25mhz);

        // ---- Check 1: reset check across the whole system ----
        if (dut.game_state !== S_PLAY) begin
            $display("FAIL: game_state not PLAY after reset, got %0d", dut.game_state);
            errors = errors + 1;
        end
        if (dut.ball_x !== START_X[9:0] || dut.ball_y !== START_Y[9:0]) begin
            $display("FAIL: ball not at START position after reset");
            errors = errors + 1;
        end
        if (dut.score_left !== 0 || dut.score_right !== 0) begin
            $display("FAIL: scores not zero after reset");
            errors = errors + 1;
        end

        // ---- Check 2: button -> paddle_control -> paddle_y_right wiring ----
        begin
            paddle_y_before = dut.paddle_y_right;
            btn_up_right = 1'b1;
            force_one_frame_tick;
            repeat (2) @(negedge dut.clk_25mhz);
            btn_up_right = 1'b0;
            if (dut.paddle_y_right !== paddle_y_before - 10'd4) begin
                $display("FAIL: paddle_y_right did not move on button+frame_tick, before=%0d after=%0d",
                          paddle_y_before, dut.paddle_y_right);
                errors = errors + 1;
            end
        end

        // ---- Check 3: collision.v -> ball_control.v wiring (paddle bounce) ----
        force dut.u_ball_control.ball_x = 10'd605;
        force dut.u_ball_control.ball_y = 10'd236;
        force dut.paddle_y_right        = 10'd236;
        force dut.u_ball_control.x_dir  = 1'b1;
        repeat (3) @(negedge dut.clk_25mhz);
        if (!saw_paddle_bounce) begin
            $display("FAIL: paddle_hit_right never reached ball_control (collision wiring broken)");
            errors = errors + 1;
        end
        if (dut.u_ball_control.x_dir !== 1'b0) begin
            $display("FAIL: x_dir did not flip on paddle_hit_right, still %0b", dut.u_ball_control.x_dir);
            errors = errors + 1;
        end
        release dut.u_ball_control.ball_x;
        release dut.u_ball_control.ball_y;
        release dut.paddle_y_right;
        release dut.u_ball_control.x_dir;
        repeat (2) @(negedge dut.clk_25mhz);

        // ---- Check 4: ball_control.v -> score_fsm.v -> ball_control.v wiring ----
        game_reset_cycles = 0;
        force_wall_hit_right;
        if (dut.score_left !== 4'd1) begin
            $display("FAIL: score_left did not reach 1 after wall_hit_right, got %0d", dut.score_left);
            errors = errors + 1;
        end
        if (game_reset_cycles !== 1) begin
            $display("FAIL: game_reset did not pulse exactly once, got %0d", game_reset_cycles);
            errors = errors + 1;
        end
        if (dut.ball_x !== START_X[9:0]) begin
            $display("FAIL: ball did not re-serve to START_X after game_reset, ball_x=%0d", dut.ball_x);
            errors = errors + 1;
        end

        // ---- Check 5: drive remaining points to reach GAME_OVER ----
        repeat (WIN_SCORE - dut.score_left) force_wall_hit_right;
        if (dut.game_state !== S_GAME_OVER || !dut.game_over) begin
            $display("FAIL: GAME_OVER not reached, state=%0d game_over=%0b", dut.game_state, dut.game_over);
            errors = errors + 1;
        end

        force_wall_hit_right;
        if (dut.game_state !== S_GAME_OVER) begin
            $display("FAIL: GAME_OVER did not hold against a further wall_hit force");
            errors = errors + 1;
        end
        if (!saw_game_over) begin
            $display("FAIL: sticky saw_game_over never latched");
            errors = errors + 1;
        end

        // ---- Check 6: reset recovers cleanly from GAME_OVER, system-wide ----
        reset = 1'b1;
        repeat (3) @(negedge clk_50mhz); // reset hold -- clk_25mhz frozen, must use clk_50mhz
        reset = 1'b0;
        repeat (3) @(negedge dut.clk_25mhz);
        if (dut.game_state !== S_PLAY || dut.score_left !== 0 || dut.score_right !== 0 ||
            dut.ball_x !== START_X[9:0] || dut.game_over !== 1'b0) begin
            $display("FAIL: system did not cleanly recover from GAME_OVER after reset");
            errors = errors + 1;
        end

        // ---- Check 7: vga_sync/ball_control -> rgb_mux wiring ----
        force dut.video_on = 1'b1;
        force dut.pixel_x  = dut.ball_x;
        force dut.pixel_y  = dut.ball_y;
        repeat (2) @(negedge dut.clk_25mhz);
        if (vga_red === 4'h0) begin
            $display("FAIL: rgb_mux did not light pixel aligned with ball (ball_x/ball_y wiring broken)");
            errors = errors + 1;
        end
        force dut.pixel_x = dut.ball_x + 10'd100;
        repeat (2) @(negedge dut.clk_25mhz);
        if (vga_red !== 4'h0) begin
            $display("FAIL: rgb_mux stayed lit after pixel moved off the ball");
            errors = errors + 1;
        end
        release dut.video_on;
        release dut.pixel_x;
        release dut.pixel_y;

        if (errors == 0) $display("ALL TESTS PASSED");
        else              $display("%0d TEST(S) FAILED", errors);

        $stop;
    end

endmodule