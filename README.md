# Fofum Solidity Evals

> **Validation suite for AI-powered smart contract auditing**

This repo tests the [fofum-solidity-skills](https://github.com/DeFiFoFum/fofum-solidity-skills) audit plugin against real-world DeFi exploits to measure accuracy before trusting it on production code.

## Philosophy

**Trust, but verify.** Before using an AI audit tool on your contracts, you should know:
- Does it actually find known vulnerabilities?
- Does it generate false positives that waste your time?
- What types of bugs is it good (or bad) at catching?

This eval suite answers those questions with hard numbers.

## Results

```
======================================================================
FOFUM SOLIDITY AUDIT SKILL - EVAL RESULTS
======================================================================
Benchmarks evaluated:    22
Known vulnerabilities:   22

✅ RECALL:           100.0% (22/22 known bugs found)
🎁 EXTRA FINDINGS:   19 (bonus issues discovered)
❌ FALSE POSITIVES:  0

📊 OVERALL GRADE:    A+
======================================================================
Category             Benchmarks    All Found?
----------------------------------------------------------------------
Reentrancy           3             ✅
Flash Loan           3             ✅
Oracle/Price         3             ✅
Access Control       3             ✅
Logic Bugs           2             ✅
Integer/Precision    3             ✅
Governance           2             ✅
Bridge               3             ✅
======================================================================
```

## Quick Start

```bash
# Clone this repo
git clone https://github.com/DeFiFoFum/fofum-solidity-evals.git
cd fofum-solidity-evals

# Score all benchmarks
python scripts/score.py

# Save results to history
python scripts/save_history.py
```

## Methodology

### What We Test

Each benchmark contains:
1. **Vulnerable code** — Simplified version of the exploited contract
2. **Expected findings** — The known vulnerability that led to the exploit
3. **Audit results** — What the skill actually found

### How We Score

| Metric | What It Measures | Why It Matters |
|--------|-----------------|----------------|
| **Recall** | % of known vulns found | Primary metric — did we catch the bug? |
| **Extra Findings** | Valid issues beyond known vuln | Bonus — finding more is good |
| **False Positives** | Incorrect findings | Bad — wastes reviewer time |

### Grading Scale

| Grade | Recall | False Positives |
|-------|--------|-----------------|
| A+ | 100% | 0 |
| A | 95-99% | ≤2 |
| B | 80-94% | ≤5 |
| C | 60-79% | ≤10 |
| F | <60% | >10 |

## Benchmarks (22 total)

Covering **$3.4B+ in real-world exploits**:

| Category | Benchmark | Loss | Root Cause |
|----------|-----------|------|------------|
| **Reentrancy** | reentrancy-dao | — | Classic reentrancy |
| | reentrancy-cream | $130M | Flash loan + reentrancy |
| | reentrancy-curve-readonly | $70M+ | Read-only reentrancy |
| **Flash Loan** | flashloan-beanstalk | $182M | Governance flash loan |
| | flashloan-harvest | $34M | Price manipulation |
| | euler-2023 | $197M | Donation attack |
| **Oracle** | oracle-mango | $116M | Oracle manipulation |
| | oracle-inverse | $15M | Price oracle attack |
| | oracle-bonq | $120M | Oracle manipulation |
| **Access Control** | access-parity | $30M | Unprotected init |
| | access-ronin | $625M | Compromised validators |
| | access-wintermute | $160M | Vanity address exploit |
| **Logic Bugs** | logic-compound | $80M | Token misconfiguration |
| | logic-level | $1.1M | Claim logic error |
| **Integer** | integer-uranium | $50M | Balance multiplication |
| | integer-value | $7M | Swap calculation error |
| | integer-cover | $4M | Division precision loss |
| **Governance** | governance-build | $470K | Flash loan governance |
| | governance-audius | $6M | Governance takeover |
| **Bridge** | bridge-wormhole | $320M | Missing signer check |
| | bridge-polynetwork | $611M | Cross-chain verification |
| | nomad-2022 | $190M | Improper initialization |

## Structure

```
benchmarks/
├── reentrancy-dao/
│   ├── contracts/           # Vulnerable Solidity code
│   ├── expected.json        # Known vulnerability
│   └── results.json         # Audit findings
└── ... (22 benchmarks)

scripts/
├── score.py                 # Calculate metrics
└── save_history.py          # Track results over time

results/
└── history.json             # Results timeline
```

## Data Sources

Vulnerable contracts sourced from:
- [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs) — 300+ Foundry reproductions
- [learn-evm-attacks](https://github.com/coinspect/learn-evm-attacks) — Categorized with diagrams
- Etherscan verified contracts (pre-patch commits)

## Contributing

Add new benchmarks:

1. Create `benchmarks/{category}-{name}/`
2. Add vulnerable code to `contracts/`
3. Document expected findings in `expected.json`:
```json
{
  "vulnerabilities": [{
    "id": "VULN-001",
    "title": "Brief description",
    "severity": "Critical",
    "category": "Reentrancy",
    "description": "What's vulnerable and why"
  }]
}
```
4. Run audit, save to `results.json`
5. Submit PR

## License

MIT
