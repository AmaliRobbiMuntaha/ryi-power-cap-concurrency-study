#!/bin/bash
set -uo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Run this script with sudo!"
    exit 1
fi

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

BAT_STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1)
# Check the battery status (make sure it is not currently active "Charging")
if [ -n "$BAT_STATUS" ]; then
    if [ "$BAT_STATUS" = "Discharging" ]; then
        fail "Charger plug-in needed! Device must run on AC power to maintain stable TDP profiles."
    elif [ "$BAT_STATUS" = "Charging" ]; then
        fail "The battery is in active 'Charging' mode. This produces parasitic heat which damages thermal experiments. Wait until 'Full'/'Not charging' or set charge_control_end_threshold."
    fi
fi

## STUDY IDENTITY (Section 2: Schematic Design)
STUDY_ID="conc15w_v1"
BLOCK_ID="block_01"
BASE_DIR="./results/$STUDY_ID/$BLOCK_ID"

ITERATIONS=50
TDP_LEVELS=(15000 25000 45000)
MODES=("pct" "baseline")
WRAPPER="./libpct.so"
BENCHMARK_NAME="cpu_melter_bug"
TARGET_CMD="./cpu_melter_bug"

mkdir -p "$BASE_DIR"

# Helper Monotonic Clock & Hardware Data
get_mono_ns() { date +%s%N; }
HW_CPU=$(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)
HW_KERNEL=$(uname -r)

## SAFETY TRAP (Prevent Zombie Process when Ctrl+C)
cleanup_on_exit() {
    echo -e "\n[!] the experiment was canceled by the user (ctrl+c). clearing background processes..."
    killall -9 "$BENCHMARK_NAME" 2>/dev/null
    kill -INT "$TURBO_PID" 2>/dev/null
    exit 1
}
trap cleanup_on_exit INT TERM

