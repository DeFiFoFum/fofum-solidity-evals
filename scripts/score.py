#!/usr/bin/env python3
"""
Score evaluation results against expected findings.

Metrics:
- Recall: Did we find all known vulnerabilities? (most important)
- False Positives: Did we report non-bugs? (bad)
- Extra Findings: Did we find more than expected? (good)

Usage:
    python score.py                    # Score all benchmarks
    python score.py benchmarks/euler   # Score single benchmark
"""

import json
import sys
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class BenchmarkResult:
    name: str
    expected_count: int
    found_count: int
    true_positives: int      # Found AND in expected
    false_positives: int     # Found but NOT a real bug (manually marked)
    false_negatives: int     # In expected but NOT found
    extra_findings: int      # Found, real bug, but not in expected (bonus!)
    severity_matches: int
    
    @property
    def recall(self) -> float:
        """% of expected vulns that were found - PRIMARY METRIC"""
        if self.expected_count == 0:
            return 1.0
        return self.true_positives / self.expected_count
    
    @property
    def false_positive_rate(self) -> float:
        """% of findings that were wrong"""
        if self.found_count == 0:
            return 0.0
        return self.false_positives / self.found_count
    
    @property  
    def grade(self) -> str:
        """Letter grade based on recall"""
        if self.recall >= 1.0 and self.false_positives == 0:
            return "A+"
        elif self.recall >= 1.0:
            return "A"
        elif self.recall >= 0.8:
            return "B"
        elif self.recall >= 0.6:
            return "C"
        elif self.recall >= 0.4:
            return "D"
        else:
            return "F"


def load_json(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def score_benchmark(benchmark_dir: Path) -> Optional[BenchmarkResult]:
    """Score a single benchmark directory."""
    expected_path = benchmark_dir / "expected.json"
    results_path = benchmark_dir / "results.json"
    
    if not expected_path.exists():
        print(f"  Skipping {benchmark_dir.name}: no expected.json")
        return None
    
    if not results_path.exists():
        print(f"  Skipping {benchmark_dir.name}: no results.json (run eval first)")
        return None
    
    expected = load_json(expected_path)
    results = load_json(results_path)
    
    expected_vulns = expected.get("vulnerabilities", [])
    found_vulns = results.get("findings", [])
    
    # Match findings to expected vulnerabilities
    matched_expected = set()
    true_positives = 0
    severity_matches = 0
    false_positives = 0
    
    for found in found_vulns:
        # Check if marked as false positive
        if found.get("false_positive", False):
            false_positives += 1
            continue
            
        matched = False
        for i, exp in enumerate(expected_vulns):
            if i in matched_expected:
                continue
            # Match by category or title similarity
            if (found.get("category", "").lower() == exp.get("category", "").lower() or
                exp.get("title", "").lower() in found.get("title", "").lower() or
                found.get("title", "").lower() in exp.get("title", "").lower()):
                matched_expected.add(i)
                true_positives += 1
                matched = True
                if found.get("severity", "").lower() == exp.get("severity", "").lower():
                    severity_matches += 1
                break
    
    # Extra findings = found real bugs not in expected (good!)
    extra_findings = len(found_vulns) - true_positives - false_positives
    
    return BenchmarkResult(
        name=benchmark_dir.name,
        expected_count=len(expected_vulns),
        found_count=len(found_vulns),
        true_positives=true_positives,
        false_positives=false_positives,
        false_negatives=len(expected_vulns) - true_positives,
        extra_findings=extra_findings,
        severity_matches=severity_matches
    )


def main():
    benchmarks_dir = Path(__file__).parent.parent / "benchmarks"
    
    if len(sys.argv) > 1:
        # Score specific benchmark
        benchmark_path = Path(sys.argv[1])
        result = score_benchmark(benchmark_path)
        if result:
            print(f"\n{result.name}: {result.grade}")
            print(f"  Recall: {result.recall:.1%} ({result.true_positives}/{result.expected_count} known bugs found)")
            print(f"  Extra findings: {result.extra_findings} (bonus!)")
            print(f"  False positives: {result.false_positives}")
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
        print("\n" + "=" * 70)
        print("FOFUM SOLIDITY AUDIT SKILL - EVAL RESULTS")
        print("=" * 70)
        
        total_expected = sum(r.expected_count for r in results)
        total_tp = sum(r.true_positives for r in results)
        total_fp = sum(r.false_positives for r in results)
        total_extra = sum(r.extra_findings for r in results)
        
        overall_recall = total_tp / total_expected if total_expected else 0
        
        print(f"\nBenchmarks evaluated: {len(results)}")
        print(f"Known vulnerabilities: {total_expected}")
        print(f"")
        print(f"✅ RECALL: {overall_recall:.1%} ({total_tp}/{total_expected} known bugs found)")
        print(f"🎁 EXTRA FINDINGS: {total_extra} (found more than expected)")
        print(f"❌ FALSE POSITIVES: {total_fp}")
        
        # Overall grade
        if overall_recall >= 1.0 and total_fp == 0:
            grade = "A+"
        elif overall_recall >= 1.0:
            grade = "A"
        elif overall_recall >= 0.8:
            grade = "B"
        else:
            grade = "C"
        
        print(f"\n📊 OVERALL GRADE: {grade}")
        
        print("\n" + "-" * 70)
        print(f"{'Benchmark':<25} {'Grade':>6} {'Recall':>10} {'Extra':>8} {'FP':>6}")
        print("-" * 70)
        for r in results:
            print(f"{r.name:<25} {r.grade:>6} {r.recall:>10.1%} {r.extra_findings:>8} {r.false_positives:>6}")
        
        print("\n" + "=" * 70)
        print("Recall = Found known bugs (most important)")
        print("Extra = Found additional real bugs (good!)")
        print("FP = Reported non-bugs (bad)")
        print("=" * 70)


if __name__ == "__main__":
    main()
