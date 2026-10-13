# run from repository root
raw <- read.csv("data/raw/results/conc15w_v1/block_01/master_run_summary.csv")
pub <- read.csv("data/processed/publication_ready_dataset.csv")
v2  <- read.csv("data/processed/publication_ready_dataset_v2.csv")

stopifnot(nrow(raw) == 300, nrow(pub) == 300, nrow(v2) == 300,
          setequal(raw$run_id, pub$run_id), setequal(pub$run_id, v2$run_id))

## (A) master_run_summary -> publication_ready_dataset: shared fields identical
a <- merge(raw, pub, by = "run_id", suffixes = c(".m", ".p"))
same <- c("study_id", "block_id", "replicate", "sched_mode", "seed", "duration_s",
          "any_fault", "fault_class", "mean_watt", "peak_temp_c", "cswitches")
for (col in same) stopifnot(identical(a[[paste0(col, ".m")]], a[[paste0(col, ".p")]]) ||
                            isTRUE(all.equal(a[[paste0(col, ".m")]], a[[paste0(col, ".p")]])))
stopifnot(isTRUE(all.equal(a$tdp_w, a$configured_power_limit_w)))      # renamed power column

## (B) publication_ready_dataset -> v2: only 2 relabels + 1 column rename
m <- merge(pub, v2, by = "run_id", suffixes = c(".p", ".v2"))
for (col in c("replicate", "seed", "duration_s", "any_fault", "mean_watt", "cswitches"))
  stopifnot(isTRUE(all.equal(m[[paste0(col, ".p")]], m[[paste0(col, ".v2")]])))
for (col in c("study_id", "block_id", "configured_power_limit_w", "fault_class", "benchmark",
              "device_cpu_model", "kernel_release", "thread_count", "start_utc"))
  stopifnot(identical(as.character(m[[paste0(col, ".p")]]), as.character(m[[paste0(col, ".v2")]])))
stopifnot(isTRUE(all.equal(m$peak_temp_c, m$post_run_temp_c)))          # renamed, same values
stopifnot(all(m$sched_mode.v2 == ifelse(m$sched_mode.p == "pct", "randomized_yield", "baseline")))
stopifnot(all(m$perturbation_family.v2 ==
              ifelse(m$sched_mode.v2 == "baseline", "none", "randomized_yield")))
stopifnot(all(m$perturbation_family.p == "randomized_yield"))           # raw hardcoded value
cat("OK: master -> publication_ready identical on shared fields; publication_ready -> v2",
    "differs only by 2 relabels and 1 column rename\n")
