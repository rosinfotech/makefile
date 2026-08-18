GLOBAL_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

define resolve_script
$(if $(wildcard $(CURDIR)/.makefile/$(1)),$(CURDIR)/.makefile/$(1),$(GLOBAL_ROOT)/.makefile/$(1))
endef

.PHONY: clear clone_makefile echo git_commit git_commit_push git_commit_version init kill_processes link local_deploy_remote setup unlink update_version
.SILENT: clear clone_makefile echo git_commit git_commit_push git_commit_version init kill_processes link local_deploy_remote setup unlink update_version

.DEFAULT_GOAL := echo

clear: init
	$(call resolve_script,clear.sh)

clone_makefile:
	$(call resolve_script,clone_makefile.sh)

echo: init
	GLOBAL_ROOT="$(GLOBAL_ROOT)" $(call resolve_script,echo.sh)

git_commit: init
	$(call resolve_script,git_commit.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_push: init
	$(call resolve_script,git_commit_push.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_version: init
	$(call resolve_script,git_commit_version.sh) "$(filter-out $@,$(MAKECMDGOALS))"

init:
	chmod +x $(GLOBAL_ROOT)/.makefile/*.sh $(GLOBAL_ROOT)/.makefile/make $(wildcard $(CURDIR)/.makefile/*.sh $(CURDIR)/.makefile/make)

kill_processes: init
	$(call resolve_script,kill_processes.sh)

link: init
	$(call resolve_script,link.sh)

local_deploy_remote: init
	$(call resolve_script,local_deploy_remote.sh)

setup: init
	$(call resolve_script,setup.sh)

unlink: init
	$(call resolve_script,unlink.sh)

update_version: init
	$(call resolve_script,update_version.sh)

%:
	@:
