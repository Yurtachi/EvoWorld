"""Read-only metrics from recorded P1 trajectories; never executes a simulation."""
import json
import math
import statistics
import sys
from pathlib import Path


def calculate(data):
    groups = {}
    paired = {}
    for row in data['rows']:
        key = row['phase'] + ':' + row['arm']
        groups.setdefault(key, []).append(row)
        paired.setdefault((row['seed'], key), []).append(row['latency'])
    summary = {}
    for key, rows in groups.items():
        summary[key] = {
            'n': len(rows), 'success': statistics.mean(r['success'] for r in rows),
            'latency': statistics.mean(r['latency'] for r in rows),
            'path_ratio': statistics.mean(r['path_ratio'] for r in rows),
            'searches': statistics.mean(r['searches'] for r in rows),
            'failures': statistics.mean(r['failures'] for r in rows),
        }
    baselines = ['sem_memoria', 'nao_treinado', 'sistematico']
    best_success = max(baselines, key=lambda a: summary['A:' + a]['success'])
    best_time = min(baselines, key=lambda a: summary['A:' + a]['latency'])
    trained = summary['A:treinado']
    seeds = sorted({r['seed'] for r in data['rows']})
    wins = losses = ties = 0
    differences = []
    for seed in seeds:
        delta = statistics.mean(paired[seed, 'A:' + best_time]) - statistics.mean(paired[seed, 'A:treinado'])
        differences.append({'seed': seed, 'baseline_minus_trained': delta})
        wins += delta > 0
        losses += delta < 0
        ties += delta == 0
    n = wins + losses
    p = sum(math.comb(n, k) for k in range(wins, n + 1)) / 2 ** n if n else 1.0
    checks = data['checks']
    retention = summary['C:treinado']
    b_rate = statistics.mean(r['B_expectation'] < .25 and r['B_failures'] <= 5 for r in checks)
    d_rate = statistics.mean(r['D_preferred_L2'] for r in checks)
    h = {
        'A_success_margin': trained['success'] >= summary['A:' + best_success]['success'] + .20 - 1e-12,
        'A_latency_margin': trained['latency'] <= .75 * summary['A:' + best_time]['latency'],
        'A_paired_test': p < .05,
        'B_revision': b_rate >= .9,
        'C_retention': retention['success'] >= .95 * trained['success'] and retention['latency'] <= 1.10 * trained['latency'],
        'D_richer': d_rate >= .75,
        'E_coverage': data['coverage']['fraction'] >= .9,
        'E_cpu': data['cpu']['ms_per_tick'] < 2,
        'E_integrity': not data['errors'],
    }
    verdict = 'PASS' if all(h.values()) else ('PARTIAL' if h['E_integrity'] else 'FAIL')
    demonstrated = trained['success'] > summary['A:sistematico']['success'] and trained['latency'] < summary['A:sistematico']['latency']
    return {'verdict': verdict, 'learning_demonstrated_in_scenario': demonstrated,
            'criteria': h, 'summary': summary, 'best_success_baseline': best_success,
            'best_latency_baseline': best_time, 'paired': {'wins': wins, 'losses': losses, 'ties': ties, 'p_one_sided': p, 'differences': differences},
            'B_revision_rate': b_rate, 'B_mean_post_returns': statistics.mean(r['B_returns'] for r in checks),
            'D_preference_rate': d_rate, 'seeds': seeds,
            'oracle_is_ceiling_only': True}


if __name__ == '__main__':
    print(json.dumps(calculate(json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))), indent=2, ensure_ascii=False))
