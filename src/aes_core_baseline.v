// =============================================================
// aes_core_baseline.v  -  AES-128 core, iterative one-round-per-cycle
//                         with COMBINATIONAL all-round-keys schedule.
//
// Same FSM/datapath as the original aes_top.v, and the same parallel
// port list so the existing testbenches can drive it directly. The
// only difference vs aes_top:
//   - key_expansion_flat (packed bus output) replaces key_expansion
//     (SystemVerilog unpacked-array port), so the Yosys-based Tiny
//     Tapeout flow can synthesise it.
//
// This is the BASELINE for the rubric area comparison (large
// combinational key schedule, ~40 S-boxes). The optimised counterpart
// is aes_core_otf.v (on-the-fly schedule, 4 key-schedule S-boxes).
// =============================================================
module aes_core_baseline (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg          done,
    output reg          busy,
    output reg  [127:0] ciphertext
);

    localparam IDLE        = 3'd0;
    localparam INIT_ARK    = 3'd1;
    localparam MAIN_ROUND  = 3'd2;
    localparam FINAL_ROUND = 3'd3;
    localparam DONE_ST     = 3'd4;

    reg [2:0]   state;
    reg [3:0]   round_cnt;
    reg [127:0] state_reg;

    // ---- key schedule (packed bus: K_i at [i*128 +: 128]) ----
    wire [11*128-1:0] round_key_flat;
    key_expansion_flat u_key_exp (
        .key            (key),
        .round_key_flat (round_key_flat)
    );

    wire [127:0] rk0     = round_key_flat[0*128    +: 128]; // K0  for INIT_ARK
    wire [127:0] rk_last = round_key_flat[10*128   +: 128]; // K10 for FINAL_ROUND

    // K_{round_cnt} for MAIN_ROUND. Explicit case (not a variable part-select)
    // so Yosys generates only a clean 11-way mux -- a variable part-select
    // with a 4-bit index on an 11-slot bus would create 5 out-of-range mux
    // inputs that synthesise to floating nets and break OpenROAD detailed
    // placement (RSZ-0020 / DPL-0036).
    reg [127:0] rk_cur;
    always @(*) begin
        case (round_cnt)
            4'd0:  rk_cur = round_key_flat[0    +: 128];
            4'd1:  rk_cur = round_key_flat[128  +: 128];
            4'd2:  rk_cur = round_key_flat[256  +: 128];
            4'd3:  rk_cur = round_key_flat[384  +: 128];
            4'd4:  rk_cur = round_key_flat[512  +: 128];
            4'd5:  rk_cur = round_key_flat[640  +: 128];
            4'd6:  rk_cur = round_key_flat[768  +: 128];
            4'd7:  rk_cur = round_key_flat[896  +: 128];
            4'd8:  rk_cur = round_key_flat[1024 +: 128];
            4'd9:  rk_cur = round_key_flat[1152 +: 128];
            4'd10: rk_cur = round_key_flat[1280 +: 128];
            default: rk_cur = 128'd0;
        endcase
    end

    // ---- round datapath (combinational) ----
    wire [127:0] sb_out, sr_out, mc_out;
    wire [127:0] ark_init, ark_main, ark_final;

    subbytes   u_sb (.state_in(state_reg), .state_out(sb_out));
    shiftrows  u_sr (.state_in(sb_out),    .state_out(sr_out));
    mixcolumns u_mc (.state_in(sr_out),    .state_out(mc_out));

    addroundkey u_ark_init  (.state_in(plaintext), .round_key(rk0),     .state_out(ark_init));
    addroundkey u_ark_main  (.state_in(mc_out),    .round_key(rk_cur),  .state_out(ark_main));
    addroundkey u_ark_final (.state_in(sr_out),    .round_key(rk_last), .state_out(ark_final));

    // ---- FSM ----
    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            round_cnt  <= 4'd0;
            state_reg  <= 128'd0;
            done       <= 1'b0;
            busy       <= 1'b0;
            ciphertext <= 128'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy  <= 1'b1;
                        state <= INIT_ARK;
                    end
                end
                INIT_ARK: begin
                    state_reg <= ark_init;
                    round_cnt <= 4'd1;
                    state     <= MAIN_ROUND;
                end
                MAIN_ROUND: begin
                    state_reg <= ark_main;
                    if (round_cnt == 4'd9) state <= FINAL_ROUND;
                    else round_cnt <= round_cnt + 4'd1;
                end
                FINAL_ROUND: begin
                    state_reg <= ark_final;
                    state     <= DONE_ST;
                end
                DONE_ST: begin
                    ciphertext <= state_reg;
                    done       <= 1'b1;
                    busy       <= 1'b0;
                    state      <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
