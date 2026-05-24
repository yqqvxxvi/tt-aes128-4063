// =============================================================
// addroundkey.v
// 功能：把当前状态 state 和当前轮密钥 round_key 做 XOR
// 这是 AES 里最简单的一步，128位全部同时异或，一行逻辑完成
// =============================================================
module addroundkey (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);

    // 全部128位同时 XOR，没有时序逻辑，纯组合电路
    assign state_out = state_in ^ round_key;

endmodule
