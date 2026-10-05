.PHONY: all test report clean help setup

# Run the analyzer on all test logs.
all:
	@echo "Running RISC-V Log Analyzer on all test logs..."
	@for log in test_data/*.log; do \
		echo ""; \
		echo "=== $$log ==="; \
		./scripts/analyze.sh "$$log" || true; \
	done

# Run the analyzer tests and check expected exit codes.
test:
	@echo "Running test suite..."
	@./scripts/analyze.sh test_data/sample_pass.log >/dev/null; \
	if [ $$? -ne 0 ]; then \
		echo "FAIL: sample_pass.log should pass"; \
		exit 1; \
	fi
	@./scripts/analyze.sh test_data/sample_fail.log >/dev/null; \
	if [ $$? -ne 1 ]; then \
		echo "FAIL: sample_fail.log should return exit code 1"; \
		exit 1; \
	fi
	@./scripts/analyze.sh test_data/sample_sim.log >/dev/null; \
	if [ $$? -ne 1 ]; then \
		echo "FAIL: sample_sim.log should return exit code 1"; \
		exit 1; \
	fi
	@echo "All tests passed."

# Generate a combined report.
report:
	@./scripts/generate_report.sh

# Remove generated output files.
clean:
	@echo "Cleaning generated output..."
	@rm -rf output/*
	@echo "Clean complete."

# Check the required environment.
setup:
	@./scripts/setup_env.sh

# Display available Make targets.
help:
	@echo "RISC-V Log Analyzer Make Targets"
	@echo "================================"
	@echo "make all     - Analyze all test logs"
	@echo "make test    - Run the test suite"
	@echo "make report  - Generate a combined report"
	@echo "make clean   - Remove generated output"
	@echo "make setup   - Check required tools"
	@echo "make help    - Show this help message"
