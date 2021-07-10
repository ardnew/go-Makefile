# +----------------------------------------------------------------------------+
# | system configuration                                                       |
# +----------------------------------------------------------------------------+

# verify we have a valid GOPATH
GOPATH ?= $(shell go env GOPATH)
ifeq "" "$(strip $(GOPATH))"
$(error invalid GOPATH="$(GOPATH)")
endif

# +----------------------------------------------------------------------------+
# | project symbols exported verbatim via go linker                            |
# +----------------------------------------------------------------------------+

PROJECT   ?= my-project
IMPORT    ?= host/user/$(PROJECT)
VERSION   ?= 0.1.0
BUILDTIME ?= $(shell date -u '+%FT%TZ')
PLATFORM  ?= linux-amd64

# determine git branch and revision if metadata exists
ifneq "" "$(wildcard $(GOPATH)/src/$(IMPORT)/.git)"
# verify we have git installed
ifneq "" "$(shell which git)"
BRANCH   ?= $(shell git symbolic-ref --short HEAD)
REVISION ?= $(shell git rev-parse --short HEAD)
endif
endif

# Makefile identifiers to export (as strings) via Go linker
EXPORTS ?= PROJECT IMPORT VERSION BUILDTIME PLATFORM \
	$(if $(BRANCH),BRANCH,) $(if $(REVISION),REVISION,) 

# +----------------------------------------------------------------------------+
# | build paths and project files                                              |
# +----------------------------------------------------------------------------+

# if the command being built is different than the project import path, define
# GOCMD as that import path. this will be used as the output executable when
# making targets "build", "run", "install", etc. for example, a common practice
# is to place the project's main package in a "cmd" subdirectory. 
ifneq "" "$(wildcard cmd/$(PROJECT))"
# if a directory named PROJECT is found in the "cmd" subdirectory, use it as
# the main package.
GOCMD ?= $(IMPORT)/cmd/$(PROJECT)
else
GOCMD ?= # otherwise, if GOCMD left undefined, use IMPORT.
endif

# default output paths
BINPATH ?= bin
PKGPATH ?= pkg

# consider all Go source files recursively from working dir
SOURCES ?= $(shell find . -type f -iname '*.go')

# other non-Go source files that may affect build staleness
METASOURCES ?= Makefile go.mod

# other files to include with distribution packages
EXTRAFILES ?= LICENSE README.md

# Go package where the exported symbols will be defined
EXPORTPATH ?= main

# Paths to remove when all of their contents are removed
CLEANPARENT ?= $(BINPATH) $(PKGPATH)

#        +==========================================================+           
#      <||  YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE  ||>         
#        +==========================================================+           

# +----------------------------------------------------------------------------+
# | constants and derived variables                                            |
# +----------------------------------------------------------------------------+

# supported platforms (GOARCH-GOOS)
platforms :=                                           \
	linux-amd64 linux-386 linux-arm64 linux-arm          \
	darwin-amd64 darwin-arm64                            \
	windows-amd64 windows-386                            \
	freebsd-amd64 freebsd-386 freebsd-arm                \
	android-amd64 android-386 android-arm64 android-arm

# invalid build target provided
ifeq "" "$(strip $(filter $(platforms),$(PLATFORM)))"
$(error unsupported PLATFORM "$(PLATFORM)" (see: "make help"))
endif

# parse OS (linux, darwin, ...) and arch (386, amd64, ...) from PLATFORM
os   := $(word 1,$(subst -, ,$(PLATFORM)))
arch := $(word 2,$(subst -, ,$(PLATFORM)))

# output file extensions
binext := $(if $(filter windows,$(os)),.exe,)
tgzext := .tar.gz
tbzext := .tar.bz2
zipext := .zip

# system commands
echo  := echo
test  := test
cd    := cd
rm    := rm -rvf
rmdir := rmdir
mv    := mv -v
cp    := cp -rv
mkdir := mkdir -pv
chmod := chmod -v
tail  := tail
ls    := command ls
grep  := command grep
go    := GOOS="$(os)" GOARCH="$(arch)" go
tgz   := tar -czvf
tbz   := tar -cjvf
zip   := zip -vr

