"""Freeze and single-opening guard. No old closed evaluator is invoked."""
import argparse
import datetime
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXP = ROOT / 'tests/experiments'
GODOT = r'C:\Users\Yurtachi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def seed_inventory():
    records = {}

    def walk(value, filename, key=''):
        if isinstance(value, dict):
            for k, item in value.items():
                walk(item, filename, k)
        elif isinstance(value, list):
            for item in value:
                walk(item, filename, key)
        elif key in ('seed', 'seeds', 'world_seed'):
            try:
                number = int(value)
                records.setdefault(number, set()).add(filename)
            except (ValueError, TypeError):
                pass

    for path in sorted((ROOT / 'reports').glob('*.json')):
        walk(json.loads(path.read_text(encoding='utf-8-sig')), path.name)
    return {str(k): sorted(v) for k, v in sorted(records.items())}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--freeze', action='store_true')
    parser.add_argument('--holdout', action='store_true')
    args = parser.parse_args()
    assert args.freeze != args.holdout, 'choose --freeze or --holdout'
    assert not git('status', '--porcelain', '--untracked-files=no'), 'commit all tracked changes first'
    if args.freeze:
        assert not (EXP / 'p1_freeze.json').exists(), 'freeze already exists'
        tracked = git('ls-files', 'scripts', 'tests/unit/test_sim_p1.gd', 'tests/experiments/p1*').splitlines()
        files = {p: digest(ROOT / p) for p in tracked if p.endswith(('.gd', '.py', '.md'))}
        inventory = seed_inventory()
        assert not set(range(271401, 271425)) & set(map(int, inventory)), 'holdout seed collision'
        prereg_commit = git('log', '--diff-filter=A', '--format=%H', '--', 'tests/experiments/p1_preregistro.md')
        engine = git('rev-parse', 'HEAD')
        assert prereg_commit != engine
        subprocess.run(['git', 'merge-base', '--is-ancestor', prereg_commit, engine], cwd=ROOT, check=True)
        payload = {'engine_commit': engine, 'prereg_commit': prereg_commit,
                   'preregister_sha256': digest(EXP / 'p1_preregistro.md'),
                   'files_sha256': files, 'historical_seeds': inventory,
                   'dev_seeds': list(range(271101, 271107)), 'holdout_seeds': list(range(271401, 271425))}
        with (EXP / 'p1_freeze.json').open('x', encoding='utf-8') as stream:
            json.dump(payload, stream, indent=2, ensure_ascii=False)
        print('P1 frozen; commit p1_freeze.json after full suite passes, then --holdout')
        return
    freeze = json.loads((EXP / 'p1_freeze.json').read_text(encoding='utf-8'))
    for path, expected in freeze['files_sha256'].items():
        assert digest(ROOT / path) == expected, f'freeze mismatch: {path}'
    assert not (EXP / 'p1_holdout.json').exists(), 'holdout result already exists'
    marker = {'opened_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'head': git('rev-parse', 'HEAD'), 'freeze_sha256': digest(EXP / 'p1_freeze.json')}
    with (EXP / 'p1_opened.json').open('x', encoding='utf-8') as stream:
        json.dump(marker, stream, indent=2)
    command = [GODOT, '--headless', '--path', str(ROOT), '--quit-after', '5', '-s', 'tests/experiments/p1_eval.gd', '--', '--holdout']
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    (EXP / 'p1_holdout_log.txt').write_text(run.stdout + run.stderr, encoding='utf-8')
    print(run.stdout, end='')
    print(run.stderr, end='')
    assert run.returncode == 0 and 'SCRIPT ERROR' not in run.stderr and 'ERROR:' not in run.stderr, 'holdout failed; marker preserved, do not reopen'
    from p1_metrics import calculate
    result = calculate(json.loads((EXP / 'p1_holdout.json').read_text(encoding='utf-8')))
    (EXP / 'p1_metrics.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
    print('P1 verdict:', result['verdict'])


if __name__ == '__main__':
    main()
