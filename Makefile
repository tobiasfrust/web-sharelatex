DOCKER_COMPOSE_FLAGS ?= -f docker-compose.yml
BUILD_NUMBER ?= local
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD)
PROJECT_NAME = web

MODULE_DIRS := $(shell find modules -mindepth 1 -maxdepth 1 -type d -not -name '.git' )
MODULE_MAKEFILES := $(MODULE_DIRS:=/Makefile)
COFFEE := node_modules/.bin/coffee $(COFFEE_OPTIONS)
BABEL := node_modules/.bin/babel
GRUNT := node_modules/.bin/grunt

APP_COFFEE_FILES := $(shell find app/coffee -name '*.coffee')
FRONT_END_SRC_FILES := $(shell find public/src -name '*.js')
TEST_COFFEE_FILES := $(shell find test/*/coffee -name '*.coffee')
TEST_SRC_FILES := $(shell find test/*/src -name '*.js')
MODULE_MAIN_SRC_FILES := $(shell find modules -type f -wholename '*main/index.js')
MODULE_IDE_SRC_FILES := $(shell find modules -type f -wholename '*ide/index.js')
COFFEE_FILES := app.coffee $(APP_COFFEE_FILES) $(FRONT_END_COFFEE_FILES) $(TEST_COFFEE_FILES)
SRC_FILES := $(FRONT_END_SRC_FILES) $(TEST_SRC_FILES)
JS_FILES := $(subst coffee,js,$(COFFEE_FILES))
OUTPUT_SRC_FILES := $(subst src,js,$(SRC_FILES))
LESS_FILES := $(shell find public/stylesheets -name '*.less')
CSS_FILES := public/stylesheets/style.css public/stylesheets/ol-style.css public/stylesheets/ol-light-style.css

# The automatic variable $(@D) is the target directory name
app.js: app.coffee
	$(COFFEE) --compile -o $(@D) $< 

app/js/%.js: app/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

public/js/%.js: public/src/%.js
	@mkdir -p $(@D)
	$(BABEL) $< --out-file $@

test/unit/js/%.js: test/unit/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

test/acceptance/js/%.js: test/acceptance/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<

test/unit_frontend/js/%.js: test/unit_frontend/src/%.js
	@mkdir -p $(@D)
	$(BABEL) $< --out-file $@

test/smoke/js/%.js: test/smoke/coffee/%.coffee
	@mkdir -p $(@D)
	$(COFFEE) --compile -o $(@D) $<