# go build flags: export variables as strings to the selected package
goflags ?= -v -ldflags='-w -s $(foreach %,$(EXPORTS),-X "$(EXPORTPATH).$(%)=$($(%))")'

# output paths
srcdir := $(or $(GOCMD),$(IMPORT))
bindir := $(shell go env GOPATH)/bin
binexe := $(bindir)/$(PROJECT)$(binext)
outdir := $(BINPATH)/$(PLATFORM)
outexe := $(outdir)/$(PROJECT)$(binext)
pkgver := $(PKGPATH)/$(VERSION)
triple := $(PROJECT)-$(VERSION)-$(PLATFORM)

# make targets for directories to clean when their content is removed.
pclean := $(addprefix clean-,$(CLEANPARENT))

# Since it isn't possible to pass arguments from make to the target executable
# (without, e.g., inline variable definitions), we simply use a separate shell
# script that builds the project and calls the executable.
# You can thus call this shell script, and all arguments will be passed along.
# Use the 'make run' target to generate this script in the project root.
runsh := run.sh
define RUNSH
#!/bin/sh
# Description:
# 	Rebuild and run $(outexe) with command-line arguments.
# 
# Usage:
# 	./$(runsh) [arg ...]
# 
if make -s build; then
	"$(outexe)" "$${@}"
fi
endef
export RUNSH

# +----------------------------------------------------------------------------+
# | make targets                                                               |
# +----------------------------------------------------------------------------+

.PHONY: all
all: build

clean-%::
	@test ! -d "$(*)" || test `$(ls) -v "$(*)"` || $(rmdir) -v "$(*)"

.PHONY: flush
flush:
	$(go) clean
	$(rm) "$(outdir)" "$(pkgver)/$(triple)" "$(runsh)"

.PHONY: clean
clean: tidy flush $(pclean)

.PHONY: tidy
tidy: $(METASOURCES)
	@$(go) mod tidy

.PHONY: build
build: tidy $(outexe)

.PHONY: install
install: tidy
	$(go) install $(goflags) "$(srcdir)"
	@$(echo) " -- success: $(binexe)"

.PHONY: vet
vet: tidy $(SOURCES) $(METASOURCES)
	$(go) vet "$(IMPORT)" $(if $(GOCMD),"$(GOCMD)",)

.PHONY: run
run: $(runsh)

$(outdir) $(pkgver) $(pkgver)/$(triple):
	@$(test) -d "$(@)" || $(mkdir) "$(@)"

$(outexe): $(SOURCES) $(METASOURCES) $(outdir)
	$(go) build -o "$(@)" $(goflags) "$(srcdir)"
	@$(echo) " -- success: $(@)"

$(runsh):
	@$(echo) "$$RUNSH" > "$(@)"
	@$(chmod) +x "$(@)"
	@$(echo) " -- success: $(@)"
	@$(echo)
	@# print the comment block at top of shell script for usage details
	@$(tail) -n +2 "$(@)" | $(grep) -oP '^#\K.*'

# +----------------------------------------------------------------------------+
# | targets for creating versioned packages (.zip, .tar.gz, or .tar.bz2)       |
# +----------------------------------------------------------------------------+

.PHONY: zip
zip: $(EXTRAFILES) $(pkgver)/$(triple)$(zipext)

$(pkgver)/%$(zipext): $(outexe) $(pkgver)/%
	$(cp) "$(<)" $(EXTRAFILES) "$(@D)/$(*)"
	@$(cd) "$(@D)" && $(zip) "$(*)$(zipext)" "$(*)"

.PHONY: tgz
tgz: $(EXTRAFILES) $(pkgver)/$(triple)$(tgzext)

$(pkgver)/%$(tgzext): $(outexe) $(pkgver)/%
	$(cp) "$(<)" $(EXTRAFILES) "$(@D)/$(*)"
	@$(cd) "$(@D)" && $(tgz) "$(*)$(tgzext)" "$(*)"

.PHONY: tbz
tbz: $(EXTRAFILES) $(pkgver)/$(triple)$(tbzext)

$(pkgver)/%$(tbzext): $(outexe) $(pkgver)/%
	$(cp) "$(<)" $(EXTRAFILES) "$(@D)/$(*)"
	@$(cd) "$(@D)" && $(tbz) "$(*)$(tbzext)" "$(*)"

