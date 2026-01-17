.PHONY: init
.SILENT: init

init:
	chmod +x .makefile/*.sh

clear: init
	.makefile/clear.sh

update_version: init
	.makefile/update_version.sh

git_commit: init
	.makefile/git_commit.sh "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_push: init
	.makefile/git_commit_push.sh "$(filter-out $@,$(MAKECMDGOALS))"

git_commit_version: init
	.makefile/git_commit_version.sh "$(filter-out $@,$(MAKECMDGOALS))"

kill_processes: init
	.makefile/kill_processes.sh

local_deploy_remote_only_www: init
	.makefile/local_deploy_remote_only_www.sh

local_docker_compose_start: init
	.makefile/kill_processes.sh
	docker compose -f ops/docker-compose.local.yml --env-file envs/.env.local.backend --env-file envs/.env.local.frontend up -d

local_docker_compose_stop: init
	docker compose -f ops/docker-compose.local.yml --env-file envs/.env.local.backend --env-file envs/.env.local.frontend down
	.makefile/kill_processes.sh

local_deploy_remote: init
	.makefile/local_deploy_remote.sh

local_undeploy_remote: init
	.makefile/local_undeploy_remote.sh

%:
	@:
