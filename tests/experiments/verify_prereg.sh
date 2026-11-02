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
