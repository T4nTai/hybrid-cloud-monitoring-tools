#!/usr/bin/env python3
"""TN4 — Scalability: điểm/giây, %mất dữ liệu, tải InfluxDB theo interval Telegraf."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pandas as pd  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

from common.loaders import raw_dir, out_dir  # noqa: E402
from common import style  # noqa: E402


def main():
    src, dst = raw_dir("tn4"), out_dir("tn4")
    f = src / "levels.csv"
    if not f.exists():
        print("Không có data/raw/tn4/levels.csv — chạy scripts/benchmark/run-tn4.sh trước.")
        return

    df = pd.read_csv(f)
    df["interval_s"] = df["level"].str.rstrip("s").astype(int)
    df["influx_cpu_pct"] = pd.to_numeric(df["influx_cpu_pct"], errors="coerce")
    df["query_ms"] = pd.to_numeric(df["query_ms"], errors="coerce")
    df = df.sort_values("interval_s", ascending=False)  # 30s -> 1s (tải tăng dần)

    print("\n=== TN4 — Scalability pipeline giám sát ===")
    print(df.to_string(index=False))
    df.to_csv(dst / "tn4_summary.csv", index=False)

    # Điểm ghi được vs kỳ vọng
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(df["interval_s"], df["actual_pts"], "o-", color=style.PALETTE[0], label="ghi được /60s")
    ax.plot(df["interval_s"], df["expected_pts"], "s--", color=style.PALETTE[3], label="kỳ vọng /60s")
    ax.set_xlabel("Interval Telegraf (s) — nhỏ hơn = tải cao hơn")
    ax.set_ylabel("Số điểm trong 60s")
    ax.set_title("TN4 — Điểm ghi được vs kỳ vọng")
    ax.invert_xaxis()
    ax.legend()
    style.save(fig, dst / "tn4_points.png")

    # % mất dữ liệu
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(df["interval_s"], df["loss_pct"], "o-", color=style.PALETTE[3])
    ax.set_xlabel("Interval Telegraf (s)")
    ax.set_ylabel("% mất dữ liệu")
    ax.set_title("TN4 — Tỷ lệ mất dữ liệu theo tải")
    ax.invert_xaxis()
    style.save(fig, dst / "tn4_loss.png")

    # CPU InfluxDB
    if df["influx_cpu_pct"].notna().any():
        fig, ax = plt.subplots(figsize=(9, 5))
        ax.plot(df["interval_s"], df["influx_cpu_pct"], "o-", color=style.PALETTE[2])
        ax.set_xlabel("Interval Telegraf (s)")
        ax.set_ylabel("%CPU InfluxDB")
        ax.set_title("TN4 — Tải CPU InfluxDB theo interval")
        ax.invert_xaxis()
        style.save(fig, dst / "tn4_influx_cpu.png")


if __name__ == "__main__":
    main()
