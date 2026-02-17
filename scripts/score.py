#!/usr/bin/env python3
"""
Score evaluation results against expected findings.

Usage:
    python score.py                    # Score all benchmarks
    python score.py benchmarks/euler   # Score single benchmark
"""

import json
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import Optional


@dataclass
class Finding:
    title: str
    severity: str  # critical, high, medium, low, info
    category: str  # reentrancy, access-control, oracle, etc.
    description: str


@dataclass
class BenchmarkResult:
    name: str
    expected_count: int
    found_count: int
    true_positives: int
    false_positives: int
    false_negatives: int
    severity_matches: int
    
    @property
    def recall(self) -> float:
        """% of expected vulns that were found"""
        if self.expected_count == 0:
            return 1.0
        return self.true_positives / self.expected_count
    
    @property
    def precision(self) -> float:
        """% of findings that are true positives"""
        if self.found_count == 0:
            return 1.0
        return self.true_positives / self.found_count
    
    @property
    def f1(self) -> float:
        """Harmonic mean of precision and recall"""
        if self.precision + self.recall == 0:
            return 0
        return 2 * (self.precision * self.recall) / (self.precision + self.recall)


def load_json(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def score_benchmark(benchmark_dir: Path) -> Optional[BenchmarkResult]:
    """Score a single benchmark directory."""
    expected_path = benchmark_dir / "expected.json"
    results_path = benchmark_dir / "results.json"
    
    if not expected_path.exists():
        print(f"Skipping {benchmark_dir.name}: no expected.json")
        return None
    
    if not results_path.exists():
        print(f"Skipping {benchmark_dir.name}: no results.json (run eval first)")
        return None
    
    expected = load_json(expected_path)
    results = load_json(results_path)
    
    expected_vulns = expected.get("vulnerabilities", [])
    found_vulns = results.get("findings", [])
    
    # Match findings to expected vulnerabilities
    matched_expected = set()
    true_positives = 0
    severity_matches = 0
    
    for found in found_vulns:
        for i, exp in enumerate(expected_vulns):
            if i in matched_expected:
                continue
            # Match by category or title similarity
            if (found.get("category", "").lower() == exp.get("category", "").lower() or
                exp.get("title", "").lower() in found.get("title", "").lower()):
                matched_expected.add(i)
                true_positives += 1
                if found.get("severity", "").lower() == exp.get("severity", "").lower():
                    severity_matches += 1
                break
    
    return BenchmarkResult(
        name=benchmark_dir.name,
        expected_count=len(expected_vulns),
        found_count=len(found_vulns),
        true_positives=true_positives,
        false_positives=len(found_vulns) - true_positives,
        false_negatives=len(expected_vulns) - true_positives,
        severity_matches=severity_matches
    )


def main():
    benchmarks_dir = Path(__file__).parent.parent / "benchmarks"
    
    if len(sys.argv) > 1:
        # Score specific benchmark
        benchmark_path = Path(sys.argv[1])
        result = score_benchmark(benchmark_path)
        if result:
            print(f"\n{result.name}:")
            print(f"  Recall: {result.recall:.1%}")
            print(f"  Precision: {result.precision:.1%}")
            print(f"  F1: {result.f1:.1%}")
    else:
        # Score all benchmarks
        results = []
        for benchmark_dir in sorted(benchmarks_dir.iterdir()):
            if benchmark_dir.is_dir() and not benchmark_dir.name.startswith("."):
                result = score_benchmark(benchmark_dir)
                if result:
                    results.append(result)
        
        if not results:
            print("No scored benchmarks found.")
            return
        
        # Summary
        print("\n" + "=" * 60)
        print("EVAL SUMMARY")
        print("=" * 60)
        
        total_expected = sum(r.expected_count for r in results)
        total_tp = sum(r.true_positives for r in results)
        total_found = sum(r.found_count for r in results)
        
        print(f"\nBenchmarks: {len(results)}")
        print(f"Total Expected Vulns: {total_expected}")
        print(f"Total Findings: {total_found}")
        print(f"True Positives: {total_tp}")
        
        overall_recall = total_tp / total_expected if total_expected else 0
        overall_precision = total_tp / total_found if total_found else 0
        
        print(f"\nOverall Recall: {overall_recall:.1%}")
        print(f"Overall Precision: {overall_precision:.1%}")
        
        print("\n" + "-" * 60)
        print(f"{'Benchmark':<25} {'Recall':>10} {'Precision':>10} {'F1':>10}")
        print("-" * 60)
        for r in results:
            print(f"{r.name:<25} {r.recall:>10.1%} {r.precision:>10.1%} {r.f1:>10.1%}")


if __name__ == "__main__":
    main()
