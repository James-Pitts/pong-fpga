// Module: vga_sync
// Purpose: Generates VGA horizontal/vertical sync pulses, video_on blanking
//          signal, and pixel coordinates for 640x480@60Hz timing.

module vga_sync (
    input  wire       clk,
    input  wire       reset,
    output reg        hsync,
    output reg        vsync,
    output reg        video_on,
    output reg [9:0]  pixel_x,
    output reg [9:0]  pixel_y
);

    // Internal counters
    reg [9:0] h_count;
    reg [9:0] v_count;

    // Horizontal counter: counts 0-799, wraps every line
    always @(posedge clk) begin
        if (reset) begin
            h_count <= 0;
        end else begin
            if (h_count == 799) begin
                h_count <= 0;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // Vertical counter: increments once per completed line, counts 0-524
    always @(posedge clk) begin
        if (reset) begin
            v_count <= 0;
        end else begin
            if (h_count == 799) begin
                if (v_count == 524) begin
                    v_count <= 0;
                end else begin
                    v_count <= v_count + 1;
                end
            end
        end
    end

    // hsync, vsync, video_on, pixel_x, pixel_y — combinational-feeling logic,
    // but since outputs are `reg` and this is clocked, still lives in an
    // always @(posedge clk) block per our established pattern.
    always @(posedge clk) begin
        if (reset) begin
            hsync <= 1;
            vsync <= 1;
            video_on <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
        end else begin
            hsync <= (h_count >= 656 && h_count <= 751) ? 0 : 1;
            vsync <= (v_count >= 490 && v_count <= 491) ? 0 : 1;
            video_on <= (h_count <= 639 && v_count <= 479);
            pixel_x <= h_count;
            pixel_y <= v_count;
        end
    end

endmodule