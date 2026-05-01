.PHONY: build test clean help \
	aizen-core aizen-dashboard aizen-watch aizen-kanban aizen-orchestrate \
	skill-bridge smoke-test

BOLD := \033[1m
RESET := \033[0m

help: ## Show this help
	@echo "$(BOLD)Aizen Agent - Build System$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BOLD)%-24s$(RESET) %s\n", $$1, $$2}'

build: aizen-core aizen-dashboard aizen-watch aizen-kanban aizen-orchestrate skill-bridge ## Build all services

aizen-core: ## Build agent runtime
	cd aizen-core && zig build -Doptimize=ReleaseSmall

aizen-dashboard: ## Build management hub
	cd aizen-dashboard && zig build -Doptimize=ReleaseSmall

aizen-watch: ## Build observability service
	cd aizen-watch && zig build -Doptimize=ReleaseSmall

aizen-kanban: ## Build task tracker
	cd aizen-kanban && zig build -Doptimize=ReleaseSmall

aizen-orchestrate: ## Build workflow engine
	cd aizen-orchestrate && zig build -Doptimize=ReleaseSmall

skill-bridge: ## Install Python skill bridge
	cd aizen-skill-bridge && pip install -e .

test: ## Run all tests
	cd aizen-core && zig build test --summary all
	cd aizen-watch && zig build test --summary all
	cd aizen-kanban && zig build test --summary all
	cd aizen-orchestrate && zig build test --summary all

clean: ## Clean build artifacts
	cd aizen-core && zig build uninstall 2>/dev/null || true
	cd aizen-dashboard && zig build uninstall 2>/dev/null || true
	cd aizen-watch && zig build uninstall 2>/dev/null || true
	cd aizen-kanban && zig build uninstall 2>/dev/null || true
	cd aizen-orchestrate && zig build uninstall 2>/dev/null || true
	rm -rf zig-cache zig-out

smoke-test: ## Run smoke tests
	bash scripts/smoke-test.sh
