// Testbench: tb_paddle_control
// Purpose: Verifies paddle_control.v — reset value, up/down
//          movement per frame tick, and clamping at both the
//          top and bottom of the screen.
`timescale 1ns/1ps

module tb_paddle_control;

    localparam PADDLE_HEIGHT = 60;
    localparam SCREEN_HEIGHT = 480;
    localparam STEP          = 4;
    localparam START_Y       = 210;
    localparam MAX_Y         = SCREEN_HEIGHT - PADDLE_HEIGHT;

    reg clk, reset, btn_up, btn_down, vsync;
    wire [9:0] paddle_y;

    paddle_control #(
        .PADDLE_HEIGHT(PADDLE_HEIGHT),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .STEP(STEP),
        .START_Y(START_Y)
    ) dut (
        .clk(clk),
        .reset(reset),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .vsync(vsync),
        .paddle_y(paddle_y)
    );

    // 25 MHz fake clock, same convention as tb_vga_sync (downstream of clock divider)
    always #20 clk = ~clk;

    // NEW — fake vsync, but generated synchronously off clk (mirrors how
// the real vga_sync module will drive it: a registered pulse, not a
// free-running async #delay). Fires every FRAME_PERIOD clk cycles.
localparam FRAME_PERIOD = 2;   // artificially fast for sim speed, not real 60Hz timing
reg [7:0] frame_counter;

always @(posedge clk) begin
    if (reset) begin
        frame_counter <= 8'd0;
        vsync         <= 1'b0;
    end else if (frame_counter == FRAME_PERIOD - 1) begin
        frame_counter <= 8'd0;
        vsync         <= 1'b1;   // one-cycle pulse, lands exactly on a clk edge
    end else begin
        frame_counter <= frame_counter + 1'b1;
        vsync         <= 1'b0;
    end
end

    // Tripwire: paddle_y must never leave [0, MAX_Y]
    always @(posedge clk) begin
        if (paddle_y > MAX_Y)
            $display("FAIL @ %0t: paddle_y = %0d exceeds MAX_Y = %0d", $time, paddle_y, MAX_Y);
    end

    initial begin
        // --- Reset check ---
        clk = 0; reset = 1; btn_up = 0; btn_down = 0;
        #100;
        if (paddle_y !== START_Y)
            $display("FAIL: paddle_y = %0d after reset, expected %0d", paddle_y, START_Y);
        else
            $display("PASS: paddle_y correctly reset to %0d", paddle_y);
        reset = 0;

        // --- Hold DOWN, verify increment + eventual clamp at bottom ---
        btn_down = 1; btn_up = 0;
        #15000;
        if (paddle_y !== MAX_Y[9:0])
            $display("FAIL: paddle_y = %0d, expected clamp at MAX_Y = %0d", paddle_y, MAX_Y);
        else
            $display("PASS: paddle_y correctly clamped at bottom, value = %0d", paddle_y);
        btn_down = 0;

        // --- Hold UP, verify decrement + eventual clamp at top ---
        btn_up = 1; btn_down = 0;
        #15000;
        if (paddle_y !== 10'd0)
            $display("FAIL: paddle_y = %0d, expected clamp at top (0)", paddle_y);
        else
            $display("PASS: paddle_y correctly clamped at top, value = %0d", paddle_y);
        btn_up = 0;

        $display("Simulation complete.");
        $stop;
    end

endmodule