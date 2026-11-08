#!/usr/bin/env python3
"""TN1 — RTT / loss / jitter theo điểm đo + throughput iperf3 + self-interference."""
import sys
import glob
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

from common.loaders import raw_dir, out_dir, ping_stats, parse_iperf_json, trim_outliers  # noqa: E402
from common import style  # noqa: E402

POINTS = {
    "p1-vpn-vma-vmb": "P1 on-prem→VM-B (VPN)",
    "p2-vma-central": "P2 on-prem→Central",
    "p3-vmb-central": "P3 VM-B→Central",
    "p4-public-vma-vmb": "P4 on-prem→VM-B (Internet)",
}


def _run_stats(pattern):
    rows = []
    for f in sorted(glob.glob(pattern)):
        s = ping_stats(Path(f).read_text(errors="replace"))
        if s["n"]:
            rows.append({"run": Path(f).stem, **s})
    return rows


def main():
    src, dst = raw_dir("tn1"), out_dir("tn1")

    rows = []
    for key, label in POINTS.items():
        for r in _run_stats(str(src / f"{key}-run*.txt")):
            rows.append({"point": label, **r})
    if not rows:
        print("Không có dữ liệu TN1 — chạy scripts/benchmark/run-tn1.sh trước.")
    else:
        df = pd.DataFrame(rows)
        df.to_csv(dst / "tn1_runs.csv", index=False)
        agg = []
        for label, g in df.groupby("point"):
            m = trim_outliers(g["mean"].to_numpy())
            agg.append({
                "point": label,
                "rtt_mean": round(float(m.mean()), 3),
                "rtt_std": round(float(m.std(ddof=1)) if m.size > 1 else 0.0, 3),
                "n_runs": int(m.size),
                "p50": round(float(g["p50"].mean()), 3),
                "p95": round(float(g["p95"].mean()), 3),
                "p99": round(float(g["p99"].mean()), 3),
                "loss": round(float(g["loss_pct"].mean()), 3),
            })
        agg = pd.DataFrame(agg).sort_values("point")
        print("\n=== TN1 — RTT/loss theo điểm đo (ms, đã loại outlier) ===")
        print(agg.to_string(index=False))
        agg.to_csv(dst / "tn1_summary.csv", index=False)

        fig, ax = plt.subplots(figsize=(9, 5))
        ax.barh(agg["point"], agg["rtt_mean"], xerr=agg["rtt_std"],
                color=style.PALETTE[: len(agg)])
        ax.set_xlabel("RTT trung bình (ms)")
        ax.set_title("TN1 — RTT trung bình theo điểm đo")
        style.save(fig, dst / "tn1_rtt.png")

    ip = sorted(glob.glob(str(src / "iperf3-vpn-run*.json")))
    if ip:
        mbps = [parse_iperf_json(f)["mbps"] for f in ip]
        print(f"\niperf3 VPN (on-prem→VM-B): {sum(mbps)/len(mbps):.1f} Mbps (n={len(mbps)})")
        pd.DataFrame({"run": range(1, len(mbps) + 1), "mbps": mbps}).to_csv(
            dst / "tn1_iperf.csv", index=False)

    # --- Self-interference: Telegraf ON vs OFF ---
    def _mean(pattern):
        vals = []
        for f in sorted(glob.glob(pattern)):
            s = ping_stats(Path(f).read_text(errors="replace"))
            if s["n"]:
                vals.append(s["mean"])
        return float(np.mean(vals)) if vals else None

    interfer = []
    for tag, label in [("p1-vmb", "→ VM-B (VPN)"), ("p2-central", "→ Central")]:
        on = _mean(str(src / f"interference-on-{tag}-run*.txt"))
        off = _mean(str(src / f"interference-off-{tag}-run*.txt"))
        if on is not None and off is not None:
            interfer.append({"duong": label, "rtt_telegraf_on": round(on, 3),
                             "rtt_telegraf_off": round(off, 3),
                             "chenh_lech_ms": round(on - off, 3)})
    if interfer:
        idf = pd.DataFrame(interfer)
        print("\n=== TN1 — Self-interference (Telegraf ON vs OFF trên on-prem) ===")
        print(idf.to_string(index=False))
        idf.to_csv(dst / "tn1_interference.csv", index=False)


if __name__ == "__main__":
    main()
