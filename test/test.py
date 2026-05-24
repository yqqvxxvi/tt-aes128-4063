# cocotb test for tt_um_aes128_secondchip
#
# Drives the bit-serial protocol of the AES-128 wrapper and checks the
# ciphertext against NIST test vectors. Runs in the Tiny Tapeout
# GitHub Actions flow for both RTL (GATES=no) and gate-level (GATES=yes).
#
# Pin map (see info.yaml / docs/info.md):
#   ui_in[0] serial_in   ui_in[1] load_en   ui_in[2] start   ui_in[3] out_en
#   uo_out[0] serial_out  uo_out[1] busy     uo_out[2] done
#
# Vector sources: NIST FIPS 197 (App B, App C.1), NIST SP 800-38A ECB.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles

# (key, plaintext, expected_ciphertext)  -- all 128-bit ints
VECTORS = [
    (0x2b7e151628aed2a6abf7158809cf4f3c,
     0x3243f6a8885a308d313198a2e0370734,
     0x3925841d02dc09fbdc118597196a0b32),   # FIPS 197 Appendix B
    (0x000102030405060708090a0b0c0d0e0f,
     0x00112233445566778899aabbccddeeff,
     0x69c4e0d86a7b0430d8cdb78070b4c55a),   # FIPS 197 Appendix C.1
    (0x2b7e151628aed2a6abf7158809cf4f3c,
     0x6bc1bee22e409f96e93d7e117393172a,
     0x3ad77bb40d7a3660a89ecaf32466ef97),   # SP 800-38A ECB block 1
]

# ui_in bit positions
SERIAL_IN = 0
LOAD_EN   = 1
START     = 2
OUT_EN    = 3


async def load_inputs(dut, key, pt):
    """Shift in 128 key bits then 128 plaintext bits, MSB first."""
    stream = (key << 128) | pt          # 256-bit: key in [255:128], pt in [127:0]
    for i in range(255, -1, -1):
        await FallingEdge(dut.clk)
        bit = (stream >> i) & 1
        dut.ui_in.value = (1 << LOAD_EN) | (bit << SERIAL_IN)
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0


async def pulse_start(dut):
    await FallingEdge(dut.clk)
    dut.ui_in.value = (1 << START)
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0


async def wait_done(dut):
    for _ in range(100):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 2) & 1:
            return
    assert False, "done never asserted"


async def read_ct(dut):
    """Shift out 128 ciphertext bits, MSB first."""
    ct = 0
    for _ in range(128):
        await FallingEdge(dut.clk)
        ct = (ct << 1) | (int(dut.uo_out.value) & 1)
        dut.ui_in.value = (1 << OUT_EN)
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0
    return ct


@cocotb.test()
async def test_aes128(dut):
    dut._log.info("start")
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    for (key, pt, expected) in VECTORS:
        await load_inputs(dut, key, pt)
        await pulse_start(dut)
        await wait_done(dut)
        got = await read_ct(dut)
        assert got == expected, (
            f"AES-128 mismatch\n key={key:032x}\n pt ={pt:032x}\n"
            f" exp={expected:032x}\n got={got:032x}"
        )
        dut._log.info(f"PASS key={key:032x} ct={got:032x}")

    dut._log.info("all vectors passed")
