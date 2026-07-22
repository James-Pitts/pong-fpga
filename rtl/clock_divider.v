// Module: clock_divider
// Purpose: Takes the board's 50 MHz clock and produces a
//          25 MHz clock for driving VGA timing.

module clock_divider (
    input  wire clk,       // 50 MHz clock coming from the board
    input wire reset,
    output reg  clk_out // 25 MHz clock we are creating
);

    // Every time the fast clock ticks (rising edge),
    // we want to flip clk_out from 0 to 1 or 1 to 0.

    initial clk_out = 1'b0;

    always @(posedge clk) begin
        clk_out <= ~clk_out;
        // Flip clk_out to its opposite value.
    end

endmodule