.PHONY: build test benchmark run

build:
	@echo "Nothing to build (Ruby)."

test:
	@rm -rf coverage
	@cd tests && ./run_tests.sh
benchmark:
	@cd benchmark && ./autorun_benchmarks.sh

.PHONY: run

run:
	@set -eu; \
	[ -n "$$TARGET_COV" ] || { echo "ERROR: TARGET_COV not set"; exit 2; }; \
	[ -d "$$TARGET_COV" ] || { echo "ERROR: TARGET_COV '$$TARGET_COV' is not a directory"; exit 2; }; \
	OUT=out; \
	rm -rf "$$OUT" && mkdir -p "$$OUT"; \
	./instrument.rb "$$TARGET_COV" "$$OUT"; \
	cp "$${TARGET_COV%/}"/*.h "$$OUT"/ 2>/dev/null || true; \
	cd "$$OUT"; \
	c_files=$$(ls *.c 2>/dev/null || true); \
	[ -n "$$c_files" ] || { echo "ERROR: no .c files found in '$$OUT'"; exit 3; }; \
	gcc -O0 *.c -o program; \
	./program; \
	if [ -f coverage.lcov ]; then cp coverage.lcov ../coverage.lcov; fi; \
	cd ..; \
	[ -f coverage.lcov ] || { echo "WARNING: coverage.lcov not found; did instrument.rb generate it?"; exit 4; }; \
	echo "coverage.lcov written"; \
	cat coverage.lcov
	cp coverage.lcov "${TARGET_COV}".
