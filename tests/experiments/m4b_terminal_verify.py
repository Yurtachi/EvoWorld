"""Read-only historical audit, never runs the X7 evaluator."""
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
    protocol = "tests/experiments/m4b_terminal_preregistro.md"
    artifact = "reports/M4b_terminal_eval.json"
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
    frozen = json.loads(blob(freeze, "tests/experiments/m4b_freeze.json"))
    for path, checksum in frozen["files"].items():
        assert sha(blob(freeze, path)) == checksum, path
        # Later integration may evolve production; validate historical result.
        assert sha(blob(result, path)) == checksum, path
    assert data["status"] == "complete" and data["failures"] == []
    rows = data["rows"]
    assert len(rows) == 24 * 5 * 24
    assert {r["seed"] for r in rows} == set(range(154401, 154425))
    assert len({(r["seed"], r["arm"], r["phase"], r["attempt"]) for r in rows}) == len(rows)
    for arm, phases in data["summary"].items():
        if arm not in ("completo", "sem_ensino", "aleatorio", "fixo_servo", "sem_memoria"):
            continue
        for phase, cell in phases.items():
            selected = [r for r in rows if r["arm"] == arm and r["phase"] == phase]
            assert len(selected) == cell["n"]
            assert sum(r["success"] for r in selected) == cell["successes"]
            assert sum(r["error"] != "" for r in selected) == cell["errors"]
    assert len(data["checks"]) == 24
    assert {r["seed"] for r in data["checks"]} == set(range(154401, 154425))
    print(f"M4b PASS historical prereg={prereg[:7]} freeze={freeze[:7]} result={result[:7]} seeds=24 rows={len(rows)} scientific_verdict={data['summary']['verdict']}")


if __name__ == "__main__":
    main()
