#!/usr/bin/env python3
"""Per-run frequency/power on the ACTIVE-LOAD window + oracle counts.
Run from repository root:  python3 analysis/extract_telemetry.py
Output: analysis/telemetry_per_run.csv
Active window = turbostat summary rows (CPU == '-') with Busy% >= BUSY_MIN.
"""
import csv, glob, os, re, statistics as st
RAW = "data/raw/results/conc15w_v1/block_01"
BUSY_MIN = 50.0
out = []
for d in sorted(glob.glob(f"{RAW}/*/")):
    rid = os.path.basename(d.rstrip("/"))
    hdr, rows = None, []
    for line in open(f"{d}artifacts/turbostat_raw.csv", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if f[0] == "Core": hdr = f; continue
        if hdr and f[0] == "-" and len(f) == len(hdr):
            rows.append(dict(zip(hdr, f)))
    act = [r for r in rows if float(r["Busy%"]) >= BUSY_MIN]
    bz = [float(r["Bzy_MHz"]) for r in act]
    pw = [float(r["PkgWatt"]) for r in act]
    m = re.search(r"(?:Hasil Akhir|Final Results):\s*(\d+)\s*\|\s*(?:Seharusnya|It should be):\s*(\d+)",
                open(f"{d}artifacts/application_trace.log", errors="replace").read())
    final, expected = (int(m[1]), int(m[2])) if m else (None, None)
    out.append(dict(run_id=rid, n_active=len(act),
        bzy_mhz_mean=round(st.mean(bz), 1) if bz else "", bzy_mhz_min=min(bz) if bz else "",
        pkgwatt_active=round(st.mean(pw), 3) if pw else "",
        final=final, expected=expected,
        expected_updates=expected // 10 if expected else "",
        lost_updates=(expected - final) // 10 if m else ""))
with open("analysis/telemetry_per_run.csv", "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(out[0])); w.writeheader(); w.writerows(out)
print(len(out), "runs written")
