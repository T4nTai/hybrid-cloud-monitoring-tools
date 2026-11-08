"""Đọc & parse dữ liệu thô (raw) sinh ra bởi các script scripts/benchmark/run-tn*.sh."""
from __future__ import annotations

import json
import re
from pathlib import Path

import numpy as np


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def raw_dir(tn: str) -> Path:
    return repo_root() / "data" / "raw" / tn


def out_dir(tn: str) -> Path:
    d = repo_root() / "analysis" / "output" / tn
    d.mkdir(parents=True, exist_ok=True)
    return d


def load_config() -> dict:
    """Đọc configs/variables.env thành dict (không cần python-dotenv)."""
    cfg: dict[str, str] = {}
    f = repo_root() / "configs" / "variables.env"
    if f.exists():
        for line in f.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    return cfg


def read_text(path) -> str:
    return Path(path).read_text(encoding="utf-8", errors="replace")


def ping_stats(text: str) -> dict:
    """Thống kê từ output `ping`: per-packet RTT -> mean/std/percentiles + loss."""
    times = [float(x) for x in re.findall(r"time=([0-9.]+)\s*ms", text)]
    m = re.search(r"(\d+) packets transmitted,\s*(\d+)\s+(?:packets\s+)?received", text)
    sent = int(m.group(1)) if m else len(times)
    recv = int(m.group(2)) if m else len(times)
    loss = round(100.0 * (sent - recv) / sent, 2) if sent else 0.0

    out = {"sent": sent, "recv": recv, "loss_pct": loss, "n": len(times)}
    if times:
        a = np.asarray(times, dtype=float)
        out.update(
            mean=float(a.mean()),
            std=float(a.std(ddof=1) if a.size > 1 else 0.0),
            min=float(a.min()),
            max=float(a.max()),
            p50=float(np.percentile(a, 50)),
            p95=float(np.percentile(a, 95)),
            p99=float(np.percentile(a, 99)),
        )
    return out


def parse_ab(text: str) -> dict:
    out: dict[str, float] = {}
    for key, pat, cast in [
        ("req_per_s", r"Requests per second:\s*([0-9.]+)", float),
        ("mean_ms", r"Time per request:\s*([0-9.]+)\s*\[ms\]\s*\(mean\)", float),
        ("failed", r"Failed requests:\s*(\d+)", int),
        ("kbytes_per_s", r"Transfer rate:\s*([0-9.]+)", float),
    ]:
        m = re.search(pat, text)
        if m:
            out[key] = cast(m.group(1))
    # Bảng phân vị của ab: các dòng dạng "  99%     15"
    for m in re.finditer(r"^\s*(\d+)%\s+(\d+)\s*$", text, re.M):
        out[f"p{m.group(1)}_ms"] = int(m.group(2))
    return out


def parse_iperf_json(path) -> dict:
    d = json.loads(read_text(path))
    end = d.get("end", {})
    s = end.get("sum_sent") or end.get("sum") or {}
    bps = s.get("bits_per_second")
    return {"bits_per_second": bps, "mbps": (bps or 0) / 1e6}


def parse_fio_json(path) -> dict:
    d = json.loads(read_text(path))
    job = d["jobs"][0]
    rw = "read" if job.get("read", {}).get("iops") else "write"
    j = job.get(rw, {})
    return {
        "mode": rw,
        "iops": j.get("iops"),
        "bw_kib_s": j.get("bw"),
        "clat_mean_ns": (j.get("clat_ns") or {}).get("mean"),
    }


def parse_sysbench_cpu(text: str):
    m = re.search(r"events per second:\s*([0-9.]+)", text)
    return float(m.group(1)) if m else None


def parse_sysbench_mem(text: str):
    m = re.search(r"([0-9.]+)\s*MiB/sec", text)
    return float(m.group(1)) if m else None


def trim_outliers(values, k: float = 3.0):
    """Loại outlier theo ngưỡng mean ± k*std. Bỏ qua nếu < 4 mẫu hoặc std=0."""
    a = np.asarray([v for v in values if v is not None], dtype=float)
    if a.size < 4:
        return a
    m, s = a.mean(), a.std(ddof=1)
    if s == 0:
        return a
    keep = np.abs(a - m) <= k * s
    return a[keep] if keep.any() else a
