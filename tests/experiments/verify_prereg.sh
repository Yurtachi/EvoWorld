#!/usr/bin/env bash
# Read-only audit; does not run TRAIN/HOLDOUT or modify their artifacts.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
revision=$(git rev-parse --verify --end-of-options "${1:-HEAD}^{commit}")

verify() {
    local gate=$1 prereg=$2 protocol=$3 evaluator=$4 artifact=$5 checksum_key=$6
    local blob eval_commit result_commit eval_blob result_blob current_blob expected recorded
    git merge-base --is-ancestor "$prereg" "$revision"
    blob=$(git rev-parse "$prereg:$protocol")
    eval_commit=$(git log --diff-filter=A --format=%H "$revision" -- "$evaluator" | tail -n 1)
    result_commit=$(git log --diff-filter=A --format=%H "$revision" -- "$artifact" | tail -n 1)
    test -n "$eval_commit"
    test -n "$result_commit"
    # E3 committed the evaluator together with its preregistration. E4 did so
    # afterward. Both must strictly precede the first committed result artifact.
    git merge-base --is-ancestor "$prereg" "$eval_commit"
    test "$prereg" != "$result_commit"
    git merge-base --is-ancestor "$prereg" "$result_commit"
    test "$eval_commit" != "$result_commit"
    git merge-base --is-ancestor "$eval_commit" "$result_commit"
    eval_blob=$(git rev-parse "$eval_commit:$protocol")
    result_blob=$(git rev-parse "$result_commit:$protocol")
    current_blob=$(git rev-parse "$revision:$protocol")
    test "$blob" = "$eval_blob"
    test "$blob" = "$result_blob"
    test "$blob" = "$current_blob"
    expected=$(git cat-file blob "$blob" | sha256sum | cut -d ' ' -f 1)
    recorded=$(git show "$result_commit:$artifact" | awk -F '"' -v key="$checksum_key" '$2 == key {print $4}')
    test "$recorded" = "$expected"
    recorded=$(git show "$revision:$artifact" | awk -F '"' -v key="$checksum_key" '$2 == key {print $4}')
    test "$recorded" = "$expected"
    printf '%s PASS prereg_commit=%s prereg_blob=%s blob_sha256=%s evaluator_commit=%s result_commit=%s\n' \
        "$gate" "$prereg" "$blob" "$expected" "$eval_commit" "$result_commit"
}

trap 'echo "FAIL: commit ancestry, protocol blob, or recorded checksum does not match" >&2' ERR
verify E3 a66ea9c0084f2c3ced6e7c55c127a90266d006fd \
    tests/experiments/ensino_preregistro.md tests/experiments/ensino_eval.gd \
    reports/E3_ensino_eval.json preregistration_sha256
verify E4 ad63789bf26c64e5b829aba76f5c461f75e5a996 \
    tests/experiments/social_preregistro.md tests/experiments/social_eval.gd \
    reports/E4_social_eval.json preregister_sha256
verify M1 c8e9e91159a088558774e353e870a8b47802beea \
    tests/experiments/m1_preregistro.md tests/experiments/m1_eval.gd \
    reports/M1_mind_eval.json preregister_sha256
verify M2 f1a6349 \
    tests/experiments/m2_curiosity_preregistro.md tests/experiments/m2_curiosity_eval.gd \
    reports/M2_curiosidade_eval.json preregister_sha256
python tests/experiments/m2_curiosity_verify.py 49350ea
verify M3 c9a4e31 \
    tests/experiments/m3_atelier_preregistro.md tests/experiments/m3_atelier_eval.gd \
    reports/M3_atelie_eval.json preregister_sha256
python tests/experiments/m3_atelier_verify.py "$revision"
verify M3b 9460b1e \
    tests/experiments/m3b_copia_preregistro.md tests/experiments/m3b_copia_eval.gd \
    reports/M3b_copia_eval.json preregister_sha256
# X5 validates its historical freeze, before later milestones change the engine.
python tests/experiments/m3b_copia_verify.py "$(git log -1 --format=%H "$revision" -- reports/M3b_copia_eval.json)"

verify M3c 4eb4050 \
    tests/experiments/m3c_biblioteca_preregistro.md tests/experiments/m3c_biblioteca_eval.gd \
    reports/M3c_biblioteca_eval.json preregister_sha256
python tests/experiments/m3c_biblioteca_verify.py "$revision"

# X7 is audited at the historical freeze, so later integration stays possible.
# Before its single opening there is deliberately no result artifact to audit.
if git cat-file -e "$revision:reports/M4b_terminal_eval.json" 2>/dev/null; then
    verify M4b d9b57a1 \
        tests/experiments/m4b_terminal_preregistro.md tests/experiments/m4b_terminal_eval.gd \
        reports/M4b_terminal_eval.json preregister_sha256
    python tests/experiments/m4b_terminal_verify.py "$revision"
fi

# P1 has its own immutable freeze and one-opening marker. Read-only audit.
if git cat-file -e "$revision:tests/experiments/p1_holdout.json" 2>/dev/null; then
    python tests/experiments/p1_verify.py "$revision"
fi

if git cat-file -e "$revision:reports/M5_convivencia_eval.json" 2>/dev/null; then
    verify M5 ffe9e14 \
        tests/experiments/m5_convivencia_preregistro.md tests/experiments/m5_convivencia_eval.gd \
        reports/M5_convivencia_eval.json preregister_sha256
    python tests/experiments/m5_convivencia_verify.py "$revision"
fi
