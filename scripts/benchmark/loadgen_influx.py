#!/usr/bin/env python3
"""Sinh tải ghi line-protocol vào InfluxDB 1.x để đo capacity.
Chỉ dùng stdlib. Chạy từ máy bất kỳ tới được InfluxDB.

Usage:
  python3 loadgen_influx.py --url http://20.255.72.0:8086 --db monitoring \
      --user admin --password xxx --rate 1000 --duration 30
"""
import argparse
import base64
import sys
import time
import urllib.request


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--db", default="monitoring")
    ap.add_argument("--user", default="admin")
    ap.add_argument("--password", required=True)
    ap.add_argument("--rate", type=int, default=1000, help="điểm/giây mục tiêu")
    ap.add_argument("--duration", type=int, default=30, help="giây")
    ap.add_argument("--measurement", default="tn4load")
    a = ap.parse_args()

    endpoint = f"{a.url.rstrip('/')}/write?db={a.db}&precision=ns"
    auth = "Basic " + base64.b64encode(f"{a.user}:{a.password}".encode()).decode()
    headers = {"Authorization": auth, "Content-Type": "text/plain"}

    sent, errors = 0, 0
    end = time.time() + a.duration
    while time.time() < end:
        ts = int(time.time() * 1e9)
        batch = min(a.rate, 5000)
        # timestamp tăng dần từng điểm để tránh InfluxDB khử trùng lặp (cùng series+time)
        lines = "\n".join(f'{a.measurement},src=gen value=1i {ts + i}' for i in range(batch))
        req = urllib.request.Request(endpoint, data=lines.encode(), headers=headers, method="POST")
        try:
            urllib.request.urlopen(req, timeout=15).read()
            sent += batch
        except Exception:
            errors += 1
        time.sleep(max(0.001, batch / float(a.rate)))

    print(f"sent={sent} errors={errors} rate_target={a.rate} duration={a.duration}")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
