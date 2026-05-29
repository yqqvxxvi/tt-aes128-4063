# Tiny Tapeout submission - AES-128 BASELINE (group SecondChip)

This is the **baseline (unoptimised)** Tiny Tapeout variant of the AES-128 project: same
bit-serial interface and same datapath as `tinytapeout/` (the optimised on-the-fly version),
but with the **combinational all-round-keys schedule** (`key_expansion_flat`). It exists to
provide a real backend comparison against the optimised core for rubric criterion 4
(reduce chip area).

```
tinytapeout_baseline/
├── info.yaml          # TT metadata; top_module: tt_um_aes128_baseline_secondchip; tiles: "8x2"
├── src/
│   ├── config.json                          # base LibreLane config -- DO NOT DELETE
│   ├── tt_um_aes128_baseline_secondchip.v   # bit-serial wrapper (TT top)
│   ├── aes_core_baseline.v                  # iterative core, combinational all-keys
│   ├── key_expansion_flat.v                 # packed-bus key schedule (Yosys-friendly)
│   ├── sbox.v  subbytes.v  shiftrows.v  mixcolumns.v  addroundkey.v
├── test/              # cocotb test, ttsky + cocotb 2.0.1 compatible
│   ├── Makefile  tb.v  test.py  requirements.txt
└── docs/
    └── info.md
```

## Heads-up: this might not fit at the standard maximum tile size

Quartus measured the baseline core at **~14,547 logic elements** (vs ~5,050 for the OTF
version), driven by ~40 S-boxes in the key schedule plus 16 in the datapath. Even at the
largest standard Tiny Tapeout tile size (`8x2`, 16 tiles) it may report `GPL-0301
Utilization > 100%`. That is itself a useful comparison result: it documents that the
on-the-fly optimisation is what makes this design practical to tape out at all.

If it does report over-utilisation, options in priority order:
1. Try `PL_TARGET_DENSITY_PCT = 80` (raise in `src/config.json`) - may give just enough.
2. Accept it as the negative-result evidence and only tape out the OTF version.

## How to apply to a Tiny Tapeout submission repo

Same procedure as the optimised version (see `../tinytapeout/README.md`):

1. Create a *new* Tiny Tapeout repo from the current ttsky-verilog-template
   (https://github.com/TinyTapeout/ttsky-verilog-template) - this is a separate submission
   from the OTF one, so it needs its own GitHub repo.
2. **Keep** the template's `src/config.json`, `tt/` submodule, `.github/workflows/`, and
   `test/` scaffolding.
3. Copy the 8 `.v` files from this folder's `src/` into the repo's `src/`, and delete the
   placeholder `src/project.v`.
4. Overwrite `info.yaml`, `docs/info.md`, `test/Makefile`, `test/tb.v`, `test/test.py`,
   `test/requirements.txt` with the versions from this folder.
5. Commit and push. The `gds` and `test` actions run automatically.

## Local test (optional)

With cocotb 2.0.1 + Icarus Verilog:

```
cd test
make            # RTL simulation
make GATES=yes  # gate-level (needs hardened netlist + sky130 PDK)
```

End-to-end functional verification (all 20 NIST vectors through the bit-serial wrapper) is
also run in ModelSim at the repo root via `tb/tb_tt_um_aes128_baseline.v`
(20 PASS / 0 FAIL).
