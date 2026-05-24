<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused sections.
-->

## How it works

This project is an **AES-128 encryption accelerator**. It implements the full AES-128
encryption algorithm (the initial AddRoundKey, 9 main rounds of
SubBytes / ShiftRows / MixColumns / AddRoundKey, and a final round without MixColumns)
as an **iterative one-round-per-cycle** datapath, so the round logic is reused across
cycles. Encryption of one 128-bit block takes 11 clock cycles once the data is loaded.

The round keys are produced by an **on-the-fly key schedule**: instead of pre-computing
all 11 round keys, a single 128-bit round-key register is advanced by one round each cycle
(RotWord -> SubWord -> Rcon -> XOR chain), using only 4 S-boxes. This keeps the silicon
area small.

AES-128 needs 256 input bits (128-bit key + 128-bit plaintext) and produces 128 output
bits, but Tiny Tapeout only provides 8 input / 8 output / 8 bidirectional pins. So the
core is wrapped in a **bit-serial interface**: the key and plaintext are shifted in one
bit at a time, and the ciphertext is shifted out one bit at a time.

### Interface

| Pin | Direction | Name | Function |
|-----|-----------|------|----------|
| `ui_in[0]` | in  | `serial_in`  | one data bit, captured while `load_en` = 1 |
| `ui_in[1]` | in  | `load_en`    | shift `serial_in` into the 256-bit input register |
| `ui_in[2]` | in  | `start`      | rising edge starts encryption |
| `ui_in[3]` | in  | `out_en`     | shift the ciphertext out, one bit per clock |
| `uo_out[0]`| out | `serial_out` | ciphertext bit, MSB first |
| `uo_out[1]`| out | `busy`       | high while the core is computing |
| `uo_out[2]`| out | `done`       | high when the ciphertext is valid (held until next `start`) |
| `uio[*]`   | -   | unused       | driven to 0, `uio_oe` = 0 |

## How to test

1. Apply reset: hold `rst_n` low for a few clocks, then release.
2. **Load:** hold `load_en` (`ui_in[1]`) high for **256 clock cycles**, presenting one bit
   on `serial_in` (`ui_in[0]`) each cycle. Send the **128 key bits first, then the 128
   plaintext bits, MSB first** (the very first bit is `key[127]`).
3. **Start:** pulse `start` (`ui_in[2]`) high for one clock.
4. **Wait:** poll `done` (`uo_out[2]`); it goes high about 11 clocks after `start`.
5. **Read:** hold `out_en` (`ui_in[3]`) high for **128 clock cycles**, sampling
   `serial_out` (`uo_out[0]`) each cycle to reconstruct the ciphertext, MSB first.

The included cocotb test (`test/test.py`) does exactly this for the NIST FIPS-197 and
SP 800-38A vectors and checks the result. Run it with `cd test && make` (RTL) or
`make GATES=yes` (gate level).

Example (NIST FIPS-197 Appendix B):
- key = `2b7e151628aed2a6abf7158809cf4f3c`
- plaintext = `3243f6a8885a308d313198a2e0370734`
- ciphertext = `3925841d02dc09fbdc118597196a0b32`

## External hardware

None. Inputs can be driven from the on-board RP2040 / DIP switches and outputs read on
the LEDs or via the test harness. AES decryption is out of scope (encryption only).
