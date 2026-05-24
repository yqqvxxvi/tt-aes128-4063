// =============================================================
// shiftrows.v
// 状态存储：列优先，s[列][行]
//   state[127:96] = 列0 = {行0,行1,行2,行3}
//   s_XY = 列X 行Y
//
// ShiftRows：行r循环左移r列
//   输出[列c][行r] = 输入[列(c+r)%4][行r]
// =============================================================
module shiftrows (
    input  wire  [127:0] state_in,
    output wire  [127:0] state_out
);

    wire [7:0] s00, s01, s02, s03;  // 列0 行0~3
    wire [7:0] s10, s11, s12, s13;  // 列1 行0~3
    wire [7:0] s20, s21, s22, s23;  // 列2 行0~3
    wire [7:0] s30, s31, s32, s33;  // 列3 行0~3

    assign s00=state_in[127:120]; assign s01=state_in[119:112];
    assign s02=state_in[111:104]; assign s03=state_in[103:96];

    assign s10=state_in[95:88];   assign s11=state_in[87:80];
    assign s12=state_in[79:72];   assign s13=state_in[71:64];

    assign s20=state_in[63:56];   assign s21=state_in[55:48];
    assign s22=state_in[47:40];   assign s23=state_in[39:32];

    assign s30=state_in[31:24];   assign s31=state_in[23:16];
    assign s32=state_in[15:8];    assign s33=state_in[7:0];

    // 输出列c行r = 输入列(c+r)%4 行r
    assign state_out = {
        s00, s11, s22, s33,   // 输出列0: 行0←列0, 行1←列1, 行2←列2, 行3←列3
        s10, s21, s32, s03,   // 输出列1: 行0←列1, 行1←列2, 行2←列3, 行3←列0
        s20, s31, s02, s13,   // 输出列2: 行0←列2, 行1←列3, 行2←列0, 行3←列1
        s30, s01, s12, s23    // 输出列3: 行0←列3, 行1←列0, 行2←列1, 行3←列2
    };

endmodule