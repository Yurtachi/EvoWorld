"""X6 read-only metrics and ancestry audit. Never invokes a Godot experiment."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

PROTOCOL = 'tests/experiments/m3c_biblioteca_preregistro.md'
ARTIFACT = 'reports/M3c_biblioteca_eval.json'
ARMS = ['verdadeiro', 'sem_livro', 'enganoso', 'sem_memoria']

def git(*args):
    return subprocess.check_output(['git', *args])

def sha(blob):
    return hashlib.sha256(blob.replace(b'\r\n', b'\n')).hexdigest()

def summarize(data):
    rows = data['rows']
    n = len(rows)
    arms = {name: [next(a for a in r['arms'] if a['arm'] == name) for r in rows] for name in ARMS}
    rates = {name: sum(a['first']['avoided'] for a in values) / n for name, values in arms.items()}
    correction = []
    for a in arms['enganoso']:
        name = 'livro:guia_enganoso'
        before = a['sources_before'].get(name, 0)
        after = a['sources_after'].get(name, 0)
        facts_before = [f for f in a['facts_before'] if f['fonte'] == name + ':1']
        facts_after = [f for f in a['facts_after'] if f['fonte'] == name + ':1']
        delta_fact = facts_before[0]['confianca'] - facts_after[0]['confianca'] if facts_before and facts_after else 0
        correction.append({'source_drop': before-after, 'fact_drop': delta_fact, 'contact': a['first']['contacts'] > 0, 'converged': a['second']['avoided']})
    questions = {}
    for name in ['lacuna', 'conhecido', 'sem_lacuna']:
        qs = [next(q for q in r['questions'] if q['condition'] == name) for r in rows]
        questions[name] = {'seeds_with_question': sum(q['count'] > 0 for q in qs), 'questions': sum(q['count'] for q in qs), 'ticks': n*48, 'maximum_per_seed': max(q['count'] for q in qs)}
    caregiver = [r['caregiver'] for r in rows]
    h = {
        'H-a': rates['verdadeiro'] >= .75 and rates['verdadeiro'] - rates['sem_livro'] >= .5 and all(a['read_ticks'] >= 8 for a in arms['verdadeiro']),
        'H-b': sum(x['contact'] for x in correction)/n >= .75 and sum(x['converged'] and x['source_drop'] >= .25 and x['fact_drop'] >= .25 for x in correction)/n >= .75,
        'H-c': questions['lacuna']['seeds_with_question']/n >= .75 and questions['conhecido']['questions'] == 0 and questions['sem_lacuna']['questions'] == 0 and all(q['maximum_per_seed'] <= 1 for q in questions.values()),
        'H-d': sum(x['accepted'] and x['retained'] and all(f['fonte'] == 'cuidador' and 0 < f['confianca'] < 1 and not f['evidencia'] for f in x.get('facts', [])) for x in caregiver)/n >= .75,
        'H-e': abs(rates['sem_memoria']-rates['sem_livro']) <= .1,
    }
    return {'classification': 'PASS' if all(h.values()) else ('PARTIAL' if sum(h.values()) >= 3 else 'FAIL'), 'hypotheses': h, 'n': n, 'avoidance': rates, 'questions': questions, 'random_questions': {'questions': sum(r['random_questions']['count'] for r in rows), 'seeds_with_question': sum(r['random_questions']['count'] > 0 for r in rows), 'ticks': n*48}, 'correction': correction, 'caregiver_accepted_retained': sum(x['accepted'] and x['retained'] for x in caregiver), 'symbols': {'correct_known': sum(r['symbols']['correct'] for r in rows), 'known_trials': n*2, 'unknown_rejected': sum(r['symbols']['unknown_rejected'] for r in rows), 'unknown_trials': n}}

def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--file':
        data = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8-sig'))
    else:
        rev = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
        data = json.loads(git('show', f'{rev}:{ARTIFACT}'))
        prereg = git('rev-parse', '4eb4050').decode().strip()
        result_commit = git('log', '--diff-filter=A', '--format=%H', rev, '--', ARTIFACT).decode().splitlines()[-1]
        freeze = data['freeze_commit']
        assert len({prereg, freeze, result_commit}) == 3
        for before, after in [(prereg, freeze), (freeze, result_commit), (result_commit, rev)]:
            subprocess.check_call(['git', 'merge-base', '--is-ancestor', before, after])
        protocol = git('show', f'{prereg}:{PROTOCOL}')
        assert sha(protocol) == data['preregister_sha256']
        for ref in [freeze, result_commit, rev]:
            assert git('show', f'{ref}:{PROTOCOL}') == protocol
        for ref in [freeze, result_commit]:
            for path, expected in data['frozen_sha256'].items():
                assert sha(git('show', f'{ref}:{path}')) == expected, (ref, path)
        code = git('show', f'{freeze}:tests/experiments/m3c_biblioteca_eval.gd').decode('utf-8-sig')
        assert '"status": "opened"' in code and 'FileAccess.file_exists(path)' in code and 'file.flush()' in code
        assert code.index('write_result(path, output)') < code.index('for seed_value in seeds:')
        assert data['split'] == 'holdout' and data['seeds'] == list(range(140401,140425))
    assert data['status'] == 'complete' and data['arms'] == ARMS
    assert len(data['rows']) == len(data['seeds'])
    assert [r['seed'] for r in data['rows']] == data['seeds']
    for row in data['rows']:
        assert [a['arm'] for a in row['arms']] == ARMS
        assert len(row['questions']) == 3
        for a in row['arms']:
            assert a['seed'] == row['seed']
            for phase in ['first', 'second']:
                p = a[phase]
                assert len(p['actions']) == 48 and p['contacts'] == p['actions'].count('investigate_object')
                assert p['avoided'] == (p['contacts'] == 0)
                assert p['body_after'][0] <= p['body_before'][0] and p['body_after'][1] <= p['body_before'][1]
    result = summarize(data)
    print('X6 INTEGRITY PASS scientific=' + result['classification'])
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
