// =============================================================
// Module: pong_top
// Purpose: Top-level wiring only -- no new logic. Instantiates
//          every previously-verified module and connects them.
//
// Naming note (important -- read before touching wires below):
//   collision.v's hit_left/hit_right   = ball touched a PADDLE
//   score_fsm.v's hit_left/hit_right   = ball touched a WALL
//   These are DIFFERENT events despite the shared name upstream.
//   Renamed here as paddle_hit_left/right and wall_hit_left/right
//   respectively to keep them visually distinct at every wire.
// =============================================================
module pong_top (
    input  wire        clk_50mhz,
    input  wire        reset,
    input  wire        btn_up_left,
    input  wire        btn_down_left,
    input  wire        btn_up_right,
    input  wire        btn_down_right,
    output wire        hsync,
    output wire        vsync,
    output wire [3:0]  vga_red,
    output wire [3:0]  vga_green,
    output wire [3:0]  vga_blue
);

    wire        clk_25mhz;
    wire        video_on;
    wire [9:0]  pixel_x, pixel_y;
    wire [9:0]  paddle_y_left, paddle_y_right;
    wire [9:0]  ball_x, ball_y;
    wire        paddle_hit_left, paddle_hit_right; // ball vs paddle (from collision.v)
    wire        wall_hit_left, wall_hit_right;      // ball vs screen edge (from ball_control.v)
    wire        game_reset;                          // score_fsm.v's ball_reset -> ball_control.v
    wire        game_over;
    wire [3:0]  score_left, score_right;
    wire [1:0]  game_state;

    // ASSUMPTION -- confirm clock_divider's real port names against your file;
    // update this instantiation if they differ.
    clock_divider u_clock_divider (
        .clk     (clk_50mhz),
        .reset   (reset),
        .clk_out (clk_25mhz)
    );

    vga_sync u_vga_sync (
        .clk      (clk_25mhz),
        .reset    (reset),
        .hsync    (hsync),
        .vsync    (vsync),
        .video_on (video_on),
        .pixel_x  (pixel_x),
        .pixel_y  (pixel_y)
    );

    paddle_control u_paddle_left (
        .clk      (clk_25mhz),
        .reset    (reset),
        .btn_up   (btn_up_left),
        .btn_down (btn_down_left),
        .vsync    (vsync),
        .paddle_y (paddle_y_left)
    );

    paddle_control u_paddle_right (
        .clk      (clk_25mhz),
        .reset    (reset),
        .btn_up   (btn_up_right),
        .btn_down (btn_down_right),
        .vsync    (vsync),
        .paddle_y (paddle_y_right)
    );

    ball_control u_ball_control (
        .clk              (clk_25mhz),
        .reset            (reset),
        .vsync            (vsync),
        .paddle_hit_left  (paddle_hit_left),
        .paddle_hit_right (paddle_hit_right),
        .game_reset       (game_reset),
        .ball_x           (ball_x),
        .ball_y           (ball_y),
        .wall_hit_left    (wall_hit_left),
        .wall_hit_right   (wall_hit_right)
    );

    collision u_collision (
        .clk            (clk_25mhz),
        .reset          (reset),
        .ball_x         (ball_x),
        .ball_y         (ball_y),
        .paddle_y_left  (paddle_y_left),
        .paddle_y_right (paddle_y_right),
        .hit_left       (paddle_hit_left),
        .hit_right      (paddle_hit_right)
    );

    score_fsm #(.WIN_SCORE(5)) u_score_fsm (
        .clk         (clk_25mhz),
        .reset       (reset),
        .hit_left    (wall_hit_left),
        .hit_right   (wall_hit_right),
        .score_left  (score_left),
        .score_right (score_right),
        .ball_reset  (game_reset),
        .game_over   (game_over),
        .state       (game_state)
    );

    rgb_mux u_rgb_mux (
        .clk            (clk_25mhz),
        .reset          (reset),
        .video_on       (video_on),
        .pixel_x        (pixel_x),
        .pixel_y        (pixel_y),
        .ball_x         (ball_x),
        .ball_y         (ball_y),
        .paddle_y_left  (paddle_y_left),
        .paddle_y_right (paddle_y_right),
        .red            (vga_red),
        .green          (vga_green),
        .blue           (vga_blue)
    );

endmodule