# Benchmark Plan

## Goal
Cover all major exploit categories with 3+ examples each to validate the audit skill.

## Categories (from DeFiHackLabs analysis)

| Category | Available | Target | Current |
|----------|-----------|--------|---------|
| **Reentrancy** | 25 | 3 | 1 (DAO) |
| **Flash Loan** | 290 | 3 | 1 (Euler) |
| **Oracle/Price** | 80 | 3 | 0 |
| **Access Control** | 25 | 3 | 0 |
| **Logic Bugs** | ~100 | 3 | 1 (Nomad) |
| **Integer/Precision** | 18 | 3 | 0 |
| **Governance** | ~20 | 2 | 0 |
| **Bridge/Cross-chain** | ~30 | 2 | 0 |

**Target: 20-25 benchmarks across 8 categories**

---

## Benchmark Selection Criteria

1. **Diverse root causes** - Different patterns within each category
2. **Real money lost** - Actual exploits, not theoretical
3. **Documented** - Post-mortem available
4. **Reproducible** - Can isolate the vulnerable code
5. **Varying difficulty** - Some obvious, some subtle

---

## Selected Benchmarks

### Reentrancy (3)
- [x] `reentrancy-dao` - Classic reentrancy (2016, $60M)
- [ ] `reentrancy-cream` - Cross-contract reentrancy (2021)
- [ ] `reentrancy-readonly` - Read-only reentrancy (Curve)

### Flash Loan (3)
- [x] `euler-2023` - Donate + self-liquidation ($197M)
- [ ] `beanstalk-2022` - Governance flash loan ($182M)
- [ ] `harvest-2020` - Oracle manipulation via flash loan ($34M)

### Oracle/Price Manipulation (3)
- [ ] `mango-2022` - Self-referential oracle ($116M)
- [ ] `inverse-2022` - Short TWAP window ($15M)
- [ ] `bonq-2023` - TellorFlex oracle manipulation ($120M)

### Access Control (3)
- [ ] `parity-2017` - Unprotected initWallet ($150M frozen)
- [ ] `ronin-2022` - Validator key compromise ($625M)
- [ ] `wintermute-2022` - Vanity address exploit ($160M)

### Logic Bugs (3)
- [x] `nomad-2022` - Zero init as valid state ($190M)
- [ ] `compound-2021` - Reward distribution bug ($80M)
- [ ] `level-2023` - Referral double claim ($1M)

### Integer/Precision (3)
- [ ] `uranium-2021` - Fee calculation overflow ($50M)
- [ ] `value-2021` - Price precision loss ($11M)
- [ ] `cover-2020` - Infinite mint ($4M)

### Governance (2)
- [ ] `tornado-2023` - Malicious proposal execution
- [ ] `audius-2022` - Governance initialization ($6M)

### Bridge/Cross-chain (2)
- [ ] `wormhole-2022` - Signature verification ($326M)
- [ ] `polynetwork-2021` - Cross-chain call target ($611M)

---

## Total: 22 benchmarks across 8 categories

## Effort Estimate
- ~2 hours to create all benchmark files
- Each benchmark needs: contracts/, expected.json
- Can automate some extraction from DeFiHackLabs

## Success Criteria
- **Recall ≥ 90%** across all benchmarks
- **False Positive Rate < 20%**
- Coverage of all 8 categories
