# Fofum Solidity Evals

Evaluation benchmarks for [fofum-solidity-skills](https://github.com/DeFiFoFum/fofum-solidity-skills) audit plugin.

## Latest Results

```
======================================================================
FOFUM SOLIDITY AUDIT SKILL - EVAL RESULTS
======================================================================
Benchmarks evaluated:    22
Known vulnerabilities:   22

✅ RECALL:           100.0% (22/22 known bugs found)
🎁 EXTRA FINDINGS:   19 (found more than expected)
❌ FALSE POSITIVES:  0

📊 OVERALL GRADE:    A+
```

## Benchmarks (22 total)

| Category | Benchmark | Exploit Value | Root Cause |
|----------|-----------|---------------|------------|
| **Reentrancy** | reentrancy-dao | N/A | Classic reentrancy |
| | reentrancy-cream | $130M | Flash loan + reentrancy |
| | reentrancy-curve-readonly | $70M+ | Read-only reentrancy |
| **Flash Loan** | flashloan-beanstalk | $182M | Governance flash loan |
| | flashloan-harvest | $34M | Price manipulation |
| **Oracle** | oracle-mango | $116M | Oracle manipulation |
| | oracle-inverse | $15M | Price oracle attack |
| | oracle-bonq | $120M | Oracle manipulation |
| **Access Control** | access-parity | $30M | Unprotected init |
| | access-ronin | $625M | Compromised validators |
| | access-wintermute | $160M | Vanity address exploit |
| **Logic Bugs** | logic-compound | $80M | Token misconfiguration |
| | logic-level | $1.1M | Claim logic error |
| **Integer/Precision** | integer-uranium | $50M | Balance multiplication bug |
| | integer-value | $7M | Swap calculation error |
| | integer-cover | $4M | Division precision loss |
| **Governance** | governance-build | $470K | Flash loan governance |
| | governance-audius | $6M | Governance takeover |
| **Bridge** | bridge-wormhole | $320M | Missing signer check |
| | bridge-polynetwork | $611M | Cross-chain verification |
| **Other** | euler-2023 | $197M | Donation attack |
| | nomad-2022 | $190M | Improper initialization |

**Total Real-World Exploits Covered: $3.4B+**

## Structure

```
benchmarks/
├── reentrancy-dao/          # Classic DAO reentrancy
│   ├── contracts/           # Vulnerable code
│   ├── expected.json        # Known vulnerability
│   └── results.json         # Skill findings
├── euler-2023/              # $197M exploit
├── access-ronin/            # $625M exploit
└── ... (22 total)

scripts/
├── score.py                 # Calculate accuracy metrics
└── save_history.py          # Record results over time

results/
└── history.json             # Results timeline
```

## Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| **Recall** | % of known vulns found | 100% |
| **Extra Findings** | Additional valid issues discovered | Bonus |
| **False Positives** | Incorrect findings reported | 0 |

### Grading Scale

| Grade | Recall | False Positives |
|-------|--------|-----------------|
| A+ | 100% | 0 |
| A | 95-99% | ≤2 |
| B | 80-94% | ≤5 |
| C | 60-79% | ≤10 |
| F | <60% | >10 |

## Running Evals

```bash
# Score all benchmarks
python scripts/score.py

# Save results to history
python scripts/save_history.py

# Or use make
make score
make history
```

## Data Sources

Vulnerable contracts sourced from:
- [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs) - 300+ Foundry reproductions
- [learn-evm-attacks](https://github.com/coinspect/learn-evm-attacks) - Categorized with diagrams
- Etherscan verified contracts (pre-patch commits)

## Contributing

Add new benchmarks:
1. Create folder in `benchmarks/{category}-{name}/`
2. Add vulnerable contracts to `contracts/`
3. Document expected findings in `expected.json`
4. Run audit and save to `results.json`
5. Submit PR

### expected.json format
```json
{
  "vulnerabilities": [
    {
      "id": "VULN-001",
      "title": "Short description",
      "severity": "Critical|High|Medium|Low",
      "category": "Reentrancy|Oracle|AccessControl|...",
      "description": "What's vulnerable and why"
    }
  ]
}
```

## License

MIT
