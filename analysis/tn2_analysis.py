#!/usr/bin/env python3
"""TN2 — Hồi quy khoảng cách địa lý -> RTT:  RTT = a*km + b."""
import sys
import glob
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
from scipy.stats import linregress  # noqa: E402

from common.loaders import raw_dir, out_dir, ping_stats  # noqa: E402
from common import style  # noqa: E402


def _mean_rtt(pattern):
    vals = []
    for f in glob.glob(pattern):
        s = ping_stats(Path(f).read_text(errors="replace"))
        if s["n"]:
            vals.append(s["mean"])
    if not vals:
        return None, None
    return float(np.mean(vals)), float(np.std(vals, ddof=1) if len(vals) > 1 else 0.0)


def main():
    src, dst = raw_dir("tn2"), out_dir("tn2")
    meta = src / "probes.tsv"
    if not meta.exists():
        print("Không có probes.tsv — chạy scripts/benchmark/run-tn2.sh trước.")
        return

    rows = []
    for line in meta.read_text().splitlines():
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        name, dist, pattern = line.split("\t")
        mean, std = _mean_rtt(pattern)
        if mean is not None:
            rows.append({"probe": name, "distance_km": float(dist),
                         "rtt_mean_ms": mean, "rtt_std_ms": std or 0.0})
    if len(rows) < 2:
        print(f"Chỉ có {len(rows)} điểm đo — cần >=2 để hồi quy. Bổ sung probe (configs/probes.tsv).")
        return

    df = pd.DataFrame(rows).sort_values("distance_km")
    df.to_csv(dst / "tn2_probes.csv", index=False)
    print("\n=== TN2 — RTT theo khoảng cách ===")
    print(df.to_string(index=False))

    x, y = df["distance_km"].to_numpy(), df["rtt_mean_ms"].to_numpy()
    res = linregress(x, y)
    print(f"\nHồi quy: RTT = {res.slope:.5f} * km + {res.intercept:.3f}")
    print(f"  R = {res.rvalue:.4f}  R^2 = {res.rvalue**2:.4f}  p = {res.pvalue:.3g}")
    print(f"  (lý thuyết ~ 0.01 ms/km nếu đường truyền ~ great-circle)")

    xx = np.linspace(x.min(), x.max(), 100)
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.scatter(x, y, color=style.PALETTE[0], zorder=3, label="đo được")
    ax.plot(xx, res.slope * xx + res.intercept, "--", color=style.PALETTE[3],
            label=f"fit: RTT={res.slope:.4f}·km+{res.intercept:.2f}  (R²={res.rvalue**2:.3f})")
    for _, r in df.iterrows():
        ax.annotate(r["probe"], (r["distance_km"], r["rtt_mean_ms"]),
                    textcoords="offset points", xytext=(5, 4), fontsize=9)
    ax.set_xlabel("Khoảng cách (km)")
    ax.set_ylabel("RTT trung bình (ms)")
    ax.set_title("TN2 — Khoảng cách vs RTT")
    ax.legend()
    style.save(fig, dst / "tn2_regression.png")


if __name__ == "__main__":
    main()
