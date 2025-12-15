.PHONY: init
.SILENT: init

init:
	chmod +x scripts/*.sh

sync_version: init
	scripts/sync_version.sh

git_commit_push: init
	scripts/git_commit_push.sh "$(filter-out $@,$(MAKECMDGOALS))"

local_deploy_remote: init
	scripts/local_deploy_remote.sh

%:
	@:
