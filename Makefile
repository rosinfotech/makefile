.PHONY: bump_version init run_service_auth
.SILENT: init

init:
	chmod +x scripts/*.sh

sync_version: init
	scripts/sync_version.sh

git_commit_push: init
	scripts/git_commit_push.sh "$(filter-out $@,$(MAKECMDGOALS))"

test: init
	scripts/test.sh

%:
	@:
