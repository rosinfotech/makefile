GLOBAL_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

define resolve_script
$(if $(wildcard $(CURDIR)/.makefile/$(1)),$(CURDIR)/.makefile/$(1),$(if $(wildcard $(CURDIR)/.makefile/vendor/rosinfotech/$(1)),$(CURDIR)/.makefile/vendor/rosinfotech/$(1),$(GLOBAL_ROOT)/.makefile/$(1)))
endef

.PHONY: clear echo git_commit git_commit_push git_commit_version init kill_processes setup show_version update_version vendor
.SILENT: clear echo git_commit git_commit_push git_commit_version init kill_processes setup show_version update_version vendor

.DEFAULT_GOAL := echo

clear: init
	$(call resolve_script,clear.sh)
echo: init
	GLOBAL_ROOT="$(GLOBAL_ROOT)" $(call resolve_script,echo.sh)

git_commit: init
	$(call resolve_script,git_commit.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_push: init
	$(call resolve_script,git_commit_push.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_version: init
	$(call resolve_script,git_commit_version.sh) "$(filter-out $@,$(MAKECMDGOALS))"

init:
	chmod +x $(GLOBAL_ROOT)/.makefile/*.sh $(wildcard $(CURDIR)/.makefile/*.sh $(CURDIR)/.makefile/vendor/rosinfotech/*.sh)

kill_processes: init
	$(call resolve_script,kill_processes.sh)
setup: init
	$(call resolve_script,setup.sh)

show_version: init
	$(call resolve_script,version_show.sh)

update_version: init
	$(call resolve_script,version_update.sh)
vendor: init
	$(call resolve_script,vendor.sh) "$(filter-out $@,$(MAKECMDGOALS))"

%:
	@:
