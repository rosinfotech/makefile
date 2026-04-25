.PHONY: clear clone_makefile git_commit git_commit_push git_commit_version init kill_processes link local_deploy_remote setup unlink update_version
.SILENT: clear clone_makefile git_commit git_commit_push git_commit_version init kill_processes link local_deploy_remote setup unlink update_version

PROJECT_ROOT ?= .

clear: init
	$(PROJECT_ROOT)/.makefile/clear.sh

clone_makefile:
	$(PROJECT_ROOT)/.makefile/clone_makefile.sh

git_commit: init
	$(PROJECT_ROOT)/.makefile/git_commit.sh "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_push: init
	$(PROJECT_ROOT)/.makefile/git_commit_push.sh "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_version: init
	$(PROJECT_ROOT)/.makefile/git_commit_version.sh "$(filter-out $@,$(MAKECMDGOALS))"

init:
	chmod +x $(PROJECT_ROOT)/.makefile/*.sh $(PROJECT_ROOT)/.makefile/make

kill_processes: init
	$(PROJECT_ROOT)/.makefile/kill_processes.sh

link: init
	$(PROJECT_ROOT)/.makefile/link.sh

local_deploy_remote: init
	$(PROJECT_ROOT)/.makefile/local_deploy_remote.sh

setup: init
	$(PROJECT_ROOT)/.makefile/setup.sh

unlink: init
	$(PROJECT_ROOT)/.makefile/unlink.sh

update_version: init
	$(PROJECT_ROOT)/.makefile/update_version.sh

%:
	@:
