# Scheduling Perturbation, Concurrency Faults, and Power-Cap Conditions

Code, scripts, and data accompanying:

> R. M. Amali, S. Nabilah, A. J. Afafa, and Supriyanto, "An Empirical Study of
> Scheduling Perturbation, Concurrency Faults, and Power-Cap Conditions on a
> 15 W-Class Client Device," *ICIMCIS*, 20XX. [DOI link once published]

This repository contains everything needed to reproduce the 300-run dataset
and the figures/statistics reported in the paper: the seeded concurrency
benchmark, the randomized-yield interposition library, the automated
execution harness, the raw and processed datasets, and the plotting scripts.

## Repository structure

```
.
├── scripts/                      # Benchmark, interposition library, and execution harness
│   ├── preparation.sh            # One-time system prep (stop services, set CPU governor, verify AC)
│   ├── build.sh                  # Compiles cpu_melter_bug and libpct.so
│   ├── cpu_melter_bug.c          # Benchmark: 8-thread seeded non-atomic read-modify-write race
│   ├── pct_wrapper.c             # LD_PRELOAD wrapper: randomized yield injection (10% probability)
│   ├── run_schema_experiment.sh  # Main harness: 3x2 factorial design, 50 replicates/cell
│   └── restore.sh                # Restore services/governor changed by preparation.sh
├── analysis/
│   └── generate_fig_plots.R      # Reproduces Fig. 2, 3, 4 from data/processed/
├── data/
│   ├── raw/                      # Unmodified harness output (see CHANGELOG.md)
│   └── processed/                # Relabeled, publication-ready dataset (see CHANGELOG.md)
├── CHANGELOG.md                  # Exact data dictionary: what changed between raw -> processed, and why
├── CITATION.cff                  # Machine-readable citation metadata
└── LICENSE                       # MIT (code) -- see DATA_LICENSE.md for data terms
```

## Requirements

Tested on an AMD Ryzen 5 3500U laptop running a standard Linux distribution
(Arch-based) with the following tools installed and on `PATH`:

- `gcc`, `make`
- `ryzenadj` (requires the `ryzen_smu` kernel module)
- `turbostat`, `perf` (Linux kernel tools)
- `lm-sensors` (`sensors` command)
- `uuidgen`, `bc`

Root privileges (`sudo`) are required: the harness reads/writes power-limit
registers via `ryzenadj` and reads CPU performance counters via `perf`.

## Reproducing the experiment

```bash
cd scripts
sudo ./preparation.sh             # one-time: stop background services, set performance governor
./build.sh                        # compiles cpu_melter_bug and libpct.so
sudo ./run_schema_experiment.sh   # runs the full 3x2 x 50-replicate design (~1-2 hours)
sudo ./done.sh                    # restore services/governor changed by preparation.sh
```

Output lands in `results/<study_id>/<block_id>/`, mirroring the structure
under `data/raw/` in this repository.

**Hardware note:** `run_schema_experiment.sh` uses `ryzenadj` to set
STAPM/PPT power limits directly via the SMU. This is specific to AMD Ryzen
mobile processors and will not work on other platforms without modification.
The 45 W condition in this study exceeds the AMD Ryzen 5 3500U's documented
cTDP range (12-35 W); see the paper's Methodology and Threats to Validity
sections for details.

Checksums embed paths relative to data/raw/ at collection time. To verify: cd data/raw && sha256sum -c results/<study_id>/<block_id>/<run_id>/checksums.sha256.

**Naming note.** The harness, wrapper, and raw data use the legacy identifier pct (pct_wrapper.c, libpct.so, PCT_SEED, scheduler_policy="pct"). This name predates the study design and does not denote formal Probabilistic Concurrency Testing: the wrapper only injects sched_yield() with 10% probability before each pthread_mutex_lock call. The paper calls this technique randomized yield injection (RYI); data/processed/ uses the label randomized_yield (see CHANGELOG.md).

## Reproducing the figures and statistics

```bash
cd analysis
Rscript generate_fig_plots.R ../data/processed/publication_ready_dataset.csv
```

The Fisher exact tests, Holm correction, odds ratios, and the
cap x mode logistic-regression interaction test reported in the paper's
Discussion section can be reproduced directly from
`data/processed/publication_ready_dataset.csv` -- see the paper for exact
model specifications.

## Data

Two dataset versions are provided; see `CHANGELOG.md` for the exact,
auditable difference between them (two categorical relabelings only --
no numeric value was changed):

- `data/raw/` -- exactly as produced by `run_schema_experiment.sh`
- `data/processed/publication_ready_dataset.csv` -- the version referenced
  by the paper's Result and Discussion sections

## License

Code in `scripts/` and `analysis/` is released under the MIT License (see
`LICENSE`). Data in `data/` is released under CC BY 4.0 (see
`DATA_LICENSE.md`).

## Citation

See `CITATION.cff`, or cite directly:
DOI: 10.5281/zenodo.23234432

```bibtex
@inproceedings{amali2026scheduling,
  title     = {An Empirical Study of Scheduling Perturbation, Concurrency Faults, and Power-Cap Conditions on a 15 W-Class Client Device},
  author    = {Amali, Robbi Muntaha and Nabilah, Sarah and Afafa, Aura Jannati and Supriyanto},
  booktitle = {ICIMCIS},
  year      = {2026}
}
```
