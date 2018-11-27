REPO=malice-plugins/kaspersky
ORG=malice
NAME=kaspersky
CATEGORY=av
VERSION=$(shell cat VERSION)

KASPERSKY_KEY?=$(shell cat license.key | base64)

MALWARE=tests/malware
NOT_MALWARE=tests/not.malware

all: build size tag test_all

.PHONY: build
build:
	docker build --build-arg KASPERSKY_KEY=${KASPERSKY_KEY} -t $(ORG)/$(NAME):$(VERSION) .

.PHONY: build_no_cache
build_no_cache:
	docker build --no-cache --build-arg KASPERSKY_KEY=${KASPERSKY_KEY} -t $(ORG)/$(NAME):$(VERSION) .

.PHONY: build_w_key
build_w_key:
	docker build --build-arg KASPERSKY_KEY=${KASPERSKY_KEY} -t $(ORG)/$(NAME):$(VERSION) .

.PHONY: size
size:
	sed -i.bu 's/docker%20image-.*-blue/docker%20image-$(shell docker images --format "{{.Size}}" $(ORG)/$(NAME):$(VERSION)| cut -d' ' -f1)-blue/' README.md

.PHONY: tag
tag:
	docker tag $(ORG)/$(NAME):$(VERSION) $(ORG)/$(NAME):latest

.PHONY: tags
tags:
	docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" $(ORG)/$(NAME)

.PHONY: ssh
ssh:
	@docker run --init -it --rm --name $(NAME) --entrypoint=bash $(ORG)/$(NAME):$(VERSION)
	# --privileged --security-opt apparmor=unconfined

.PHONY: tar
tar:
	docker save $(ORG)/$(NAME):$(VERSION) -o $(NAME).tar

.PHONY: push
push: build tag
	docker push $(ORG)/$(NAME):$(VERSION)
	docker push $(ORG)/$(NAME):latest

go-test:
	go get
	go test -v

SPVR=/etc/init.d/kav4fs-supervisor
CTRL=/opt/kaspersky/kav4fs/bin/kav4fs-control
VERIFY=$(CTRL) -S --app-info
avtest: malware
	@echo "===>  Version"
	@docker run --init --rm --entrypoint=bash $(ORG)/$(NAME):$(VERSION) -c "$(SPVR) start;sleep 3 && $(VERIFY)" > tests/av_version.out
	@echo "===>  License"
	@docker run --init --rm --entrypoint=bash $(ORG)/$(NAME):$(VERSION) -c "$(SPVR) start;sleep 3 && $(CTRL) -L --query-status" > tests/av_license.out
	@echo "===>  EICAR Test"
	@docker run --init -it --rm --entrypoint=bash -v $(PWD)/tests:/malware/tests $(ORG)/$(NAME):$(VERSION) -c "MALWARE=/malware/EICAR tests/test_malware.sh" > tests/av_eicar_scan.out || true
	@echo "===>  $(MALWARE) Test"
	@docker run --init -it --rm --entrypoint=bash -v $(PWD)/tests:/malware/tests $(ORG)/$(NAME):$(VERSION) -c "MALWARE=$(MALWARE) tests/test_malware.sh" > tests/av_malware_scan.out || true
	@echo "===>  $(NOT_MALWARE) Test"
	@docker run --init -it --rm --entrypoint=bash -v $(PWD)/tests:/malware/tests $(ORG)/$(NAME):$(VERSION) -c "MALWARE=$(NOT_MALWARE) tests/test_malware.sh" > tests/av_clean_scan.out || true

update:
	@docker run --init --rm $(ORG)/$(NAME):$(VERSION) -V update

.PHONY: start_elasticsearch
start_elasticsearch:
ifeq ("$(shell docker inspect -f {{.State.Running}} elasticsearch)", "true")
	@echo "===> elasticsearch already running.  Stopping now..."
	@docker rm -f elasticsearch || true
endif
	@echo "===> Starting elasticsearch"
	@docker run --init -d --name elasticsearch -p 9200:9200 malice/elasticsearch:6.5; sleep 15

.PHONY: malware
malware:
ifeq (,$(wildcard $(MALWARE)))
	wget https://github.com/maliceio/malice-av/raw/master/samples/befb88b89c2eb401900a68e9f5b78764203f2b48264fcc3f7121bf04a57fd408 -O $(MALWARE)
	cd tests; echo "TEST" > not.malware
endif

.PHONY: test_all
test_all: test test_elastic test_markdown test_web

.PHONY: test
test: malware
	@echo "===> ${NAME} --help"
	docker run --init --rm $(ORG)/$(NAME):$(VERSION) --help
	docker run --init --rm -v $(PWD):/malware $(ORG)/$(NAME):$(VERSION) -V $(MALWARE) | jq . > docs/results.json
	cat docs/results.json | jq .

.PHONY: test_elastic
test_elastic: start_elasticsearch malware
	@echo "===> ${NAME} test_elastic found"
	docker run --rm --link elasticsearch -e MALICE_ELASTICSEARCH_URL=http://elasticsearch:9200 -v $(PWD):/malware $(ORG)/$(NAME):$(VERSION) -V $(MALWARE)
	@echo "===> ${NAME} test_elastic NOT found"
	docker run --rm --link elasticsearch -e MALICE_ELASTICSEARCH_URL=http://elasticsearch:9200 -v $(PWD):/malware $(ORG)/$(NAME):$(VERSION) -V $(NOT_MALWARE)
	http localhost:9200/malice/_search | jq . > docs/elastic.json

.PHONY: test_markdown
test_markdown: test_elastic
	@echo "===> ${NAME} test_markdown"
	# http localhost:9200/malice/_search query:=@docs/query.json | jq . > docs/elastic.json
	cat docs/elastic.json | jq -r '.hits.hits[] ._source.plugins.${CATEGORY}.${NAME}.markdown' > docs/SAMPLE.md

.PHONY: test_web
test_web: malware stop
	@echo "===> Starting web service"
	@docker run -d --name $(NAME) -p 3993:3993 $(ORG)/$(NAME):$(VERSION) web
	http -f localhost:3993/scan malware@$(MALWARE)
	@echo "===> Stopping web service"
	@docker logs $(NAME)
	@docker rm -f $(NAME)

.PHONY: stop
stop: ## Kill running docker containers
	@docker rm -f $(NAME) || true

.PHONY: circle
circle: ci-size
	@sed -i.bu 's/docker%20image-.*-blue/docker%20image-$(shell cat .circleci/size)-blue/' README.md
	@echo "===> Image size is: $(shell cat .circleci/size)"

ci-build:
	@echo "===> Getting CircleCI build number"
	@http https://circleci.com/api/v1.1/project/github/${REPO} | jq '.[0].build_num' > .circleci/build_num

ci-size: ci-build
	@echo "===> Getting artifact sizes from CircleCI"
	@cd .circleci; rm size || true
	@http https://circleci.com/api/v1.1/project/github/${REPO}/$(shell cat .circleci/build_num)/artifacts${CIRCLE_TOKEN} | jq -r ".[] | .url" | xargs wget -q -P .circleci

clean:
	docker-clean stop
	docker image rm $(ORG)/$(NAME):$(VERSION)  || true
	docker image rm $(ORG)/$(NAME):latest || true
	rm $(MALWARE)  || true
	rm $(NOT_MALWARE)  || true

# Absolutely awesome: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := all

