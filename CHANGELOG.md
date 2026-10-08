# Data dictionary / changelog

`data/raw/` contains the unmodified output of `scripts/run_schema_experiment.sh`:
300 per-run directories (manifest.json, faults.csv, run_summary.json,
application_trace.log) plus the harness's own consolidated
`master_run_summary.csv`, exactly as produced during data collection.

`data/processed/` contains the dataset used for the statistics and figures
reported in the paper. It differs from `data/raw/` in exactly two respects,
both purely categorical relabeling -- **no fault outcome, power, temperature,
context-switch, duration, or seed value was altered.**

| Column | Raw value | Processed value | Reason |
|---|---|---|---|
| `sched_mode` | `pct` | `randomized_yield` | The harness used the internal wrapper name (`pct_wrapper.c`), but the technique is a simple randomized yield injection before `pthread_mutex_lock` (10% probability), not an implementation of formal Probabilistic Concurrency Testing (Burckhardt et al. 2010; Thomson et al. 2016). Renamed to avoid implying that algorithm. `baseline` is unchanged. |
| `perturbation_family` | `randomized_yield` for *all* rows, including `baseline` | `none` for baseline rows; `randomized_yield` for RYI rows | The harness script hardcoded this field for every run regardless of treatment. Baseline runs never set `LD_PRELOAD` and never received the perturbation; corrected to reflect the treatment actually received. |

No other field was changed. Any statistic in the paper can be reproduced
from `data/processed/publication_ready_dataset.csv` directly, or audited
against `data/raw/` using this table.

Raw per-run run_summary.json files use the harness's original field name peak_temperature_c. This is a single post-run sensors reading, not a continuously sampled peak (see paper, Methodology §B); the paper and data/processed/ consistently refer to this as post-run temperature.

NOTE: An earlier manual sysfs fallback (echo performance > cpu*/cpufreq) was removed here. On multi-core systems the glob expands to multiple paths, which bash rejects as an ambiguous redirect; this fallback never executed successfully and had no effect during data collection. `cpupower frequency-set -g performance` above is the sole functioning mechanism.
