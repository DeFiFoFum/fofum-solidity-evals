.PHONY: help setup score eval clean add-benchmark

# Default target
help:
	@echo "Fofum Solidity Evals"
	@echo "===================="
	@echo ""
	@echo "Usage:"
	@echo "  make setup          Install dependencies"
	@echo "  make score          Score all benchmarks"
	@echo "  make eval NAME=x    Run eval on specific benchmark"
	@echo "  make list           List available benchmarks"
	@echo "  make add NAME=x     Create new benchmark scaffold"
	@echo "  make clean          Remove results files"
	@echo ""

# Install dependencies
setup:
	@echo "Setting up eval environment..."
	pip install -q requests
	@echo "Done!"

# Score all benchmarks
score:
	@python scripts/score.py

# Run eval on specific benchmark
eval:
ifndef NAME
	@echo "Usage: make eval NAME=euler-2023"
	@exit 1
endif
	@echo "Running eval on $(NAME)..."
	@python scripts/score.py benchmarks/$(NAME)

# List available benchmarks
list:
	@echo "Available benchmarks:"
	@echo "---------------------"
	@ls -1 benchmarks/ | grep -v ".gitkeep" | sed 's/^/  /'

# Create new benchmark scaffold
add:
ifndef NAME
	@echo "Usage: make add NAME=nomad-2022"
	@exit 1
endif
	@mkdir -p benchmarks/$(NAME)/contracts
	@echo '{\n  "name": "$(NAME)",\n  "date": "",\n  "loss": "",\n  "chain": "ethereum",\n  "category": "",\n  "vulnerabilities": [\n    {\n      "id": "$(NAME)-01",\n      "title": "",\n      "severity": "critical",\n      "category": "",\n      "description": "",\n      "rootCause": ""\n    }\n  ]\n}' > benchmarks/$(NAME)/expected.json
	@echo "Created benchmarks/$(NAME)/"
	@echo "  - Add contracts to contracts/"
	@echo "  - Fill in expected.json"

# Clean results
clean:
	@find benchmarks -name "results.json" -delete
	@rm -f results/summary.md
	@echo "Cleaned results files"

# Quick stats
stats:
	@echo "Benchmarks: $$(ls -1 benchmarks/ | grep -v ".gitkeep" | wc -l)"
	@echo "With results: $$(find benchmarks -name "results.json" | wc -l)"

# Save current results to history
save:
	@python3 scripts/save_history.py
	@echo "Results saved to results/history.json"

# Show history
history:
	@python3 -c "import json; h=json.load(open('results/history.json')); print('Run History:'); [print(f\"  {r['timestamp'][:10]}: {r['grade']} ({r['recall']*100:.0f}% recall, {r['benchmarks']} benchmarks)\") for r in h['runs']]"
