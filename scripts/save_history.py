#!/usr/bin/env python3
"""
Save current eval results to history.json for tracking over time.
"""

import json
from datetime import datetime
from pathlib import Path


def load_json(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def save_json(path: Path, data: dict):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)


def main():
    base = Path(__file__).parent.parent
    benchmarks_dir = base / "benchmarks"
    history_path = base / "results" / "history.json"
    
    # Load current history
    if history_path.exists():
        history = load_json(history_path)
    else:
        history = {"runs": []}
    
    # Score all benchmarks
    details = {}
    total_expected = 0
    total_tp = 0
    total_extra = 0
    total_fp = 0
    
    for benchmark_dir in sorted(benchmarks_dir.iterdir()):
        if not benchmark_dir.is_dir() or benchmark_dir.name.startswith("."):
            continue
            
        expected_path = benchmark_dir / "expected.json"
        results_path = benchmark_dir / "results.json"
        
        if not expected_path.exists() or not results_path.exists():
            continue
        
        expected = load_json(expected_path)
        results = load_json(results_path)
        
        expected_vulns = expected.get("vulnerabilities", [])
        found_vulns = results.get("findings", [])
        
        # Simple matching
        matched = 0
        fp = sum(1 for f in found_vulns if f.get("false_positive", False))
        
        for found in found_vulns:
            if found.get("false_positive"):
                continue
            for exp in expected_vulns:
                if (found.get("category", "").lower() == exp.get("category", "").lower()):
                    matched += 1
                    break
        
        recall = matched / len(expected_vulns) if expected_vulns else 1.0
        extra = len(found_vulns) - matched - fp
        
        details[benchmark_dir.name] = {
            "recall": recall,
            "extra": extra,
            "fp": fp
        }
        
        total_expected += len(expected_vulns)
        total_tp += matched
        total_extra += extra
        total_fp += fp
    
    if total_expected == 0:
        print("No benchmarks with results found.")
        return
    
    overall_recall = total_tp / total_expected
    
    # Determine grade
    if overall_recall >= 1.0 and total_fp == 0:
        grade = "A+"
    elif overall_recall >= 1.0:
        grade = "A"
    elif overall_recall >= 0.8:
        grade = "B"
    elif overall_recall >= 0.6:
        grade = "C"
    else:
        grade = "D"
    
    # Create run entry
    run = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "skillVersion": "0.1.0",
        "benchmarks": len(details),
        "knownVulns": total_expected,
        "recall": overall_recall,
        "extraFindings": total_extra,
        "falsePositives": total_fp,
        "grade": grade,
        "details": details
    }
    
    history["runs"].append(run)
    save_json(history_path, history)
    
    print(f"Saved: {grade} ({overall_recall*100:.0f}% recall, {len(details)} benchmarks)")


if __name__ == "__main__":
    main()
