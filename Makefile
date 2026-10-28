# Checks and packaging for every chart under charts/. The GitHub workflows run
# these same targets, so a green `make test` locally is a green CI run.
#
# Tool versions are pinned here and nowhere else; Renovate keeps them current
# (custom manager in renovate.json). Each binary lands in
# .tools/<tool>-<version>/, so a changed pin downloads the new version instead
# of reusing a stale one.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# renovate: datasource=github-releases depName=helm/helm
HELM_VERSION := v4.3.1
# renovate: datasource=github-releases depName=yannh/kubeconform
KUBECONFORM_VERSION := v0.8.0
# renovate: datasource=github-releases depName=helm-unittest/helm-unittest
HELM_UNITTEST_VERSION := v1.2.1

# Every chart is rendered and schema-validated against each of these: the
# minor of the wds18 production cluster and the newest upstream minor.
KUBERNETES_VERSIONS := 1.34.0 1.37.0

# All charts by default; narrow with `make test CHARTS=galaxy-ng`.
CHARTS ?= $(patsubst charts/%/Chart.yaml,%,$(wildcard charts/*/Chart.yaml))
# What check-version compares against.
BASE_REF ?= origin/main
DIST_DIR ?= .dist

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')
# helm-unittest names macOS "macos"
UNITTEST_OS := $(subst darwin,macos,$(OS))

TOOLS_DIR := .tools
HELM := $(CURDIR)/$(TOOLS_DIR)/helm-$(HELM_VERSION)/helm
KUBECONFORM := $(CURDIR)/$(TOOLS_DIR)/kubeconform-$(KUBECONFORM_VERSION)/kubeconform
UNITTEST := $(CURDIR)/$(TOOLS_DIR)/helm-unittest-$(HELM_UNITTEST_VERSION)/untt

export HELM KUBECONFORM UNITTEST KUBERNETES_VERSIONS

.PHONY: help
help: ## Show the targets
	@awk 'BEGIN { FS = ":.*## " } /^[a-z-]+:.*## / { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: tools
tools: $(HELM) $(KUBECONFORM) $(UNITTEST) ## Download the pinned tools into .tools/

$(HELM):
	scripts/install-tool.sh \
	  https://get.helm.sh/helm-$(HELM_VERSION)-$(OS)-$(ARCH).tar.gz \
	  https://get.helm.sh/helm-$(HELM_VERSION)-$(OS)-$(ARCH).tar.gz.sha256sum \
	  $(OS)-$(ARCH)/helm $@

$(KUBECONFORM):
	scripts/install-tool.sh \
	  https://github.com/yannh/kubeconform/releases/download/$(KUBECONFORM_VERSION)/kubeconform-$(OS)-$(ARCH).tar.gz \
	  https://github.com/yannh/kubeconform/releases/download/$(KUBECONFORM_VERSION)/CHECKSUMS \
	  kubeconform $@

$(UNITTEST):
	scripts/install-tool.sh \
	  https://github.com/helm-unittest/helm-unittest/releases/download/$(HELM_UNITTEST_VERSION)/helm-unittest-$(UNITTEST_OS)-$(ARCH)-$(HELM_UNITTEST_VERSION:v%=%).tgz \
	  https://github.com/helm-unittest/helm-unittest/releases/download/$(HELM_UNITTEST_VERSION)/helm-unittest-checksum.sha \
	  untt-$(UNITTEST_OS)-$(ARCH) $@

.PHONY: list
list: ## Print the charts the targets act on
	@printf '%s\n' $(CHARTS)

.PHONY: lint
lint: tools ## Repository conventions + helm lint --strict (default and ci/ values)
	@for c in $(CHARTS); do scripts/chart.sh lint $$c; done

.PHONY: unittest
unittest: tools ## helm-unittest suites in charts/<chart>/tests
	@for c in $(CHARTS); do scripts/chart.sh unittest $$c; done

.PHONY: kubeconform
kubeconform: tools ## Render and validate against the Kubernetes schemas
	@for c in $(CHARTS); do scripts/chart.sh kubeconform $$c; done

.PHONY: test
test: lint unittest kubeconform ## lint + unittest + kubeconform

.PHONY: check-version
check-version: tools ## Changed charts carry a new, unreleased version (against BASE_REF)
	@for c in $(CHARTS); do scripts/chart.sh check-version $$c $(BASE_REF); done

.PHONY: package
package: tools ## Package the charts into .dist/
	@mkdir -p $(DIST_DIR)
	@for c in $(CHARTS); do $(HELM) package charts/$$c -d $(DIST_DIR); done

.PHONY: clean
clean: ## Remove .dist/ (keeps the downloaded tools)
	rm -rf $(DIST_DIR)

# `make -s print-HELM` prints the pinned helm binary (used by release.yml)
.PHONY: print-%
print-%:
	@echo $($*)
