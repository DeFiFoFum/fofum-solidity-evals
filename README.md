# Fofum Solidity Evals

Evaluation benchmarks for [fofum-solidity-skills](https://github.com/DeFiFoFum/fofum-solidity-skills) audit plugin.

## Purpose

Validate the solidity-audit skill against known vulnerabilities:
- Run skill against pre-exploit contract code
- Compare findings to documented root causes
- Track accuracy metrics over time

## Structure

```
benchmarks/
├── euler-2023/              # $197M exploit
│   ├── contracts/           # Vulnerable code (pre-patch)
│   ├── expected.json        # Known vulnerability details
│   └── results.json         # Skill findings
├── nomad-2022/              # $190M exploit
├── ronin-2022/              # $625M exploit
└── ...

scripts/
├── run-eval.py              # Run skill against benchmark
└── score.py                 # Calculate accuracy metrics

results/
└── summary.md               # Overall accuracy report
```

## Metrics

| Metric | Description |
|--------|-------------|
| **Recall** | % of known vulns found |
| **Precision** | % of findings that are true positives |
| **Severity Accuracy** | % with correct severity rating |
| **Root Cause Match** | Did we identify the actual root cause? |

## Data Sources

Vulnerable contracts sourced from:
- [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs) - 100+ Foundry reproductions
- [learn-evm-attacks](https://github.com/coinspect/learn-evm-attacks) - Categorized with diagrams
- Etherscan verified contracts (pre-patch commits)

## Running Evals

```bash
# Run single benchmark
python scripts/run-eval.py benchmarks/euler-2023/

# Score all benchmarks
python scripts/score.py

# View results
cat results/summary.md
```

## Contributing

Add new benchmarks:
1. Create folder in `benchmarks/`
2. Add vulnerable contracts
3. Document expected findings in `expected.json`
4. Run eval and submit PR

## License

MIT
