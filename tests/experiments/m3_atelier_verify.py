"""Read-only provenance audit for M3 Atelier (E3.5 / X4). Does not open or rerun an experiment."""
import hashlib
import json
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args])


def sha(value):
    return hashlib.sha256(value.replace(b"\r\n", b"\n")).hexdigest()


revision = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
protocol = "tests/experiments/m3_atelier_preregistro.md"
evaluator = "tests/experiments/m3_atelier_eval.gd"
artifact = "reports/M3_atelie_eval.json"
prereg = "c9a4e31"
result_commit = git("log", "--diff-filter=A", "--format=%H", revision, "--", artifact).decode().splitlines()[-1]
eval_commit = git("log", "--diff-filter=A", "--format=%H", revision, "--", evaluator).decode().splitlines()[-1]
assert result_commit != eval_commit
assert result_commit != git("rev-parse", prereg).decode().strip()
for before, after in [(prereg, eval_commit), (eval_commit, result_commit), (result_commit, revision)]:
    subprocess.check_call(["git", "merge-base", "--is-ancestor", before, after])
original = git("show", f"{prereg}:{protocol}")
for rev in [eval_commit, result_commit, revision]:
    assert git("show", f"{rev}:{protocol}") == original
result = json.loads(git("show", f"{revision}:{artifact}"))
assert result["preregister_sha256"] == sha(original)
assert result["status"] == "complete"
assert result["seeds"] == list(range(118401, 118425))
assert len(result["rows"]) == 24 * 4 * 3
for path, checksum in result["frozen_sha256"].items():
    assert checksum == sha(git("show", f"{result_commit}^:{path}")), path
    assert checksum == sha(git("show", f"{result_commit}:{path}")), path
code = git("show", f"{result_commit}^:{evaluator}").decode()
assert '"status": "opened"' in code and "FileAccess.file_exists(path)" in code and "file.flush()" in code
for seed in result["seeds"]:
    for arm in ["random", "naive", "trained_frozen", "trained_online"]:
        rows = [r for r in result["rows"] if r["seed"] == seed and r["arm"] == arm]
        assert len(rows) == 3
        assert {r["shape"] for r in rows} == {"linha", "circulo", "quadrado"}
        assert all(r["roundtrip"] and r["actions_replay_ok"] and r["no_energy_gain_on_reward"] for r in rows)
print(f"M3 PASS prereg={prereg} evaluator={eval_commit[:7]} result={result_commit[:7]} seeds=24 rows=288")
