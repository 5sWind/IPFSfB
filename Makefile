# Copyright 2019 IBM Corp.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# -------------------------------------------------------------
# This makefile defines the following targets
#
#   - all (default) - builds all targets and runs all non-integration tests/checks
#	- swarmkeygen - builds a native swarmkeygen library
#	- ipfs - builds the go-ipfs library
#	- clean - cleans the build area
# -------------------------------------------------------------

BASE_VERSION = 0.2.0
IMAGE_VERSION = 0.2.0
COMMIT_VERSION ?= $(shell git rev-parse --short HEAD)

DOCKER_NS = ipfsfb
BASE_DOCKER_NS = ipfs
DOCKER_TAG = latest peer server
DOCKER_IMAGES = $(shell echo $(DOCKER_BUILD) | xargs -n1 docker images -q)

BUILD_DIR ?= $(shell pwd)/.build
GOBIN = $(GOPATH)/bin
GO_VER = $(shell grep -A1 'go:' .travis.yml | grep -v "go:" | cut -d'-' -f2- | cut -d' ' -f2-)
GO_MODULE_ENABLED = GO111MODULE=on
EXECUTABLES ?= go docker git curl
IMAGES = tools node
PACKAGES = ipfs swarmkeygen
ORG = IBM
PROJECT_NAME = IPFSfB
PROJECT_PATH = github.com/$(ORG)/$(PROJECT_NAME)
IPFS_VERSION = latest

PROJECT_VER = ReleaseVersion=$(BASE_VERSION)
PROJECT_VER += ImageVersion=$(IMAGE_VERSION)
PROJECT_VER += CommitSHA=$(COMMIT_VERSION)

GO_LDFLAGS = $(patsubst %,-X $(PROJECT_PATH)/release.%, $(PROJECT_VER))
TAGS = $(patsubst %, :%, $(DOCKER_TAG))
DOCKER_BUILD = $(patsubst %, $(DOCKER_NS)/$(BASE_DOCKER_NS)-%$(TAGS), $(IMAGES))
BASE_DOCKER_BUILD = $(patsubst %, $(DOCKER_NS)/$(BASE_DOCKER_NS)-%, $(IMAGES))

pkgmap.swarmkeygen := $(PROJECT_PATH)/cmd/swarmkeygen
pkgmap.ipfs        := github.com/ipfs

.PHONY: all ipfs swarmkeygen docker clean

all: ipfs swarmkeygen docker

ipfs:
	$(GO_MODULE_ENABLED) go get -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))/ipfs-update
	ipfs-update install $(IPFS_VERSION)
	rm -f $(GOBIN)/ipfs-update
	rm -rf $(GOPATH)/src/$(pkgmap.$(@F))/ipfs-update

swarmkeygen: 
	go get -ldflags "$(GO_LDFLAGS)" -u $(pkgmap.$(@F))

docker:
	@echo $(BASE_DOCKER_BUILD) | xargs -n1 docker pull -a

clean:
	rm -f $(GOBIN)/ipfs $(GOBIN)/swarmkeygen
	[ -n "$(DOCKER_IMAGES)" ] && docker rmi -f $(DOCKER_IMAGES) || true