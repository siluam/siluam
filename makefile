.RECIPEPREFIX := |
.DEFAULT_GOAL := prepare
.ONESHELL:
.SECONDEXPANSION:
.PHONY: *

mkfilePath := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfileDir := $(dir $(mkfilePath))
mkfileParent := $(abspath $(mkfileDir)/..)
projectName := $(shell basename $(mkfileDir))

define update
git -C $1 add . && nix flake update $1
endef

define updep
$(call update,$(mkfileParent)/$1)
endef

define wildnValue
$(shell echo $2 | cut -d "-" -f$1-)
endef

define wildcardValue
$(call wildnValue,2,$1)
endef

prepare:
|$(call updep,$(mkfileDir))

dry-check-%: prepare
|nix -L --show-trace build --rebuild --dry-run "$(mkfileDir)#checks.x86_64-linux.$(call wildnValue,3,$@)"

dry-check: dry-check-$$(projectName)

check-%: prepare
|nix -L --show-trace build --rebuild "$(mkfileDir)#checks.x86_64-linux.$(call wildcardValue,$@)"

check: check-$$(projectName)

build-%: prepare
|nix -L --show-trace build "$(mkfileDir)#$(call wildcardValue,$@)"

build: build-$$(projectName)