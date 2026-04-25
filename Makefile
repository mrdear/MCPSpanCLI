PACKAGE_NAME := MCPSpanCLI
COMMAND_NAME := mcp-span-cli
CONFIG ?= release
BIN_DIR ?= $(HOME)/.local/bin

.PHONY: help build install run uninstall

help:
	@echo "Targets:"
	@echo "  make build                 Build the project in release mode"
	@echo "  make install               Build and install $(COMMAND_NAME) into $(BIN_DIR)"
	@echo "  make run ARGS='...'        Run the CLI through swift run"
	@echo "  make uninstall             Remove the installed binary from $(BIN_DIR)"

build:
	swift build -c $(CONFIG)

install: build
	BIN_PATH="$$(swift build -c $(CONFIG) --show-bin-path)"; \
	mkdir -p "$(BIN_DIR)"; \
	cp "$$BIN_PATH/$(PACKAGE_NAME)" "$(BIN_DIR)/$(COMMAND_NAME)"; \
	chmod +x "$(BIN_DIR)/$(COMMAND_NAME)"; \
	echo "Installed $(COMMAND_NAME) to $(BIN_DIR)/$(COMMAND_NAME)"

run:
	swift run $(PACKAGE_NAME) $(ARGS)

uninstall:
	rm -f "$(BIN_DIR)/$(COMMAND_NAME)"
