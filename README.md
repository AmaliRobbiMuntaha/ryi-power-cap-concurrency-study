# Scheduling Perturbation, Concurrency Faults, and Power-Cap Conditions

Code, scripts, and data accompanying:

> R. M. Amali, S. Nabilah, A. J. Afafa, and Supriyanto, "An Empirical Study of
> Scheduling Perturbation, Concurrency Faults, and Power-Cap Conditions on a
> 15 W-Class Client Device," *ICIMCIS*, 2026.

This repository contains everything needed to reproduce the 300-run dataset
and the figures/statistics reported in the paper: the seeded concurrency
benchmark, the randomized-yield interposition library, the automated
execution harness, the raw and processed datasets, and the plotting scripts.

## Repository structure

```
.
├── CHANGELOG.md                  # Exact data dictionary: what changed between raw -> processed, and why
├── CITATION.cff                  # Machine-readable citation metadata
├── DATA_LICENSE.md
├── LICENSE                       # MIT (code) -- see DATA_LICENSE.md for data terms
├── README.md
├── SHA256SUMS
├── analysis
│   ├── build_dataset.R
│   ├── extract_telemetry.py
│   ├── generate_fig_plots.R      # Reproduces Fig. 2, 3, 4 from data/processed/
│   ├── sensitivity.R
│   ├── sessionInfo.txt
│   ├── stats_logistic.R
│   ├── table_cap_effects.csv
│   ├── table_ryi_effects.csv
│   └── telemetry_per_run.csv
├── data
│   ├── processed                 # Relabeled, publication-ready dataset (see CHANGELOG.md)
│   │   ├── publication_ready_dataset_v2.csv   # relabeled; used in the paper
│   │   └── publication_ready_dataset.csv      # intermediate: master_run_summary.csv + manifests
│   └── raw                       # Unmodified harness output (see CHANGELOG.md)
│       └── results
│           └── conc15w_v1
│               └── block_01
│                   ├── <run_id>/         # 300 per-run directories
│                   └── master_run_summary.csv
├── docs
│   ├── ENVIRONMENT.txt
│   ├── ORIGINAL_SHA256.txt
│   └── translation.diff
└── scripts                       # Benchmark, interposition library, and execution harness
    ├── build.sh                  # Compiles cpu_melter_bug and libpct.so
    ├── cpu_melter_bug
    ├── cpu_melter_bug.c          # Benchmark: 8-thread seeded non-atomic read-modify-write race
    ├── libpct.so
    ├── pct_wrapper.c             # LD_PRELOAD wrapper: randomized yield injection (10% probability)
    ├── preparation.sh            # One-time system prep (stop services, set CPU governor, verify AC)
    ├── restore.sh                # Restore services/governor changed by preparation.sh (originally `done.sh`)
    └── run_schema_experiment.sh  # Main harness: 3x2 factorial design, 50 replicates/cell
```

## Requirements

Tested on an AMD Ryzen 5 3500U laptop running Arch Linux (rolling) with the following tools installed and on `PATH` (exact versions: see docs/ENVIRONMENT.txt):

- `gcc`
- `ryzenadj` (requires the `ryzen_smu` kernel module)
- `turbostat`, `perf` (Linux kernel tools)
- `lm-sensors` (`sensors` command)
- `uuidgen`, `bc`
- `cpupower`, `killall (psmisc)`, `lscpu`

Root privileges (`sudo`) are required: the harness reads/writes power-limit
registers via `ryzenadj` and reads CPU performance counters via `perf`.

## Reproducing the experiment

```bash
cd scripts
sudo ./preparation.sh             # one-time: stop background services, set performance governor
./build.sh                        # compiles cpu_melter_bug and libpct.so
sudo ./run_schema_experiment.sh   # full 3x2 x 50-replicate design (~1-2 hours)
sudo ./restore.sh                 # restore services/governor
cd ..
```

Output is written to `scripts/results/<study_id>/<block_id>/`, mirroring `data/raw/`.

**Hardware note:** `run_schema_experiment.sh` uses `ryzenadj` to set
STAPM/PPT power limits directly via the SMU. This is specific to AMD Ryzen
mobile processors and will not work on other platforms without modification.
The 45 W condition in this study exceeds the AMD Ryzen 5 3500U's documented
cTDP range (12-35 W); see the paper's Methodology and Threats to Validity
sections for details.

Checksums embed paths relative to `data/raw/` at collection time.
To verify: `cd data/raw && sha256sum -c results/<study_id>/<block_id>/<run_id>/checksums.sha256`.
Verifying integrity: `sha256sum -c SHA256SUMS`.

**Naming note.** The harness, wrapper, and raw data use the legacy identifier pct (pct_wrapper.c, libpct.so, PCT_SEED, scheduler_policy="pct"). This name predates the study design and does not denote formal Probabilistic Concurrency Testing: the wrapper only injects sched_yield() with 10% probability before each pthread_mutex_lock call. The paper calls this technique randomized yield injection (RYI); data/processed/ uses the label randomized_yield (see CHANGELOG.md).

## Reproducing the figures and statistics

Run from the repository root. Requires Python 3 (standard library only) and R with
`emmeans` and `DescTools` (exact versions in `docs/ENVIRONMENT.txt`).

```bash
python3 analysis/extract_telemetry.py   # raw turbostat logs -> analysis/telemetry_per_run.csv
Rscript analysis/build_dataset.R        # consistency checks raw -> processed
Rscript analysis/stats_logistic.R       # Table I, RQ1, interaction test -> analysis/table_*.csv, sessionInfo.txt
Rscript analysis/sensitivity.R          # drift, quasi-Poisson, ratio of ORs, Holm
(cd analysis && Rscript generate_fig_plots.R ../data/processed/publication_ready_dataset_v2.csv)   # Fig. 2-4
```

## Data

Two dataset versions are provided; see `CHANGELOG.md` for the exact,
auditable difference between them. Three changes only: two categorical relabelings and one column rename. No numeric value was altered.

- `data/raw/` -- exactly as produced by `run_schema_experiment.sh`
- `data/processed/publication_ready_dataset_v2.csv` -- the version referenced
  by the paper's Result and Discussion sections

## License

Code in `scripts/` and `analysis/` is released under the MIT License (see
`LICENSE`). Data in `data/` is released under CC BY 4.0 (see
`DATA_LICENSE.md`).

## Citation

Paper DOI: to be assigned.
Repository archive (code and data): https://doi.org/10.5281/zenodo.23234432

```bibtex
@inproceedings{amali2026scheduling,
  title     = {An Empirical Study of Scheduling Perturbation, Concurrency Faults, and Power-Cap Conditions on a 15 W-Class Client Device},
  author    = {Amali, Robbi Muntaha and Nabilah, Sarah and Afafa, Aura Jannati and Supriyanto},
  booktitle = {ICIMCIS},
  year      = {2026}
}
```
