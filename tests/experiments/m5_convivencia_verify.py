"""Read-only historical audit, never runs the X8 evaluator."""
import hashlib
import json
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args])


def blob(revision, path):
    return git("show", f"{revision}:{path}")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def ancestor(older, newer):
    subprocess.run(["git", "merge-base", "--is-ancestor", older, newer], check=True)


def main():
    revision = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
    protocol = "tests/experiments/m5_convivencia_preregistro.md"
    artifact = "reports/M5_convivencia_eval.json"
    data = json.loads(blob(revision, artifact))
    result = git("log", "--diff-filter=A", "--format=%H", revision, "--", artifact).decode().splitlines()[-1]
    freeze, prereg = data["frozen_commit"], data["preregister_commit"]
    assert prereg != freeze and freeze != result
    ancestor(prereg, freeze)
    ancestor(freeze, result)
    ancestor(result, revision)
    original = blob(prereg, protocol)
    for point in (freeze, result, revision):
        assert original == blob(point, protocol), point
    assert sha(original) == data["preregister_sha256"]
    frozen = json.loads(blob(freeze, "tests/experiments/m5_freeze.json"))
    for path, checksum in frozen["files"].items():
        assert sha(blob(freeze, path)) == checksum, path
        assert sha(blob(result, path)) == checksum, path
    assert data["status"] == "complete" and data["failures"] == []
    rows_f7 = data["rows_f7"]
    rows_repro = data["rows_repro"]
    assert len(rows_f7) == 24 * 5
    assert len(rows_repro) == 24
    assert {r["seed"] for r in rows_f7} == set(range(151401, 151425))
    assert {r["seed"] for r in rows_repro} == set(range(151401, 151425))
    assert len(data["checks"]) == 24
    assert {r["seed"] for r in data["checks"]} == set(range(151401, 151425))
    summary = data["summary"]
    assert summary["verdict"] in ("PASS", "PARTIAL", "FAIL")
    print(f"M5 PASS historical prereg={prereg[:7]} freeze={freeze[:7]} result={result[:7]} seeds=24 rows_f7={len(rows_f7)} rows_repro={len(rows_repro)} scientific_verdict={summary['verdict']}")


if __name__ == "__main__":
    main()
