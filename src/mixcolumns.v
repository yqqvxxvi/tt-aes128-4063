// =============================================================
// mixcolumns.v
// 功能：对状态矩阵的4列分别做有限域乘法混合
// 方法：调用4次 mixcolumns_one_column（题目已提供的子模块）
//
// 状态按列排列：
//   列0 = state[127:96]
//   列1 = state[95:64]
//   列2 = state[63:32]
//   列3 = state[31:0]
// =============================================================
module mixcolumns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    // 对4列分别调用子模块
    mixcolumns_one_column col0 (
        .col_in  (state_in[127:96]),
        .col_out (state_out[127:96])
    );

    mixcolumns_one_column col1 (
        .col_in  (state_in[95:64]),
        .col_out (state_out[95:64])
    );

    mixcolumns_one_column col2 (
        .col_in  (state_in[63:32]),
        .col_out (state_out[63:32])
    );

    mixcolumns_one_column col3 (
        .col_in  (state_in[31:0]),
        .col_out (state_out[31:0])
    );

endmodule


// =============================================================
// mixcolumns_one_column
// 来源：题目已提供，直接使用
// 功能：对一列4个字节做 GF(2^8) 有限域乘法
// =============================================================
module mixcolumns_one_column (
    input  wire [31:0] col_in,
    output wire [31:0] col_out
);

    wire [7:0] s0, s1, s2, s3;
    wire [7:0] m0, m1, m2, m3;

    assign s0 = col_in[31:24];
    assign s1 = col_in[23:16];
    assign s2 = col_in[15:8];
    assign s3 = col_in[7:0];

    assign m0 = xtime(s0) ^ (xtime(s1) ^ s1) ^ s2 ^ s3;
    assign m1 = s0 ^ xtime(s1) ^ (xtime(s2) ^ s2) ^ s3;
    assign m2 = s0 ^ s1 ^ xtime(s2) ^ (xtime(s3) ^ s3);
    assign m3 = (xtime(s0) ^ s0) ^ s1 ^ s2 ^ xtime(s3);

    assign col_out = {m0, m1, m2, m3};

    // xtime：GF(2^8) 中乘以 2 的操作
    function [7:0] xtime;
        input [7:0] b;
        begin
            if (b[7] == 1'b1)
                xtime = (b << 1) ^ 8'h1b;
            else
                xtime = (b << 1);
        end
    endfunction

endmodule
