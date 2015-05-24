ERR=*** composer not found
HINT=Please, goto https://getcomposer.org and install it globally.

all: composer-install

test: test/phpunit.xml
	@vendor/bin/phpunit -c test

coverage: test/clover.xml
	@vendor/bin/coveralls -v -c test/.coveralls.yml

skins: .gitmodules
	@git submodule init
	@git submodule update

help:
	@echo
	@echo "Please, if you agree, run the following commands inside the main directory:"
	@echo "   make config     - if you need help to configure php-proxy-keyserver"
	@echo "   make skins      - if you wish to download extra skins"
	
config:
	@cd etc && test -e php-proxy-keyserver.ini || cp php-proxy-keyserver.ini.example php-proxy-keyserver.ini
	@echo
	@echo "----- PLEASE, EDIT YOUR CONFIG FILES -----"
	@echo
	@echo "1) Edit ${PWD}/etc/php-proxy-keyserver.ini"
	@echo "2) Set ${PWD}/pub as the DocumentRoot of your domain in your webserver configs."
	@echo
	@echo "When done, please visit your website and validate that you can search/retrieve/submit pgp public keys."

composer-install:
	$(if $(shell sh -c 'composer -v >/dev/null 2>&1 && echo 1'),,$(warning $(ERR));$(error $(HINT)))
	@composer self-update
	@composer install

debug: log/php-proxy-keyserver.log
	@tail -f log/php-proxy-keyserver.log

clean: log
	@rm -rf log

.PHONY: test skins