public/js/ide.js: public/src/ide.js $(MODULE_IDE_SRC_FILES)
	@echo Compiling and injecting module includes into public/js/ide.js
	@INCLUDES=""; \
	for dir in modules/*; \
	do \
		MODULE=`echo $$dir | cut -d/ -f2`; \
		if [ -e $$dir/public/src/ide/index.js ]; then \
			INCLUDES="\"ide/$$MODULE/index\",$$INCLUDES"; \
		fi \
	done; \
	INCLUDES=$${INCLUDES%?}; \
	$(BABEL) $< | \
		sed -e s=\'__IDE_CLIENTSIDE_INCLUDES__\'=$$INCLUDES= \
		> $@

public/js/main.js: public/src/main.js $(MODULE_MAIN_SRC_FILES)
	@echo Compiling and injecting module includes into public/js/main.js
	@INCLUDES=""; \
	for dir in modules/*; \
	do \
		MODULE=`echo $$dir | cut -d/ -f2`; \
		if [ -e $$dir/public/src/main/index.js ]; then \
			INCLUDES="\"main/$$MODULE/index\",$$INCLUDES"; \
		fi \
	done; \
	INCLUDES=$${INCLUDES%?}; \
	$(BABEL) $< | \
		sed -e s=\'__MAIN_CLIENTSIDE_INCLUDES__\'=$$INCLUDES= \
		> $@

$(CSS_FILES): $(LESS_FILES)
	$(GRUNT) compile:css

minify: $(CSS_FILES) $(JS_FILES) $(OUTPUT_SRC_FILES)
	$(GRUNT) compile:minify
	$(MAKE) minify_es

minify_es:
	npm -q run webpack:production

css: $(CSS_FILES)

compile: $(JS_FILES) $(OUTPUT_SRC_FILES) css public/js/main.js public/js/ide.js
	@$(MAKE) compile_modules

compile_full:
	$(COFFEE) -c -p app.coffee > app.js
	$(COFFEE) -o app/js -c app/coffee
	$(BABEL) public/src --out-dir public/js
	$(COFFEE) -o test/acceptance/js -c test/acceptance/coffee
	$(COFFEE) -o test/smoke/js -c test/smoke/coffee
	$(COFFEE) -o test/unit/js -c test/unit/coffee
	$(BABEL) test/unit_frontend/src --out-dir test/unit_frontend/js
	rm -f public/js/ide.js public/js/main.js # We need to generate ide.js, main.js manually later
	$(MAKE) $(CSS_FILES)
	$(MAKE) compile_modules_full
	$(MAKE) compile # ide.js, main.js, share.js, and anything missed

compile_modules: $(MODULE_MAKEFILES)
	@set -e; \
	for dir in $(MODULE_DIRS); \
	do \
		if [ -e $$dir/Makefile ]; then \
			(cd $$dir && $(MAKE) compile); \
		fi; \
		if [ ! -e $$dir/Makefile ]; then \
			echo "No makefile found in $$dir"; \
		fi; \
	done

compile_modules_full: $(MODULE_MAKEFILES)
	@set -e; \
	for dir in $(MODULE_DIRS); \
	do \
		if [ -e $$dir/Makefile ]; then \
			echo "Compiling $$dir in full"; \
			(cd $$dir && $(MAKE) compile_full); \
		fi; \
		if [ ! -e $$dir/Makefile ]; then \
			echo "No makefile found in $$dir"; \
		fi; \
	done

$(MODULE_MAKEFILES): Makefile.module
	@set -e; \
	for makefile in $(MODULE_MAKEFILES); \
	do \
		cp Makefile.module $$makefile; \
	done

clean: clean_app clean_frontend clean_css clean_tests clean_modules

clean_app:
	rm -f app.js app.js.map
	rm -rf app/js

clean_frontend:
	rm -rf public/js/{analytics,directives,es,filters,ide,main,modules,services,utils}
	rm -f public/js/*.{js,map}

clean_tests:
	rm -rf test/unit/js
	rm -rf test/unit_frontend/js
	rm -rf test/acceptance/js

clean_modules:
	for dir in modules/*; \
	do \
		rm -f $$dir/index.js; \
		rm -rf $$dir/app/js; \
		rm -rf $$dir/test/unit/js; \
		rm -rf $$dir/test/acceptance/js; \
	done

clean_css:
	rm -f public/stylesheets/*.css*

clean_ci:
	docker-compose down -v -t 0

test: test_unit test_frontend test_acceptance

test_unit:
	npm -q run test:unit -- ${MOCHA_ARGS}

test_unit_app:
	npm -q run test:unit:app -- ${MOCHA_ARGS}

test_frontend: test_clean # stop service
	$(MAKE) compile
	docker-compose ${DOCKER_COMPOSE_FLAGS} up --exit-code-from test_frontend --abort-on-container-exit test_frontend

test_acceptance: test_acceptance_app test_acceptance_modules

test_acceptance_app:
	@set -e; \
	$(MAKE) test_acceptance_app_start_service; \
	$(MAKE) test_acceptance_app_run; \
	$(MAKE) test_acceptance_app_stop_service;

test_acceptance_app_start_service: test_clean # stop service and clear dbs
	$(MAKE) compile
	docker-compose ${DOCKER_COMPOSE_FLAGS} up -d test_acceptance

test_acceptance_app_stop_service:
	docker-compose ${DOCKER_COMPOSE_FLAGS} stop -t 0 test_acceptance redis mongo

test_acceptance_app_run:
	@docker-compose ${DOCKER_COMPOSE_FLAGS} exec -T test_acceptance npm -q run test:acceptance -- ${MOCHA_ARGS}; \
	result=$$?; \
	if [ $$result -eq 137 ]; then \
		docker-compose logs --tail=50 test_acceptance; \
		echo "\nOh dear, it looks like the web process crashed! Some logs are above, but to see them all, run:\n\n\tdocker-compose logs test_acceptance\n"; \
	fi; \
	exit $$result

test_acceptance_modules:
	@set -e; \
	for dir in $(MODULE_DIRS); \
	do \
		if [ -e $$dir/test/acceptance ]; then \
			$(MAKE) test_acceptance_module MODULE=$$dir; \
		fi; \
	done

test_acceptance_module: $(MODULE_MAKEFILES)
	@if [ -e $(MODULE)/test/acceptance ]; then \
		cd $(MODULE) && $(MAKE) test_acceptance; \
	fi

test_clean:
	docker-compose ${DOCKER_COMPOSE_FLAGS} down -v -t 0

ci:
	MOCHA_ARGS="--reporter tap" \
	$(MAKE) test

format:
	npm -q run format

lint:
	npm -q run lint

.PHONY:
	all add install update test test_unit test_frontend test_acceptance \
	test_acceptance_start_service test_acceptance_stop_service \
	test_acceptance_run ci ci_clean compile clean css
