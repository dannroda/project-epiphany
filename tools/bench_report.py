"""Tabla del benchmark (15.14): python3 tools/bench_report.py <resultado.json> [otro.json para comparar]."""
import json
import sys


def load(path):
    with open(path) as f:
        return json.load(f)


def row(run):
    if "error" in run:
        return f"{run['case']:<18} {run['variant']:<6} ERROR {run['error']}"
    return (f"{run['case']:<18} {run['variant']:<6} {run['fps']:5.1f} fps  frame p50 {run['frame']['p50']:5.1f} p95 {run['frame']['p95']:5.1f}"
            f"  process {run['process']['avg']:5.1f}  physics {run['physics']['avg']:5.1f}  gpu {run['render_gpu']['avg']:5.1f}"
            f"  cpu-render {run['render_cpu']['avg']:4.1f}  draws {run['draws']['avg']:5.0f}  tris {run['triangles']['avg'] / 1e6:4.2f}M"
            f"  vram {run['video_mb']:4.0f}MB  pss {run.get('pss_mb', 0):5.0f}MB  load {run['load_ms'] / 1000:4.1f}s"
            f"  warmup max {run.get('warmup_max_ms', 0):5.0f}ms")


def main():
    data = load(sys.argv[1])
    info = data["info"]
    print(f"{info['device']} · {info['gpu']} · {info['renderer']} · {info['screen']} · {'debug' if info['debug'] else 'release'} · {info['date']}")
    before = {(r["case"], r["variant"]): r for r in load(sys.argv[2])["runs"]} if len(sys.argv) > 2 else {}
    for run in data["runs"]:
        line = row(run)
        old = before.get((run["case"], run["variant"]))
        if old and "error" not in old and "error" not in run:
            line += f"  ({run['fps'] - old['fps']:+.1f} fps)"
        print(line)
    if "startup" in data:
        print(startup(data["startup"]))


def startup(marks):
    load = marks.get("load", {})
    return (f"arranque  primer cuadro {marks['first_frame_ms'] / 1000:4.1f}s  título {marks['title_ms'] / 1000:4.1f}s"
            f"  continuar→jugable {(marks['playable_ms'] - marks['continue_ms']) / 1000:4.1f}s"
            f" (lectura {load.get('read_ms', 0) / 1000:4.1f} instancia {load.get('instance_ms', 0) / 1000:4.1f} warmup {load.get('warmup_ms', 0) / 1000:4.1f})"
            f"  pipelines {marks['playable_pipelines']}  después max {marks['after_max_ms']:4.0f}ms  pss {marks['pss_mb']:4.0f}MB")


main()
