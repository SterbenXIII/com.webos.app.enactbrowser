PNPM := pnpm

BROWSER_PKG := com.webos.app.browser
ENACT_DIR := ./samples/enact-based
ENACT_DIST := $(ENACT_DIR)/dist
SIMULATOR_PATH := /opt/webOS_TV_SDK/Simulator/webOS_TV_24_Simulator.app
ARES_LAUNCH := ares-launch
ARES_PACKAGE := ares-package
RM := rm -rf
FIND := find

.PHONY: help init clean transpile build build-dev lint sim pkg

# Default target: print help with colors
help:
	@printf "\033[1;36mUsage:\033[0m make \033[1;33m<target>\033[0m\n\n"
	@printf "\033[1;32mAvailable targets:\033[0m\n"
	@printf "  \033[1;33minit\033[0m       - Clean legacy node_modules/locks and run \033[1;36m$(PNPM) install\033[0m for the workspace\n"
	@printf "  \033[1;33mclean\033[0m      - Remove node_modules, dist, build and lock files across the repo\n"
	@printf "  \033[1;33mtranspile\033[0m - Run transpilation step (required before building library artifacts)\n"
	@printf "  \033[1;33mbuild\033[0m     - Full production build: transpile then run pack-p for the Enact browser package\n"
	@printf "  \033[1;33mbuild-dev\033[0m - Dev build: transpile then run pack for the Enact browser package\n"
	@printf "  \033[1;33mlint\033[0m      - Run lint scripts (in packages that define them)\n"
	@printf "  \033[1;33msim\033[0m       - Launch the produced dist folder in webOS simulator (requires ares tools)\n"
	@printf "  \033[1;33mpkg\033[0m       - Package the built dist into an .ipk using $(ARES_PACKAGE)\n\n"
	@printf "Examples:\n"
	@printf "  \033[1;36mmake init\033[0m\n  \033[1;36mmake build\033[0m\n\n"

# init: fresh install for pnpm workspace
# Remove old node_modules and legacy lock files to avoid conflicts, then install workspace deps.
init:
	@echo "=> Cleaning legacy node_modules and lock files (package-lock.json, npm-shrinkwrap.json, yarn.lock)..."
	@$(FIND) . -name "node_modules" -type d -prune -exec $(RM) {} + || true
	@$(FIND) . -name "package-lock.json" -type f -delete || true
	@$(FIND) . -name "npm-shrinkwrap.json" -type f -delete || true
	@$(FIND) . -name "yarn.lock" -type f -delete || true
	@echo "=> Installing workspace dependencies with $(PNPM)..."
	@$(PNPM) install

# clean: remove build artifacts and generated directories across repository
# Keeps repo clean for CI or development resets.
clean:
	@echo "=> Removing node_modules, dist, build, lib, and typical generated artifacts..."
	@$(FIND) . -name "node_modules" -type d -prune -exec $(RM) {} + || true
	@$(FIND) . -type d \( -name "dist" -o -name "build" -o -name "lib" \) -prune -exec $(RM) {} + || true
	@$(FIND) . -name "npm-shrinkwrap.json" -type f -delete || true
	@$(FIND) . -name "package-lock.json" -type f -delete || true
	@$(FIND) . -name "yarn.lock" -type f -delete || true
	@echo "=> Clean complete."

# transpile: run the repository/library transpiler (Babel)
# This is required before building packages that depend on the compiled lib.
# We run in workspace-root context (-w) to ensure root transpile script executes.
transpile:
	@echo "=> Running transpile step at workspace root (required for library compilation)..."
	@$(PNPM) -w run transpile

# build: production build of the Enact browser sample
# Step 1: transpile root library (prerequisite)
# Step 2: run the Enact pack-p script for the specific package using pnpm filter
# Using --filter ensures only the target package's lifecycle script is executed.
build: transpile
	@echo "=> Building production browser package for '$(BROWSER_PKG)'..."
	@$(PNPM) --filter $(BROWSER_PKG) run pack-p

# build-dev: development build (non-production) of the Enact browser sample
# Same rationale as build, but uses pack (dev) instead of pack-p (prod)
build-dev: transpile
	@echo "=> Building development browser package for '$(BROWSER_PKG)'..."
	@$(PNPM) --filter $(BROWSER_PKG) run pack

# lint: run lint scripts where defined across the workspace
# pnpm -r run lint executes the script only in packages that have it defined.
lint:
	@echo "=> Running linters in workspace packages that define a 'lint' script..."
	@$(PNPM) -r run lint

# sim: launch the built app in the webOS simulator using ares-launch
# Assumes ares-* tools installed globally. Uses the built dist folder (output of make build).
sim:
	@echo "=> Launching app in webOS simulator (requires ares tools)..."
	@if [ ! -d "$(ENACT_DIST)" ]; then echo "ERROR: $(ENACT_DIST) not found. Run 'make build' first."; exit 1; fi
	@echo "Using simulator at $(SIMULATOR_PATH)"
	@$(ARES_LAUNCH) -s "$(SIMULATOR_PATH)" "$(ENACT_DIST)"

# pkg: package the built dist into an .ipk using ares-package
# Creates an installable package from the dist folder produced by the build.
pkg:
	@echo "=> Creating .ipk package from $(ENACT_DIST) (requires ares-package)..."
	@if [ ! -d "$(ENACT_DIST)" ]; then echo "ERROR: $(ENACT_DIST) not found. Run 'make build' first."; exit 1; fi
	@$(ARES_PACKAGE) "$(ENACT_DIST)"
	@echo "=> Packaging complete."
