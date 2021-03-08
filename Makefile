# ------------------------------------------------------------------------------
#  project configuration (symbols exported verbatim via Go linker)

PROJECT   ?= my-project
VERSION   ?= 0.1.0
BRANCH    ?= $(shell git symbolic-ref --short HEAD)
REVISION  ?= $(shell git rev-parse --short HEAD)
BUILDTIME ?= $(shell date -u '+%FT%TZ')
PLATFORM  ?= linux-amd64

# default output paths
BINPATH ?= bin
PKGPATH ?= pkg

# consider all Go source files recursively from working dir
SOURCES ?= $(shell find . -type f -iname '*.go')

# other non-Go source files that may affect build staleness
METASOURCES ?= Makefile go.mod

# other files to include with distribution packages
EXTRAFILES ?= LICENSE README.md

# Go package import path where the exported symbols will be defined
IMPORTPATH ?= main

# Makefile identifiers to export (as strings) via Go linker
EXPORTS ?= PROJECT VERSION BRANCH REVISION BUILDTIME PLATFORM

# ------------------------------------------------------------------------------
#  constants and derived variables

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
mv    := mv -v
cp    := cp -rv
mkdir := mkdir -pv
chmod := chmod -v
tail  := tail
grep  := command grep
go    := GOOS="$(os)" GOARCH="$(arch)" go
tgz   := tar -czvf
tbz   := tar -cjvf
zip   := zip -vr

# go build flags: export variables as strings to the selected package
goflags ?= -v -ldflags='-w -s $(foreach %,$(EXPORTS),-X "$(IMPORTPATH).$(%)=$($(%))")'

# output paths
bindir := $(BINPATH)/$(PLATFORM)
binexe := $(bindir)/$(PROJECT)$(binext)
pkgver := $(PKGPATH)/$(VERSION)
triple := $(PROJECT)-$(VERSION)-$(PLATFORM)

# Since it isn't possible to pass arguments from make to the target executable
# (without, e.g., inline variable definitions), we simply use a separate shell
# script that builds the project and calls the executable.
# You can thus call this shell script, and all arguments will be passed along.
# Use the 'make run' target to generate this script in the project root.
runsh := run.sh
define RUNSH
#!/bin/sh
# Description:
# 	Rebuild and run $(binexe) with command-line arguments.
# 
# Usage:
# 	./$(runsh) [arg ...]
# 
if make build > /dev/null; then
	"$(binexe)" $${@}
fi
endef
export RUNSH

# ------------------------------------------------------------------------------
#  make targets

.PHONY: all
all: build

.PHONY: clean
clean:
	$(rm) "$(bindir)" "$(pkgver)/$(triple)"
	$(go) clean

.PHONY: build
build: $(binexe)

.PHONY: vet
vet: $(SOURCES) $(METASOURCES)
	$(go) vet

.PHONY: run
run: $(runsh)

$(bindir) $(pkgver) $(pkgver)/$(triple):
	@$(test) -d "$(@)" || $(mkdir) "$(@)"

$(binexe): $(SOURCES) $(METASOURCES) $(bindir)
	$(go) build -o "$(@)" $(goflags)
	@$(echo) " -- success: $(@)"

$(runsh):
	@$(echo) "$$RUNSH" > "$(@)"
	@$(chmod) +x "$(@)"
	@$(echo) " -- success: $(@)"
	@$(echo)
	@$(tail) -n +2 "$(@)" | $(grep) -oP '^#\K.*'

# ------------------------------------------------------------------------------
#  targets for creating versioned packages (.zip, .tar.gz, or .tar.bz2)

.PHONY: zip
zip: $(pkgver)/$(triple)$(zipext)

$(pkgver)/%$(zipext): $(EXTRAFILES) $(binexe) $(pkgver) $(pkgver)/%
	$(cp) "$(<)" $(EXTRAFILES) "$(@D)/$(*)"
	@$(cd) "$(@D)" && $(zip) "$(*)$(zipext)" "$(*)"

.PHONY: tgz
tgz: $(pkgver)/$(triple)$(tgzext)

$(pkgver)/%$(tgzext): $(EXTRAFILES) $(binexe) $(pkgver) $(pkgver)/%
	$(cp) "$(<)" $(EXTRAFILES) "$(@D)/$(*)"
	@$(cd) "$(@D)" && $(tgz) "$(*)$(tgzext)" "$(*)"

.PHONY: tbz
tbz: $(pkgver)/$(triple)$(tbzext)

$(pkgver)/%$(tbzext): $(EXTRAFILES) $(binexe) $(pkgver) $(pkgver)/%
	$(cp) "$(<)" $(EXTRAFILES) "$(@D)/$(*)"
	@$(cd) "$(@D)" && $(tbz) "$(*)$(tbzext)" "$(*)"

