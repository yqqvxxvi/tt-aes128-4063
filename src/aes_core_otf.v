// =============================================================
// aes_core_otf.v  -  AES-128 core, iterative one-round-per-cycle
//                    with ON-THE-FLY forward key expansion.
//
// Same port list as aes_top.v (drop-in compatible), so the same
// testbench can drive it. The difference is internal: instead of
// pre-computing all 11 round keys combinationally (aes_top +
// key_expansion, ~40 S-boxes), this core keeps ONE 128-bit round
// key register `rk` and advances it by one round each cycle, in
// lockstep with the datapath. Only 4 S-boxes are needed for the
// key schedule (SubWord), which is the main chip-area saving.
//
// Round key usage:
//   INIT_ARK    uses rk = K0  (= original key)
//   MAIN_ROUND  uses rk = K1..K9   (round_cnt = 1..9)
//   FINAL_ROUND uses rk = K10
// Each cycle rk is updated to the NEXT round key via next_rk.
//
// Plain Verilog-2001 (no unpacked-array ports) -> friendly to the
// Yosys-based Tiny Tapeout hardening flow.
// =============================================================
module aes_core_otf (
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
    reg [127:0] rk;          // current round key

    // ---- round datapath (combinational) ----
    wire [127:0] sb_out, sr_out, mc_out;
    wire [127:0] ark_init, ark_main, ark_final;

    subbytes   u_sb  (.state_in(state_reg), .state_out(sb_out));
    shiftrows  u_sr  (.state_in(sb_out),    .state_out(sr_out));
    mixcolumns u_mc  (.state_in(sr_out),    .state_out(mc_out));

    addroundkey u_ark_init  (.state_in(plaintext), .round_key(rk), .state_out(ark_init));
    addroundkey u_ark_main  (.state_in(mc_out),    .round_key(rk), .state_out(ark_main));
    addroundkey u_ark_final (.state_in(sr_out),    .round_key(rk), .state_out(ark_final));

    // ---- on-the-fly key schedule (combinational next round key) ----
    // Rcon index = round number of the key being GENERATED this cycle:
    //   INIT_ARK generates K1  -> idx 1
    //   MAIN_ROUND (round_cnt=r) generates K(r+1) -> idx r+1
    function [7:0] rcon;
        input [3:0] r;
        case (r)
            4'd1:  rcon = 8'h01; 4'd2:  rcon = 8'h02;
            4'd3:  rcon = 8'h04; 4'd4:  rcon = 8'h08;
            4'd5:  rcon = 8'h10; 4'd6:  rcon = 8'h20;
            4'd7:  rcon = 8'h40; 4'd8:  rcon = 8'h80;
            4'd9:  rcon = 8'h1b; 4'd10: rcon = 8'h36;
            default: rcon = 8'h00;
        endcase
    endfunction

    wire [3:0]  rcon_idx = (state == INIT_ARK) ? 4'd1 : (round_cnt + 4'd1);
    wire [7:0]  rc       = rcon(rcon_idx);

    wire [31:0] w0 = rk[127:96];
    wire [31:0] w1 = rk[95:64];
    wire [31:0] w2 = rk[63:32];
    wire [31:0] w3 = rk[31:0];

    // RotWord(w3) then SubWord via 4 shared S-boxes
    wire [31:0] rotw3 = {w3[23:0], w3[31:24]};
    wire [31:0] subrotw3;
    sbox ks0 (.addr(rotw3[31:24]), .data(subrotw3[31:24]));
    sbox ks1 (.addr(rotw3[23:16]), .data(subrotw3[23:16]));
    sbox ks2 (.addr(rotw3[15:8]),  .data(subrotw3[15:8]));
    sbox ks3 (.addr(rotw3[7:0]),   .data(subrotw3[7:0]));

    wire [31:0] t   = subrotw3 ^ {rc, 24'h000000};
    wire [31:0] nw0 = w0 ^ t;
    wire [31:0] nw1 = w1 ^ nw0;
    wire [31:0] nw2 = w2 ^ nw1;
    wire [31:0] nw3 = w3 ^ nw2;
    wire [127:0] next_rk = {nw0, nw1, nw2, nw3};

    // ---- FSM ----
    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            round_cnt  <= 4'd0;
            state_reg  <= 128'd0;
            rk         <= 128'd0;
            done       <= 1'b0;
            busy       <= 1'b0;
            ciphertext <= 128'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    rk   <= key;             // hold K0 ready for INIT_ARK
                    if (start) begin
                        busy  <= 1'b1;
                        state <= INIT_ARK;
                    end
                end
                INIT_ARK: begin
                    state_reg <= ark_init;   // plaintext ^ K0
                    rk        <= next_rk;     // K0 -> K1
                    round_cnt <= 4'd1;
                    state     <= MAIN_ROUND;
                end
                MAIN_ROUND: begin
                    state_reg <= ark_main;   // round uses K(round_cnt)
                    rk        <= next_rk;     // -> K(round_cnt+1)
                    if (round_cnt == 4'd9) state <= FINAL_ROUND;
                    else round_cnt <= round_cnt + 4'd1;
                end
                FINAL_ROUND: begin
                    state_reg <= ark_final;  // uses K10, no MixColumns
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
