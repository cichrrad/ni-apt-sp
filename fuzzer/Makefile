BUNDLE = bundle
RUBY = setarch $(uname -m) -R ruby
RSPEC = setarch $(uname -m) -R $(BUNDLE) exec rspec
FUZZER_BINARY = bin/fuzzer

# test binaries
BIN_DIR = target_programs/binary
SRC_DIR = target_programs/src

.PHONY: build
build:
	@echo "Running bundle install"
	@$(BUNDLE) install
	@chmod +x $(FUZZER_BINARY)
	@echo "Compiling test targets in $(SRC_DIR) -> $(BIN_DIR)..."
	@mkdir -p $(BIN_DIR)
	@for file in $(SRC_DIR)/*.c; do \
		cc -O0 -g -fsanitize=address -fno-omit-frame-pointer "$$file" -o "$(BIN_DIR)/$$(basename "$$file" .c)"; \
	done
	@echo "Build complete."

.PHONY: test
test:
	@echo "Compiling test targets in $(SRC_DIR) -> $(BIN_DIR)..."
	@mkdir -p $(BIN_DIR)
	@for file in $(SRC_DIR)/*.c; do \
		cc -O0 -g -fsanitize=address -fno-omit-frame-pointer "$$file" -o "$(BIN_DIR)/$$(basename "$$file" .c)"; \
	done
	@$(RSPEC)
	@echo "--- Generating coverage.txt ---"
	@$(RUBY) -r json -e "puts (JSON.parse(File.read('coverage/.last_run.json'))['result']['line'])" > coverage.txt

.PHONY: run
run: build
	@$(BUNDLE) exec $(RUBY) $(FUZZER_BINARY)