## MAIN EXPERIMENT LOOP
for TDP in "${TDP_LEVELS[@]}"; do
    ryzenadj --stapm-limit="$TDP" --fast-limit="$TDP" --slow-limit="$TDP" >/dev/null
    TDP_LABEL="${TDP}mW"

    for MODE in "${MODES[@]}"; do
        for i in $(seq 1 "$ITERATIONS"); do
            RUN_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
            RUN_DIR="$BASE_DIR/$RUN_ID"
            mkdir -p "$RUN_DIR/artifacts"

            SEED=$RANDOM
            echo "======================================================"
            echo "[*] Starting RUN: $RUN_ID"
            echo "[*] Configuration: TDP=$TDP_LABEL, Sched=$MODE, Seed=$SEED"

            ## Section 3: IMMUTABLE RUN MANIFEST (manifest.json)
            cat <<EOF >"$RUN_DIR/manifest.json"
{
  "schema_name": "conc15w.run_manifest",
  "schema_version": "1.0.0",
  "study_id": "$STUDY_ID",
  "run_id": "$RUN_ID",
  "block_id": "$BLOCK_ID",
  "replicate_index": $i,
  "planned_start_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "device": {
    "cpu_model": "$HW_CPU",
    "power_limit_w": $(awk "BEGIN {print $TDP / 1000}")
  },
  "software": {
    "kernel_release": "$HW_KERNEL",
    "workload_id": "$BENCHMARK_NAME"
  },
  "experimental_factors": {
    "thread_count": 8,
    "scheduler_policy": "$MODE",
    "perturbation_family": "randomized_yield",
    "schedule_seed": $SEED
  }
}
EOF
            sha256sum "$RUN_DIR/manifest.json" >"$RUN_DIR/checksums.sha256"

            ## TELEMETRY & INSTRUMENTATION PREPARATION
            START_MONO_NS=$(get_mono_ns)

            turbostat -i 0.25 -o "$RUN_DIR/artifacts/turbostat_raw.csv" >/dev/null 2>&1 &
            TURBO_PID=$!
            sleep 0.5

            export PCT_SEED=$SEED
            if [ "$MODE" = "pct" ]; then export LD_PRELOAD="$WRAPPER"; else unset LD_PRELOAD; fi

            ## PRODUCTION EXECUTION
            # 15-second timeout because the program ran for 10 seconds
            timeout 15s perf stat -x, -e context-switches,cpu-cycles -o "$RUN_DIR/artifacts/perf_raw.csv" \
                bash -c "$TARGET_CMD > $RUN_DIR/artifacts/application_trace.log 2>&1"

            EXIT_CODE=$?
            END_MONO_NS=$(get_mono_ns)
            DURATION_S=$(awk "BEGIN {print ($END_MONO_NS - $START_MONO_NS) / 1000000000}")

            unset LD_PRELOAD
            kill -INT "$TURBO_PID" 2>/dev/null
            wait "$TURBO_PID" 2>/dev/null

            # Change sysbench to the correct target
            killall -9 "$BENCHMARK_NAME" 2>/dev/null

            ## SECTION 7: FAULT TABLE (BUG CLASSIFICATION CORRECTIONS)
            FAULT_CLASS="none"
            STATUS="valid"
            ANY_FAULT=0

            if [ "$EXIT_CODE" -eq 124 ]; then
                ANY_FAULT=1
                FAULT_CLASS="deadlock_or_starvation"
                echo -e "    \e[31m-> [ DEADLOCK ]\e[0m (${DURATION_S}s)"
            elif [ "$EXIT_CODE" -eq 134 ]; then
                # THIS IS AN ADDITION TO CAPTURE THE RESULTS OF A BUG IN THE C CODE
                ANY_FAULT=1
                FAULT_CLASS="atomicity_violation"
                echo -e "    \e[31m-> [ BUG (Race Condition) ]\e[0m (${DURATION_S}s)"
            elif [ "$EXIT_CODE" -ne 0 ]; then
                ANY_FAULT=1
                FAULT_CLASS="crash_code_${EXIT_CODE}"
                echo -e "    \e[33m-> [ CRASH ($EXIT_CODE) ]\e[0m (${DURATION_S}s)"
            else
                ANY_FAULT=0
                FAULT_CLASS="none"
                echo -e "    \e[32m-> [ OK ]\e[0m (${DURATION_S}s)"
            fi

            # Write to faults.csv
            echo "run_id,fault_class,status,t_first_candidate_ns,detector" >"$RUN_DIR/faults.csv"
            if [ $ANY_FAULT -eq 1 ]; then
                echo "$RUN_ID,$FAULT_CLASS,confirmed,$END_MONO_NS,exit_monitor" >>"$RUN_DIR/faults.csv"
            fi

            # SECTION 8: RUN SUMMARY TABLE & METRICS
            CSWITCH=$(grep "context-switches" "$RUN_DIR/artifacts/perf_raw.csv" 2>/dev/null | awk -F, '{print $1}')
            CSWITCH=${CSWITCH:-0}

            AVG_WATT=$(awk -F'\t' -v col="PkgWatt" '!idx{for(i=1;i<=NF;i++) if($i==col) idx=i} idx && $idx ~ /^[0-9.]+$/ {sum+=$idx; n++} END{if(n>0) printf "%.3f", sum/n; else print "0"}' "$RUN_DIR/artifacts/turbostat_raw.csv")

            AVG_TMP=$(sensors | awk '/Package id 0:|Tctl:/{gsub(/\+|°C/,"",$2); printf "%.2f", $2; exit}')

            cat <<EOF >"$RUN_DIR/run_summary.json"
{
  "run_id": "$RUN_ID",
  "run_status": "$STATUS",
  "duration_s": $DURATION_S,
  "any_confirmed_fault": $(if [ $ANY_FAULT -eq 1 ]; then echo "true"; else echo "false"; fi),
  "fault_classes": ["$FAULT_CLASS"],
  "mean_package_power_w": $AVG_WATT,
  "peak_temperature_c": $AVG_TMP,
  "context_switch_total": $CSWITCH
}
EOF

            ## MASTER TABLE CONSOLIDATION
            if [ ! -f "$BASE_DIR/master_run_summary.csv" ]; then
                echo "benchmark,run_id,study_id,block_id,replicate,tdp_w,sched_mode,seed,duration_s,any_fault,fault_class,mean_watt,peak_temp_c,cswitches" >"$BASE_DIR/master_run_summary.csv"
            fi
            TDP_W=$(awk "BEGIN {print $TDP / 1000}")
            echo "$BENCHMARK_NAME,$RUN_ID,$STUDY_ID,$BLOCK_ID,$i,$TDP_W,$MODE,$SEED,$DURATION_S,$ANY_FAULT,$FAULT_CLASS,$AVG_WATT,$AVG_TMP,$CSWITCH" >>"$BASE_DIR/master_run_summary.csv"

            ## COOLDOWN
            TARGET_TEMP=55.0
            echo -n "    [*] Cooldown to < ${TARGET_TEMP}°C... "
            while true; do
                CUR_TMP=$(sensors | awk '/Package id 0:|Tctl:/{gsub(/\+|°C/,"",$2); print $2; exit}')
                if [ -z "$CUR_TMP" ]; then
                    sleep 1
                    continue
                fi
                if [ $(echo "$CUR_TMP <= $TARGET_TEMP" | bc -l) -eq 1 ]; then break; fi
                sleep 2
            done
            echo "Done ($CUR_TMP°C)."

        done
    done
done

echo "======================================================"
echo "[+] BLOCK 1 EXPERIMENT COMPLETED"
echo "[+] Results saved to: $BASE_DIR"
