// =============================================================
// aes_top.v  —  AES-128 顶层（迭代每周期一轮）
// 需要 SystemVerilog 编译
// =============================================================
module aes_top (
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

    // ---- 密钥扩展 ----
    wire [127:0] round_key [0:10];
    key_expansion u_key_exp (
        .key       (key),
        .round_key (round_key)
    );

    // ---- 数据路径（组合逻辑）----
    wire [127:0] ark_init_out;
    wire [127:0] sb_out, sr_out, mc_out;
    wire [127:0] ark_main_out, ark_final_out;

    addroundkey u_ark_init  (.state_in(plaintext),  .round_key(round_key[0]),         .state_out(ark_init_out));
    subbytes    u_sb         (.state_in(state_reg),                                    .state_out(sb_out));
    shiftrows   u_sr         (.state_in(sb_out),                                       .state_out(sr_out));
    mixcolumns  u_mc         (.state_in(sr_out),                                       .state_out(mc_out));
    addroundkey u_ark_main  (.state_in(mc_out),     .round_key(round_key[round_cnt]), .state_out(ark_main_out));
    addroundkey u_ark_final (.state_in(sr_out),     .round_key(round_key[10]),        .state_out(ark_final_out));

    // ---- FSM ----
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; round_cnt <= 4'd0;
            state_reg <= 128'd0; done <= 1'b0;
            busy <= 1'b0; ciphertext <= 128'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin busy <= 1'b1; state <= INIT_ARK; end
                end
                INIT_ARK: begin
                    state_reg <= ark_init_out;
                    round_cnt <= 4'd1;
                    state     <= MAIN_ROUND;
                end
                MAIN_ROUND: begin
                    state_reg <= ark_main_out;
                    if (round_cnt == 4'd9) state <= FINAL_ROUND;
                    else round_cnt <= round_cnt + 4'd1;
                end
                FINAL_ROUND: begin
                    state_reg <= ark_final_out;
                    state     <= DONE_ST;
                end
                DONE_ST: begin
                    ciphertext <= state_reg;
                    done <= 1'b1; busy <= 1'b0;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule