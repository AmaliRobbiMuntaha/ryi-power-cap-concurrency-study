# Data dictionary / changelog — publication_ready_dataset_v2.csv

Derived from `publication_ready_dataset.csv` (original harness output). No
numeric field (fault outcome, power, temperature, context switches,
duration, seed) was altered. Two categorical relabeling changes only:

| Column | Old value | New value | Reason |
|---|---|---|---|
| `sched_mode` | `pct` | `randomized_yield` | The original harness label ("pct") referenced the internal wrapper name (`pct_wrapper.c` / `libpct.so`). The actual mechanism is a randomized yield injection before `pthread_mutex_lock` (10% probability), not an implementation of formal Probabilistic Concurrency Testing (Burckhardt et al. 2010; Thomson et al. 2016). The label is renamed to avoid implying that algorithm. `baseline` is unchanged. |
| `perturbation_family` | `randomized_yield` (all rows) | `none` for `sched_mode == baseline`; `randomized_yield` for `sched_mode == randomized_yield` | Original harness script (`run_schema_experiment.sh`) hardcoded this field to `randomized_yield` for every run regardless of treatment. Baseline runs never set `LD_PRELOAD` and never received the perturbation; corrected to reflect actual treatment received. |

Raw per-run artifacts (`manifest.json`, `faults.csv`, `run_summary.json`,
`application_trace.log` under each run's UUID directory) are preserved
unchanged as the original provenance record and are not affected by this
relabeling.
