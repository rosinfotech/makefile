GLOBAL_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

define resolve_script
$(if $(wildcard $(CURDIR)/.makefile/$(1)),$(CURDIR)/.makefile/$(1),$(if $(wildcard $(CURDIR)/.makefile/vendor/rosinfotech/$(1)),$(CURDIR)/.makefile/vendor/rosinfotech/$(1),$(GLOBAL_ROOT)/.makefile/$(1)))
endef

export FLOW_RELEASE FLOW_YES

.PHONY: clear echo init kill_processes setup version_show version_update vendor git_flow_clear git_flow_commit git_flow_commit_push git_flow_prepare_release git_flow_help git_flow_init git_flow_promote git_flow_status git_flow_seal git_flow_hotfix_finish git_flow_hotfix_start git_flow_task_finish git_flow_task_fragment git_flow_task_merge_develop git_flow_task_start
.SILENT: clear echo init kill_processes setup version_show version_update vendor git_flow_clear git_flow_commit git_flow_commit_push git_flow_prepare_release git_flow_help git_flow_init git_flow_promote git_flow_status git_flow_seal git_flow_hotfix_finish git_flow_hotfix_start git_flow_task_finish git_flow_task_fragment git_flow_task_merge_develop git_flow_task_start

.DEFAULT_GOAL := echo

clear: init
	$(call resolve_script,clear.sh)
echo: init
	GLOBAL_ROOT="$(GLOBAL_ROOT)" $(call resolve_script,echo.sh)

init:
	chmod +x $(GLOBAL_ROOT)/.makefile/*.sh $(wildcard $(CURDIR)/.makefile/*.sh $(CURDIR)/.makefile/vendor/rosinfotech/*.sh)

kill_processes: init
	$(call resolve_script,kill_processes.sh)
setup: init
	$(call resolve_script,setup.sh)

version_show: init
	$(call resolve_script,version_show.sh)

version_update: init
	$(call resolve_script,version_update.sh)
vendor: init
	$(call resolve_script,vendor.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_flow_clear: init
	$(call resolve_script,git_flow_clear.sh)

git_flow_commit: init
	$(call resolve_script,git_flow_commit.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_flow_commit_push: init
	$(call resolve_script,git_flow_commit_push.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_flow_prepare_release: init
	$(call resolve_script,git_flow_prepare_release.sh)

git_flow_help: init
	$(call resolve_script,git_flow_help.sh)

git_flow_init: init
	$(call resolve_script,git_flow_init.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_flow_promote: init
	$(call resolve_script,git_flow_promote.sh)

git_flow_status: init
	$(call resolve_script,git_flow_status.sh)

git_flow_seal: init
	$(call resolve_script,git_flow_seal.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_flow_hotfix_finish: init
	$(call resolve_script,git_flow_hotfix_finish.sh)

git_flow_hotfix_start: init
	$(call resolve_script,git_flow_hotfix_start.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_flow_task_finish: init
	$(call resolve_script,git_flow_task_finish.sh)

git_flow_task_fragment: init
	$(call resolve_script,git_flow_task_fragment.sh) "$(filter-out $@,$(MAKECMDGOALS))"

git_flow_task_merge_develop: init
	$(call resolve_script,git_flow_task_merge_develop.sh)

git_flow_task_start: init
	$(call resolve_script,git_flow_task_start.sh) "$(filter-out $@,$(MAKECMDGOALS))"

%:
	@:
