#!/usr/bin/env python3
"""TN4 — So sánh compute (CPU / Memory / I/O) giữa các node."""
import sys
import glob
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pandas as pd  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

from common.loaders import (raw_dir, out_dir, parse_sysbench_cpu,  # noqa: E402
                            parse_sysbench_mem, parse_fio_json, read_text)
from common import style  # noqa: E402


def _collect(node_dir: Path) -> dict:
    rows = []
    for rdir in sorted(glob.glob(str(node_dir / "run*"))):
        rdir = Path(rdir)
        rec = {"run": rdir.name}
        p = rdir / "sysbench-cpu-1t.txt"
        if p.exists():
            rec["cpu1t"] = parse_sysbench_cpu(read_text(p))
        p = rdir / "sysbench-cpu-2t.txt"
        if p.exists():
            rec["cpu2t"] = parse_sysbench_cpu(read_text(p))
        p = rdir / "sysbench-mem.txt"
        if p.exists():
            rec["mem_mib_s"] = parse_sysbench_mem(read_text(p))
        for name, key in [("randread", "fio_rr"), ("randwrite", "fio_rw"), ("seqread", "fio_sr")]:
            p = rdir / f"fio-{name}.json"
            if p.exists():
                try:
                    d = parse_fio_json(p)
                    rec[f"{key}_iops"] = d["iops"]
                    rec[f"{key}_bw"] = d["bw_kib_s"]
                except Exception:
                    pass
        rows.append(rec)
    return pd.DataFrame(rows)


def main():
    src, dst = raw_dir("tn4"), out_dir("tn4")
    nodes = sorted(d.name for d in src.glob("*") if d.is_dir())
    if not nodes:
        print("Không có dữ liệu TN4 — chạy scripts/benchmark/run-tn4.sh trước.")
        return

    frames = []
    for node in nodes:
        df = _collect(src / node)
        if df.empty:
            continue
        df.insert(0, "node", node)
        frames.append(df)
        print(f"\n=== TN4 — {node} (raw per run) ===")
        print(df.to_string(index=False))

    if not frames:
        print("Không parse được dữ liệu.")
        return
    allruns = pd.concat(frames, ignore_index=True)
    allruns.to_csv(dst / "tn4_runs.csv", index=False)
    summary = allruns.groupby("node").mean(numeric_only=True).round(2)
    print("\n=== TN4 — Trung bình theo node ===")
    print(summary.to_string())
    summary.to_csv(dst / "tn4_summary.csv")

    for col, title, ylab in [
        ("cpu1t", "CPU 1 thread", "events/s"),
        ("cpu2t", "CPU 2 threads", "events/s"),
        ("mem_mib_s", "Memory", "MiB/s"),
        ("fio_rr_iops", "FIO randread", "IOPS"),
        ("fio_rw_iops", "FIO randwrite", "IOPS"),
    ]:
        if col not in summary:
            continue
        fig, ax = plt.subplots(figsize=(7, 5))
        ax.bar(summary.index, summary[col], color=style.PALETTE[: len(summary)])
        ax.set_title(f"TN4 — {title}")
        ax.set_ylabel(ylab)
        style.save(fig, dst / f"tn4_{col}.png")


if __name__ == "__main__":
    main()
