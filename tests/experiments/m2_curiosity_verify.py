"""Read-only provenance audit. Does not open or rerun an experiment."""
import hashlib
import json
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args])


def sha(value):
    return hashlib.sha256(value.replace(b"\r\n", b"\n")).hexdigest()


revision = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
protocol = "tests/experiments/m2_curiosity_preregistro.md"
evaluator = "tests/experiments/m2_curiosity_eval.gd"
artifact = "reports/M2_curiosidade_eval.json"
prereg = "f1a6349"
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
assert result["seeds"] == list(range(107301, 107325))
assert len(result["rows"]) == 24 * 7 * 6
for path, checksum in result["frozen_sha256"].items():
    assert checksum == sha(git("show", f"{result_commit}^:{path}")), path
    assert checksum == sha(git("show", f"{revision}:{path}")), path
code = git("show", f"{revision}:{evaluator}").decode()
assert '"status": "opened"' in code and "FileAccess.file_exists(path)" in code and "file.flush()" in code
for seed in result["seeds"]:
    for arm in ["full", "no_memory", "no_affect", "no_curiosity", "random", "always", "never"]:
        rows = [r for r in result["rows"] if r["seed"] == seed and r["arm"] == arm]
        assert len(rows) == 6
        histories = [r for r in rows if r["condition"] in ["neutral_history", "adverse_history"]]
        assert histories[0]["initial_body"] == histories[1]["initial_body"]
        assert all(r["roundtrip"] for r in rows)
print(f"M2 PASS prereg={prereg} evaluator={eval_commit[:7]} result={result_commit[:7]} seeds=24 rows=1008")
