"""Read-only recomputation of the immutable X5 hypotheses from raw trials."""
import json
import statistics as st
import sys

ARMS = ["random", "naive", "servo_geometrico", "trained_frozen", "trained_online", "oraculo"]
PHASES = ["acquisition", "train_shapes_eval", "holdout_shapes_eval", "unobserved_control_eval", "immediate_memory", "retention_save_load", "retention_2000_ticks"]


def summarize(data):
    result = {}
    for arm in ARMS:
        rows = [r for r in data["rows"] if r["arm"] == arm]
        out = {}
        for phase in PHASES:
            trials = [v for row in rows for v in row[phase]]
            errors = [v["error"] for v in trials]
            q = st.quantiles(errors, n=4, method="inclusive")
            out[phase] = {"n": len(errors), "median": st.median(errors), "iqr": q[2] - q[0], "success_rate": sum(v["success"] for v in trials) / len(trials)}
        out["early_train_error_median"] = st.median(r["early_train_error"] for r in rows)
        out["late_train_error_median"] = st.median(r["late_train_error"] for r in rows)
        out["improvement_median"] = st.median(r["early_train_error"] - r["late_train_error"] for r in rows)
        out["retention_drop_median"] = max(st.median(abs(st.median(v["error"] for v in r[p]) - st.median(v["error"] for v in r["immediate_memory"])) for r in rows) for p in ["retention_save_load", "retention_2000_ticks"])
        out["novel_by_shape"] = {}
        for shape in ["triangulo", "cruz", "zigue_zague"]:
            vals = [v for r in rows for v in r["holdout_shapes_eval"] if v["shape"] == shape]
            out["novel_by_shape"][shape] = {"median": st.median(v["error"] for v in vals), "success_rate": sum(v["success"] for v in vals) / len(vals)}
        result[arm] = out
    hypotheses = {}
    trained = ["trained_frozen", "trained_online"]
    baselines = ["random", "naive", "servo_geometrico"]
    hypotheses["H1"] = all(result[a]["improvement_median"] >= .14 for a in trained)
    hypotheses["H2"] = all(result[a]["train_shapes_eval"]["median"] < .18 and result[a]["train_shapes_eval"]["success_rate"] >= .75 and all(result[b]["train_shapes_eval"]["median"] - result[a]["train_shapes_eval"]["median"] >= .10 for b in baselines) for a in trained)
    hypotheses["H3"] = all(result[a]["holdout_shapes_eval"]["median"] < .20 and result[a]["holdout_shapes_eval"]["success_rate"] >= .70 and all(result[b]["holdout_shapes_eval"]["median"] - result[a]["holdout_shapes_eval"]["median"] >= .08 for b in baselines) for a in trained)
    # H4 is evaluated on all transformed train and novel evaluations together.
    def combined(arm):
        return [v for r in data["rows"] if r["arm"] == arm for p in ["train_shapes_eval", "holdout_shapes_eval"] for v in r[p]]
    servo = st.median(v["error"] for v in combined("servo_geometrico"))
    naive = st.median(v["error"] for v in combined("naive"))
    oracle = combined("oraculo")
    hypotheses["H4"] = .22 <= servo < naive and st.median(v["error"] for v in oracle) < .02 and all(v["success"] for v in oracle)
    f = result["trained_frozen"]
    frozen_rows = [r for r in data["rows"] if r["arm"] == "trained_frozen"]
    hypotheses["H5"] = all(r["roundtrip"] and r["save_version"] == 11 and r["frozen_unchanged"] for r in frozen_rows) and all(f[p]["median"] < .20 for p in ["retention_save_load", "retention_2000_ticks"]) and f["retention_drop_median"] <= .05
    hypotheses["H6"] = all(result[a]["unobserved_control_eval"]["median"] >= .28 and all(not v["has_observed"] and not v["reproduced"] for r in data["rows"] if r["arm"] == a for v in r["unobserved_control_eval"]) for a in trained)
    metabolic = max(v["metabolic_delta"] for r in data["rows"] for p in PHASES for v in r[p])
    hypotheses["H7"] = metabolic == 0 and all(r["deterministic"] for r in data["rows"])
    beats = all(all(result[b]["holdout_shapes_eval"]["median"] > result[a]["holdout_shapes_eval"]["median"] for b in ["naive", "servo_geometrico"]) for a in trained)
    partial_band = all(.50 <= result[a]["holdout_shapes_eval"]["success_rate"] < .70 or .04 <= result["servo_geometrico"]["holdout_shapes_eval"]["median"] - result[a]["holdout_shapes_eval"]["median"] < .08 for a in trained)
    classification = "PASS" if all(hypotheses.values()) else "PARTIAL" if all(hypotheses[h] for h in ["H1", "H2", "H5", "H6", "H7"]) and beats and partial_band else "FAIL"
    return {"classification": classification, "hypotheses": hypotheses, "metabolic_delta_max": metabolic, "arms": result}


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8-sig") as f:
        print(json.dumps(summarize(json.load(f)), indent=2, ensure_ascii=False))
