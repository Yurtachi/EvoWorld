"""Audit committed protocol/freeze/result ancestry, hashes, partitions and guard.

Git proves artifact ordering, not absence of hidden local executions.
Run after committing the holdout artifacts: python tests/experiments/m2_affect_verify.py
"""
import hashlib
import json
import subprocess

PROTOCOL = "tests/experiments/m2_affect_preregistro.md"
RESULT = "reports/M1b_afeto_eval.json"


def git(*args):
    return subprocess.check_output(["git", *args])


def first_commit(path):
    return git("log", "--all", "--diff-filter=A", "--format=%H", "--", path).decode().splitlines()[-1]


def sha(blob):
    # Godot text reading omits a UTF-8 BOM; normalize Git LF / Windows CRLF.
    return hashlib.sha256(blob.decode("utf-8-sig").replace("\r\n", "\n").encode()).hexdigest()


def main():
    result_commit = first_commit(RESULT)
    protocol_commit = first_commit(PROTOCOL)
    result = json.loads(git("show", f"{result_commit}:{RESULT}"))
    assert result["status"] == "completed" and result["partition"] == "HOLDOUT"
    assert result["seed_start"] == 94831 and result["seeds"] == 20
    assert sha(git("show", f"{protocol_commit}:{PROTOCOL}")) == result["preregister_sha256"]
    assert git("show", f"{result_commit}^:{PROTOCOL}") == git("show", f"{protocol_commit}:{PROTOCOL}")
    subprocess.check_call(["git", "merge-base", "--is-ancestor", protocol_commit, result_commit + "^"])
    for path, expected in result["frozen_files_sha256"].items():
        assert sha(git("show", f"{result_commit}^:{path}")) == expected, path
        assert sha(git("show", f"HEAD:{path}")) == expected, path
    evaluator = git("show", f"{result_commit}^:tests/experiments/m2_affect_eval.gd").decode("utf-8-sig")
    assert 'FileAccess.file_exists(RESULT)' in evaluator and '"status": "opened"' in evaluator
    for group in [result["x1"], result["x2"]]:
        assert {row["seed"] for row in group} == set(range(94831, 94851))
    print("M1b audit PASS: protocol ancestor, frozen hashes, holdout partition, durable guard")
    print("Protocol:", protocol_commit, "Result:", result_commit, "Science:", result["summary"]["scientific_status"])


if __name__ == "__main__":
    main()
