PWD = `pwd`

# Dev environment variables
export DAEMON ?= off
export LUA_LIB ?= lua_package_path \"$(PWD)/src/?.lua\;\;\"\;
export LUA_CODE_CACHE ?= off
export APENODE_PORT ?= 8000
export APENODE_WEB_PORT ?= 8001
export DIR ?= $(PWD)/tmp
export APENODE_CONF ?= $(DIR)/apenode.conf
export SILENT ?=

.PHONY: build global test test-web test-all run migrate populate drop

global:
	@luarocks make apenode-*.rockspec

test:
	@busted spec/unit

test-db:
	@busted spec/database

test-web:
	@$(MAKE) build DAEMON=on
	@$(MAKE) migrate SILENT=-s
	@$(MAKE) run
	@$(MAKE) seed SILENT=-s
	@busted spec/web/ || (make stop;make drop; exit 1)
	@$(MAKE) stop
	@$(MAKE) drop SILENT=-s

test-proxy:
	@$(MAKE) build DAEMON=on
	@$(MAKE) migrate SILENT=-s
	@$(MAKE) run
	@$(MAKE) seed SILENT=-s
	@busted spec/proxy/ || (make stop;make drop; exit 1)
	@$(MAKE) stop
	@$(MAKE) drop SILENT=-s

test-all:
	@$(MAKE) build DAEMON=on
	@$(MAKE) migrate SILENT=-s
	@$(MAKE) run
	@sleep 2 # Wait for the nginx process to start
	@$(MAKE) seed SILENT=-s
	@busted spec/ || (make stop;make drop; exit 1)
	@$(MAKE) stop
	@$(MAKE) drop SILENT=-s

migrate:
	@scripts/migrate migrate $(SILENT) --conf=$(APENODE_CONF)

reset:
	@scripts/migrate reset $(SILENT) --conf=$(APENODE_CONF)

seed:
	@scripts/seed seed $(SILENT) --conf=$(APENODE_CONF)

drop:
	@scripts/seed drop $(SILENT) --conf=$(APENODE_CONF)

run:
	@nginx -p $(DIR)/nginx -c nginx.conf

stop:
	@nginx -p $(DIR)/nginx -c nginx.conf -s stop

build:
	@mkdir -p $(DIR)/nginx/logs
	@cp templates/apenode.conf $(APENODE_CONF)
	@echo "" > $(DIR)/nginx/logs/error.log
	@echo "" > $(DIR)/nginx/logs/access.log
	@sed \
		-e "s/{{DAEMON}}/$(DAEMON)/g" \
		-e "s@{{LUA_LIB_PATH}}@$(LUA_LIB)@g" \
		-e "s/{{LUA_CODE_CACHE}}/$(LUA_CODE_CACHE)/g" \
		-e "s/{{PORT}}/$(APENODE_PORT)/g" \
		-e "s/{{WEB_PORT}}/$(APENODE_WEB_PORT)/g" \
		-e "s@{{APENODE_CONF}}@$(APENODE_CONF)@g" \
		templates/nginx.conf > $(DIR)/nginx/nginx.conf;

	@cp -R src/apenode/web/static $(DIR)/nginx
	@cp -R src/apenode/web/admin $(DIR)/nginx
