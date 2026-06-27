# Makefile for building sdcv Windows native binary (MinGW64)
# Run inside MSYS2 MinGW64 shell: `make` or `make dist`
# Works both locally and in GitHub Actions (msys2/setup-msys2)

SHELL := /bin/bash
UPSTREAM_REPO := https://github.com/Dushistov/sdcv.git
BUILD_DIR := build
DIST_DIR := dist
SCRIPTS_DIR := scripts

# Default values (can be overridden on command line)
CMAKE_BUILD_TYPE ?= Release
ENABLE_NLS ?= OFF
WITH_READLINE ?= OFF

# Version: lazy (=) so clone runs first, then tag is re-evaluated
# Use --exact-match to only match exact tag, avoiding commit hash suffix
# Fall back to --abbrev=0 which gives the nearest tag without hash
SDCV_VERSION = $(shell \
	git -C upstream-src describe --tags --exact-match 2>/dev/null | sed 's/^v//' || \
	git -C upstream-src describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || \
	git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || \
	echo "unknown")
DIST_NAME = sdcv-windows-x64-$(SDCV_VERSION)
DIST_ZIP = $(DIST_DIR)/$(DIST_NAME).zip

.PHONY: all build dist clean info clone patch

all: dist

# Step 1: Clone upstream source
clone:
	@if [ ! -d upstream-src ]; then \
		echo "==> Cloning upstream sdcv..."; \
		git clone $(UPSTREAM_REPO) upstream-src; \
	fi
	@echo "==> Fetching upstream tags..."
	@git -C upstream-src fetch --tags
	@latest_tag=$$(git -C upstream-src tag --sort=-v:refname | head -1); \
	current_ref=$$(git -C upstream-src rev-parse HEAD); \
	tag_ref=$$(git -C upstream-src rev-parse "$$latest_tag" 2>/dev/null); \
	if [ "$$current_ref" != "$$tag_ref" ]; then \
		echo "==> Checking out latest tag: $$latest_tag"; \
		git -C upstream-src checkout -f "$$latest_tag"; \
		rm -f .patch-applied; \
	else \
		echo "==> Already at latest tag: $$latest_tag"; \
	fi
	@echo "==> Upstream version: $$(git -C upstream-src describe --tags --abbrev=0 | sed 's/^v//')"

# Step 2: Apply Windows compatibility patches
patch: clone
	@if [ ! -f .patch-applied ]; then \
		echo "==> Applying Windows compatibility patches..."; \
		bash $(SCRIPTS_DIR)/fix-win32.sh; \
		touch .patch-applied; \
	else \
		echo "==> Patches already applied, skipping."; \
	fi

# Step 3: Configure with CMake
configure: patch
	@echo "==> Configuring with CMake..."
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake ../upstream-src \
		-G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
		-DENABLE_NLS=$(ENABLE_NLS) \
		-DWITH_READLINE=$(WITH_READLINE) \
		-DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++"

# Step 4: Build
build: configure
	@echo "==> Building sdcv..."
	$(MAKE) -C $(BUILD_DIR) -j$$(nproc)

# Step 5: Package exe + DLLs into a zip
dist: build
	@echo "==> Packaging..."
	@mkdir -p $(DIST_DIR)/$(DIST_NAME)
	@cp $(BUILD_DIR)/sdcv.exe $(DIST_DIR)/$(DIST_NAME)/
	@cp upstream-src/LICENSE $(DIST_DIR)/$(DIST_NAME)/
	@echo "==> Discovering and copying required MinGW DLLs..."
	@copied=; \
	find_dlls() { \
		for dep in $$(objdump -p "$$1" 2>/dev/null | sed -n 's/^\tDLL Name: \(.*\)$$/\1/p'); do \
			case "$$dep" in \
				KERNEL32.dll|msvcrt.dll|ADVAPI32.dll|ole32.dll|SHELL32.dll|USER32.dll|WS2_32.dll|ntdll.dll) continue ;; \
			esac; \
			if echo "$$copied" | grep -qx "$$dep"; then \
				continue; \
			fi; \
			dll_path="$$(find /mingw64/bin -name "$$dep" 2>/dev/null | head -1)"; \
			if [ -n "$$dll_path" ]; then \
				cp "$$dll_path" $(DIST_DIR)/$(DIST_NAME)/; \
				echo "  -> $$dep"; \
				copied="$$copied $$dep"; \
				find_dlls "$$dll_path"; \
			else \
				echo "  -> WARN: $$dep not found"; \
			fi; \
		done; \
	}; \
	find_dlls $(BUILD_DIR)/sdcv.exe
	@echo "==> Creating zip archive..."
	@cd $(DIST_DIR) && zip -r $(DIST_NAME).zip $(DIST_NAME)/
	@echo "==> Done: $(DIST_ZIP)"
	@echo ""
	@echo "==> Package contents:"
	@ls -la $(DIST_DIR)/$(DIST_NAME)/

info:
	@echo "sdcv Windows Build System"
	@echo "=========================="
	@echo "Upstream repo:  $(UPSTREAM_REPO)"
	@echo "Build type:     $(CMAKE_BUILD_TYPE)"
	@echo "ENABLE_NLS:     $(ENABLE_NLS)"
	@echo "WITH_READLINE:  $(WITH_READLINE)"
	@if [ -d upstream-src ]; then \
		echo "Upstream tag:   $(SDCV_VERSION)"; \
	fi
	@echo ""
	@echo "Available targets:"
	@echo "  make       - Full build (same as 'make dist')"
	@echo "  make build - Build only (no packaging)"
	@echo "  make dist  - Build + create zip distribution"
	@echo "  make clean      - Remove build artifacts (keeps upstream-src)"
	@echo "  make distclean  - Remove everything including upstream-src"

clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR) .patch-applied
	@if [ -d upstream-src ]; then \
		echo "==> Restoring upstream source to tag..."; \
		tag=$$(git -C upstream-src tag --sort=-v:refname | head -1); \
		git -C upstream-src checkout -f "$$tag"; \
		git -C upstream-src clean -fd; \
	fi
	@echo "==> Done."

distclean: clean
	@echo "==> Removing upstream source..."
	@rm -rf upstream-src
	@echo "==> Done."
