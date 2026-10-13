# Data dictionary / changelog

`data/raw/` contains the unmodified output of `scripts/run_schema_experiment.sh`:
300 per-run directories (manifest.json, faults.csv, run_summary.json, application_trace.log) plus the harness's own consolidated `master_run_summary.csv`, exactly as produced during data collection.

`data/processed/` contains the dataset used for the statistics and figures reported in the paper. It differs from data/raw/ in exactly three respects: two categorical relabelings and one column rename. No fault outcome, power, temperature, context-switch, duration, or seed value was altered.

| Column | Raw value | Processed value | Reason |
|---|---|---|---|
| `sched_mode` | `pct` | `randomized_yield` | The harness used the internal wrapper name (`pct_wrapper.c`), but the technique is a simple randomized yield injection before `pthread_mutex_lock` (10% probability), not an implementation of formal Probabilistic Concurrency Testing (Burckhardt et al. 2010; Thomson et al. 2016). Renamed to avoid implying that algorithm. `baseline` is unchanged. |
| `perturbation_family` | `randomized_yield` for *all* rows, including `baseline` | `none` for baseline rows; `randomized_yield` for RYI rows | The harness script hardcoded this field for every run regardless of treatment. Baseline runs never set `LD_PRELOAD` and never received the perturbation; corrected to reflect the treatment actually received. |
| `peak_temp_c` (column name) | `peak_temp_c` | `post_run_temp_c` | Renamed to accurately reflect a single post-run temperature reading rather than a continuously monitored peak. Numerical values remain unchanged. |

No other field was changed. Any statistic in the paper can be reproduced from `data/processed/publication_ready_dataset_v2.csv` directly, or audited against `data/raw/` using this table.

Raw per-run run_summary.json files use the harness's original field name peak_temperature_c. This is a single post-run sensors reading, not a continuously sampled peak (see paper, Methodology §B); the paper and data/processed/ consistently refer to this as post-run temperature.

## Data dictionary / changelog — data/processed/publication_ready_dataset_v2.csv

Derived from `publication_ready_dataset.csv` (original harness output). No numeric field (fault outcome, power, temperature, context switches, duration, seed) was altered.
Three changes only: two categorical relabelings and one column rename:

| Column | Old value | New value | Reason |
|---|---|---|---|
| `sched_mode` | `pct` | `randomized_yield` | The original harness label ("pct") referenced the internal wrapper name (`pct_wrapper.c` / `libpct.so`). The actual mechanism is a randomized yield injection before `pthread_mutex_lock` (10% probability), not an implementation of formal Probabilistic Concurrency Testing (Burckhardt et al. 2010; Thomson et al. 2016). The label is renamed to avoid implying that algorithm. `baseline` is unchanged. |
| `perturbation_family` | `randomized_yield` (all rows) | `none` for `sched_mode == baseline`; `randomized_yield` for `sched_mode == randomized_yield` | Original harness script (`run_schema_experiment.sh`) hardcoded this field to `randomized_yield` for every run regardless of treatment. Baseline runs never set `LD_PRELOAD` and never received the perturbation; corrected to reflect actual treatment received. |
| `peak_temp_c` (column name) | `peak_temp_c` | `post_run_temp_c` | The harness recorded a single `sensors` reading taken after each run, not a continuously sampled peak. The column is renamed to match what it measures. Values are numerically unchanged (only trailing zeros differ in formatting, e.g. `76.0` → `76`). |

Raw per-run artifacts (`manifest.json`, `faults.csv`, `run_summary.json`, `application_trace.log` under each run's UUID directory) are preserved unchanged as the original provenance record and are not affected by this relabeling.

### Relationship between the raw files

`data/raw/.../block_01/master_run_summary.csv` is the harness's own consolidated table. It uses the column name `tdp_w` (v2: `configured_power_limit_w`) and does not contain `benchmark`, `device_cpu_model`, `kernel_release`, `thread_count`, `perturbation_family`, or `start_utc`. Those six fields were taken from each run's `manifest.json` (and the constant benchmark name), so `publication_ready_dataset.csv` is a merge of `master_run_summary.csv` and the per-run manifests, not a direct copy of the master summary. For the fields the two files share (`study_id`, `block_id`, `replicate`, `sched_mode`, `seed`, `duration_s`, `any_fault`, `fault_class`, `mean_watt`, `peak_temp_c`, `cswitches`) the values are identical for all 300 runs; the only differences are the renamed power column and the added manifest fields.

## Script changes made after data collection

`scripts/` contains the harness with the edits below. None changes what was measured or how a run executes; items 3–4 concern helper scripts run before/after the experiment. Line-by-line differences: `docs/translation.diff`; SHA-256 hashes of the original files: `docs/ORIGINAL_SHA256.txt`.

1. Comments and console messages translated from Indonesian to English (`run_schema_experiment.sh`, `cpu_melter_bug.c`, `pct_wrapper.c`, `preparation.sh`). Raw `application_trace.log` files remain in Indonesian; `extract_telemetry.py` parses both languages. One trailing comment on the `MODES` line was dropped.
2. `preparation.sh`: a non-functional sysfs fallback (`echo performance > cpu*/cpufreq`) was removed. The glob expands to several paths on a multi-core system, which bash rejects as an ambiguous redirect, so it never took effect; `cpupower frequency-set -g performance` is the mechanism that was in effect.
3. `done.sh` was renamed `restore.sh`. Its final governor command changed from `performance` to `schedutil` (the system default), and stale comments were removed.
4. `build.sh`: unused `mkdir -p bin_svcomp` and progress messages removed; `cd "$(dirname "$0")"` added so it runs from any directory. The two `gcc` commands are unchanged.

### Provenance of the original files
Modification times of the preserved originals: `pct_wrapper.c` 2026-09-11; `cpu_melter_bug.c` 2026-09-14 13:11 +0700; `build.sh` 2026-09-14 11:53; original binaries 2026-09-14 15:55:58 +0700 (08:55:58 UTC, about one minute before the first run), compiled with GCC 16.2.1 20260810 (ELF `.comment`). `run_schema_experiment.sh` (2026-10-05) and `preparation.sh` (2026-09-15) were last modified after data collection; their differences from the current files are limited to comments, console strings and the removed fallback. The harness logic is corroborated by the raw outputs (manifest fields, exit-code classification, `master_run_summary.csv` columns).
