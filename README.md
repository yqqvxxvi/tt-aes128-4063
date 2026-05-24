# Tiny Tapeout submission - AES-128 (group SecondChip)

Tiny Tapeout version of the AES-128 project. The synthesizable RTL is in `src/`, the cocotb
test in `test/`, the datasheet in `docs/`, and the project metadata in `info.yaml`. These are
**drop-in files for the `ttsky-verilog-template`** (SKY130 / LibreLane shuttle).

```
tinytapeout/
├── info.yaml          # TT metadata + pinout (top_module: tt_um_aes128_secondchip)
├── src/
│   ├── config.json                 # base LibreLane config -- REQUIRED, DO NOT DELETE
│   ├── tt_um_aes128_secondchip.v   # bit-serial wrapper (TT top)
│   ├── aes_core_otf.v              # iterative core, on-the-fly key schedule
│   ├── sbox.v  subbytes.v  shiftrows.v  mixcolumns.v  addroundkey.v
├── test/              # cocotb test (RTL + gate-level), matches ttsky + cocotb 2.0.1
│   ├── Makefile  tb.v  test.py  requirements.txt
└── docs/
    └── info.md        # datasheet
```

## How to turn this into a working TT submission

> The previous CI run failed because the template's required `src/config.json` had been
> deleted and the `test/` files were from an old template. **Do not replace the whole `src/`
> directory; keep `src/config.json` and all the template scaffolding.**

Work from a clone of your repo `yqqvxxvi/tt-aes128-4063` (it was made from
`ttsky-verilog-template`, so it already has `tt/`, `.github/workflows/`, and `src/config.json`).
Keep everything from the template and apply only these changes:

1. **`src/`** - copy in the 7 `.v` files from this folder's `src/`, and **delete the placeholder
   `src/project.v`**. **Keep `src/config.json`** (copy it back from this folder if it was lost).
2. **`info.yaml`** - overwrite with this folder's `info.yaml` (sets `top_module`,
   `source_files` = the 7 `.v` files, the bit-serial pinout, `tiles: "2x2"`).
3. **`test/Makefile`** - overwrite (only the `PROJECT_SOURCES` line differs from the template;
   everything else, incl. `COCOTB_TEST_MODULES = test`, is the template's).
4. **`test/tb.v`** - overwrite (template `tb.v` with `tt_um_example` -> `tt_um_aes128_secondchip`).
5. **`test/test.py`** - overwrite (drives the bit-serial protocol for NIST vectors; cocotb 2.0.1).
6. **`test/requirements.txt`** - overwrite (`cocotb==2.0.1`, `pytest==8.4.2`).
7. **`docs/info.md`** - overwrite with this folder's datasheet.

Do **not** touch `tt/`, `.github/workflows/`, `.devcontainer/`, `.vscode/`, `LICENSE`, or
`.gitignore`. Then commit and push - the `gds`, `test` and `docs` actions re-run automatically.

After a green run the GDS action publishes the backend evidence (GDS, gate-level netlist,
layout PNG, utilization/timing reports) as the `tt_submission` / `GDS` artifacts and on the
project's GitHub Pages.

## If the GDS run fails on density / congestion

AES is S-box heavy. If LibreLane reports global-placement failure (`GPL-0302`) or congestion,
increase the area: bump `tiles` in `info.yaml` (`2x2` -> `3x2` -> `4x2`) and/or raise
`PL_TARGET_DENSITY_PCT` in `src/config.json` (values up to ~80 are usually fine), then push again.

## Local test (optional)

With cocotb 2.0.1 + Icarus Verilog installed:

```
cd test
make            # RTL simulation
make GATES=yes  # gate-level (needs the hardened netlist + sky130 PDK)
```

The same functionality is also verified in ModelSim at the repo root via
`tb/tb_tt_um_aes128.v` (all 20 NIST vectors, bit-serial end-to-end, 20 PASS / 0 FAIL).
