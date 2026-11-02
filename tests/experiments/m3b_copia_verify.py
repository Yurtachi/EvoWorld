"""Read-only X5 provenance, coverage and numerical audit; never runs Godot."""
import hashlib
import json
import subprocess
import sys
from m3b_copia_metrics import ARMS, PHASES, summarize


def git(*args):
    return subprocess.check_output(["git", *args])


def sha(blob):
    return hashlib.sha256(blob.replace(b"\r\n", b"\n")).hexdigest()


revision = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
protocol = "tests/experiments/m3b_copia_preregistro.md"
artifact = "reports/M3b_copia_eval.json"
evaluator = "tests/experiments/m3b_copia_eval.gd"
prereg = git("rev-parse", "9460b1e").decode().strip()
result_commit = git("log", "--diff-filter=A", "--format=%H", revision, "--", artifact).decode().splitlines()[-1]
data = json.loads(git("show", f"{revision}:{artifact}"))
freeze = data["freeze_commit"]
assert len({prereg, freeze, result_commit}) == 3
for before, after in [(prereg, freeze), (freeze, result_commit), (result_commit, revision)]:
    subprocess.check_call(["git", "merge-base", "--is-ancestor", before, after])
assert git("show", f"{result_commit}^:{evaluator}") == git("show", f"{freeze}:{evaluator}")
original = git("show", f"{prereg}:{protocol}")
assert data["preregister_sha256"] == sha(original)
for ref in [freeze, result_commit, revision]:
    assert git("show", f"{ref}:{protocol}") == original
    for path, expected in data["frozen_sha256"].items():
        assert sha(git("show", f"{ref}:{path}")) == expected, (ref, path)
assert data["status"] == "complete" and data["split"] == "holdout"
assert data["seeds"] == list(range(129401, 129425)) and data["arms"] == ARMS
assert len(data["rows"]) == 144
for seed in data["seeds"]:
    for arm in ARMS:
        rows = [r for r in data["rows"] if r["seed"] == seed and r["arm"] == arm]
        assert len(rows) == 1
        row = rows[0]
        assert row["roundtrip"] and row["save_version"] == 11 and row["deterministic"] and row["frozen_unchanged"]
        for phase, n in zip(PHASES, [24, 9, 9, 3, 6, 6, 6]):
            assert len(row[phase]) == n
            assert all(v["replay"] and v["metabolic_delta"] == 0 and 0 <= v["error"] <= 1 for v in row[phase])
        assert {v["shape"] for v in row["acquisition"]} == {"linha", "circulo", "quadrado"}
        assert {v["shape"] for v in row["holdout_shapes_eval"]} == {"triangulo", "cruz", "zigue_zague"}
code = git("show", f"{freeze}:{evaluator}").decode()
assert '"status": "opened"' in code and "FileAccess.file_exists(path)" in code and "file.flush()" in code
assert code.index("write_result(path, output)") < code.index("for seed_value in seeds:")
summary = summarize(data)
print(f"X5 INTEGRITY PASS prereg={prereg[:7]} freeze={freeze[:7]} result={result_commit[:7]} seeds=24 rows=144 scientific={summary['classification']}")
print(json.dumps(summary["hypotheses"], sort_keys=True))
