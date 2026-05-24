# Tiny Tapeout submission - AES-128 (group SecondChip)

This folder is the Tiny Tapeout version of the AES-128 project. It is self-contained:
the synthesizable RTL lives in `src/`, the cocotb test in `test/`, the datasheet in
`docs/`, and the project metadata in `info.yaml`.

```
tinytapeout/
├── info.yaml          # TT project metadata + pinout (top_module: tt_um_aes128_secondchip)
├── src/               # synthesizable RTL (copied from repo root; no testbench, no key_expansion.v)
│   ├── tt_um_aes128_secondchip.v   # bit-serial wrapper (TT top)
│   ├── aes_core_otf.v              # iterative core, on-the-fly key schedule
│   ├── sbox.v  subbytes.v  shiftrows.v  mixcolumns.v  addroundkey.v
├── test/              # cocotb test (RTL + gate-level)
│   ├── Makefile  tb.v  test.py  requirements.txt
└── docs/
    └── info.md        # datasheet (how it works / how to test / pinout)
```

## Turning this into a hardened TT submission

The GDS hardening flow and the GitHub Actions workflows are maintained by Tiny Tapeout in
their template repo, so do **not** copy them by hand. Instead:

1. Create a new repo from the current Tiny Tapeout Verilog template
   (https://tinytapeout.com/hdl/ -> "HDL templates" -> use the template for the open
   shuttle). This gives you `.github/workflows/` (the `gds`, `test` and `docs` actions).
2. Replace the template's `src/`, `test/`, `docs/info.md` and `info.yaml` with the files
   from this folder.
3. Push. The **GDS GitHub Action** runs OpenLane and produces the backend evidence:
   gate-level netlist, GDS, layout PNG, and utilization/timing reports (downloadable from
   the Actions run artifacts and rendered on the project's GitHub Pages).
4. The **test action** runs `test/test.py` against the RTL and, after hardening, the
   gate-level netlist.

## Tile size

`info.yaml` requests `2x2` tiles as a starting point. AES-128 is S-box dominated
(16 S-boxes in the datapath + 4 in the key schedule). If the first GDS run reports high
utilization or routing congestion, increase `tiles` (e.g. `3x2`, `4x2`) and re-run.

## Local test (optional)

With cocotb + Icarus Verilog installed:

```
cd test
make            # RTL simulation
make GATES=yes  # gate-level (needs the hardened netlist + sky130 PDK)
```

The same functionality is also verified in ModelSim at the repo root via
`tb/tb_tt_um_aes128.v` (all 20 NIST vectors, bit-serial end-to-end).
