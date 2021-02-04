.PHONY: fmt install

HCLFMT := $(shell command -v hclfmt 2> /dev/null)

fmt:
ifndef HCLFMT
	GO111MODULE=on go get github.com/hashicorp/hcl/v2/cmd/hclfmt
endif
	find jobs/*.hcl -maxdepth 0 | xargs -L 1 hclfmt -w


install:
	find jobs/*.hcl -maxdepth 0 | xargs -L 1 nomad job run
