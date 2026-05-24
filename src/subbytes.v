// =============================================================
// subbytes.v
// SubBytes: substitute each of the 16 state bytes through the
// AES S-box. Implemented as 16 parallel instances of the shared
// sbox module (sbox.v) -- one source of truth for the table.
// =============================================================
module subbytes (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sb
            sbox u_sbox (
                .addr (state_in [i*8 +: 8]),
                .data (state_out[i*8 +: 8])
            );
        end
    endgenerate

endmodule
