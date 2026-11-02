"""Historical provenance and metrics audit. Never reopens the holdout."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/experiments'))
from p1_metrics import calculate


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def blob(revision, path):
    return git('show', revision + ':' + path)


def sha(value):
    return hashlib.sha256(value).hexdigest()


def main():
    revision = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
    prefix = 'tests/experiments/'
    freeze_raw = blob(revision, prefix + 'p1_freeze.json')
    freeze = json.loads(freeze_raw)
    result = json.loads(blob(revision, prefix + 'p1_holdout.json'))
    marker = json.loads(blob(revision, prefix + 'p1_opened.json'))
    assert marker == json.loads(blob(revision, prefix + 'p1_started.json'))
    engine = freeze['engine_commit']
    prereg = freeze['prereg_commit']
    result_commit = git('log', '--diff-filter=A', '--format=%H', revision, '--', prefix + 'p1_holdout.json').decode().splitlines()[-1]
    assert prereg != engine and engine != marker['head'] and marker['head'] != result_commit
    for before, after in [(prereg, engine), (engine, marker['head']), (marker['head'], result_commit)]:
        subprocess.run(['git', 'merge-base', '--is-ancestor', before, after], cwd=ROOT, check=True)
    assert sha(freeze_raw) == marker['freeze_sha256']
    assert result['freeze'] == freeze
    assert sha(blob(prereg, prefix + 'p1_preregistro.md')) == result['preregister_sha256'] == freeze['preregister_sha256']
    for path, expected in freeze['files_sha256'].items():
        assert sha(blob(engine, path)) == expected, path
        assert sha(blob(result_commit, path)) == expected, 'post-opening mutation: ' + path
    seeds = set(freeze['holdout_seeds'])
    assert len(seeds) >= 24 and not seeds & set(map(int, freeze['historical_seeds']))
    assert not seeds & set(freeze['dev_seeds'])
    assert {row['seed'] for row in result['rows']} == seeds
    assert len(result['rows']) == 24 * 18
    assert all(len([r for r in result['rows'] if r['seed'] == seed and r['phase'] == 'A' and r['arm'] == arm]) == 3 for seed in seeds for arm in ['treinado', 'sem_memoria', 'nao_treinado', 'sistematico', 'oraculo'])
    assert calculate(result) == json.loads(blob(revision, prefix + 'p1_metrics.json'))
    assert sha(blob(revision, prefix + 'p1_preregistro.md')) == freeze['preregister_sha256']
    print('P1 INTEGRITY PASS prereg=' + prereg[:7] + ' freeze=' + engine[:7] + ' result=' + result_commit[:7] + ' seeds=24 verdict=' + calculate(result)['verdict'])


if __name__ == '__main__':
    main()
