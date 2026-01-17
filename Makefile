.PHONY: init
.SILENT: init

init:
	chmod +x .makefile/*.sh

clear: init
	.makefile/clear.sh

update_version: init
	.makefile/update_version.sh

git_commit_push: init
	.makefile/git_commit_push.sh "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_version: init
	.makefile/git_commit_version.sh "$(filter-out $@,$(MAKECMDGOALS))"

git_commit: init
	.makefile/git_commit.sh "$(filter-out $@,$(MAKECMDGOALS))"

kill_processes: init
	.makefile/kill_processes.sh

local_deploy_remote: init
	.makefile/local_deploy_remote.sh

%:
	@:
