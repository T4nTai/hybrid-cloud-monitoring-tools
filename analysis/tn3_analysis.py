#!/usr/bin/env python3
"""TN3 — Overhead của Telegraf lên throughput (req/s) và p99."""
import sys
import glob
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pandas as pd  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

from common.loaders import raw_dir, out_dir, parse_ab  # noqa: E402
from common import style  # noqa: E402

LEVELS = ["off", "30s", "15s", "5s"]


def main():
    src, dst = raw_dir("tn3"), out_dir("tn3")
    rows = []
    for lvl in LEVELS:
        for f in sorted(glob.glob(str(src / f"{lvl}-run*.txt"))):
            s = parse_ab(Path(f).read_text(errors="replace"))
            if "req_per_s" in s:
                rows.append({"level": lvl, **s})
    if not rows:
        print("Không có dữ liệu TN3 — chạy scripts/benchmark/run-tn3.sh trước.")
        return

    df = pd.DataFrame(rows)
    df.to_csv(dst / "tn3_runs.csv", index=False)
    agg = df.groupby("level").agg(
        req_s=("req_per_s", "mean"), req_s_std=("req_per_s", "std"),
        p50=("p50_ms", "mean"), p95=("p95_ms", "mean"), p99=("p99_ms", "mean"),
        failed=("failed", "mean"),
    ).reindex(LEVELS).round(2)
    print("\n=== TN3 — Throughput theo mức Telegraf ===")
    print(agg.to_string())

    base = agg.loc["off", "req_s"]
    if base and base > 0:
        agg["overhead_pct"] = ((base - agg["req_s"]) / base * 100).round(2)
        print("\nOverhead so với 'off' (%):")
        print(agg["overhead_pct"].to_string())
    agg.to_csv(dst / "tn3_summary.csv")

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(agg.index, agg["req_s"], yerr=agg["req_s_std"].fillna(0),
           color=style.PALETTE[: len(agg)])
    ax.set_xlabel("Interval Telegraf")
    ax.set_ylabel("Requests/giây")
    ax.set_title("TN3 — Throughput nginx theo mức Telegraf")
    style.save(fig, dst / "tn3_reqs.png")


if __name__ == "__main__":
    main()
