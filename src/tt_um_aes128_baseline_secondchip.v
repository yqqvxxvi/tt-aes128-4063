// =============================================================
// tt_um_aes128_baseline_secondchip.v
// Tiny Tapeout top-level wrapper (group: SecondChip).
//
// Tiny Tapeout exposes only 8 dedicated inputs, 8 dedicated
// outputs and 8 bidirectional pins. AES-128 needs 256 input bits
// (key + plaintext) and 128 output bits, so this wrapper
// serializes them BIT-SERIALLY around the aes_core_baseline core
// (combinational all-round-keys schedule -- the unoptimised baseline,
//  paired with tt_um_aes128_secondchip / aes_core_otf for the rubric
//  chip-area comparison).
//
// Pin map
//   ui_in[0]  serial_in   data bit, shifted in while load_en=1
//   ui_in[1]  load_en     shift serial_in into the 256-bit input reg
//   ui_in[2]  start        rising edge -> begin encryption
//   ui_in[3]  out_en       shift ciphertext out while high
//   uo_out[0] serial_out  ciphertext bit, MSB first
//   uo_out[1] busy        core running
//   uo_out[2] done        ciphertext valid (held until next start)
//   uio[7:0]  unused (uio_oe = 0, uio_out = 0)
//
// Load order (MSB first): 128 key bits THEN 128 plaintext bits.
//   after 256 load clocks: in_sr[255:128]=key, in_sr[127:0]=plaintext
// Read order (MSB first): 128 ciphertext bits, ct[127] first.
// =============================================================
module tt_um_aes128_baseline_secondchip (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // bidirectional input path  (unused)
    output wire [7:0] uio_out,  // bidirectional output path (unused)
    output wire [7:0] uio_oe,   // bidirectional enable      (all inputs)
    input  wire       ena,      // design selected (unused)
    input  wire       clk,
    input  wire       rst_n     // active-low reset
);

    wire rst = ~rst_n;

    // ---- input pin aliases ----
    wire serial_in = ui_in[0];
    wire load_en   = ui_in[1];
    wire start_pin = ui_in[2];
    wire out_en    = ui_in[3];

    // ---- 256-bit input shift register: {key, plaintext} ----
    reg [255:0] in_sr;
    always @(posedge clk) begin
        if (rst)          in_sr <= 256'd0;
        else if (load_en) in_sr <= {in_sr[254:0], serial_in};
    end

    // ---- start edge detect (one-cycle core pulse) ----
    reg  start_d;
    always @(posedge clk) begin
        if (rst) start_d <= 1'b0;
        else     start_d <= start_pin;
    end
    wire core_start = start_pin & ~start_d;

    // ---- AES core (on-the-fly key schedule) ----
    wire         core_busy, core_done;
    wire [127:0] core_ct;
    aes_core_baseline u_core (
        .clk        (clk),
        .rst        (rst),
        .start      (core_start),
        .plaintext  (in_sr[127:0]),
        .key        (in_sr[255:128]),
        .done       (core_done),
        .busy       (core_busy),
        .ciphertext (core_ct)
    );

    // ---- done latch (held until next start) ----
    reg done_flag;
    always @(posedge clk) begin
        if (rst)             done_flag <= 1'b0;
        else if (core_start) done_flag <= 1'b0;
        else if (core_done)  done_flag <= 1'b1;
    end

    // ---- 128-bit output shift register, MSB first ----
    reg [127:0] out_sr;
    always @(posedge clk) begin
        if (rst)            out_sr <= 128'd0;
        else if (core_done) out_sr <= core_ct;             // latch result
        else if (out_en)    out_sr <= {out_sr[126:0], 1'b0}; // shift out
    end

    // ---- outputs ----
    assign uo_out[0] = out_sr[127];   // serial_out (MSB first)
    assign uo_out[1] = core_busy;     // busy
    assign uo_out[2] = done_flag;     // done / valid
    assign uo_out[7:3] = 5'b00000;

    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;            // all uio pins are inputs (unused)

    // tie off unused inputs to avoid synthesis warnings
    wire _unused = &{ena, uio_in, ui_in[7:4], 1'b0};

endmodule
