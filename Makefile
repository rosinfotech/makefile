.PHONY: init
.SILENT: init

init:
	chmod +x .makefile/*.sh

update_version: init
	.makefile/update_version.sh

git_commit_push: init
	.makefile/git_commit_push.sh "$(filter-out $@,$(MAKECMDGOALS))"

local_deploy_remote: init
	.makefile/local_deploy_remote.sh

%:
	@:
