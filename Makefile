# +----------------------------------------------------------------------------+
# | system configuration                                                       |
# +----------------------------------------------------------------------------+

# Verify we have a valid GOPATH that physically exists.
ifeq "" "$(strip $(wildcard $(GOPATH)))"
$(error invalid GOPATH="$(GOPATH)")
endif

# Define which debugger to use (optional; disables optimizations).
# If undefined, optimizations are enabled and debug targets are empty.
# Recognized debuggers: gdb dlv
DEBUG ?= gdb

# Verify environment is suited for whichever debugger (if any) is selected.
ifeq "gdb" "$(DEBUG)"
# Go source code ships with a GDB Python extension that enables:
#   -- Inspection of runtime internals (e.g., goroutines)
#   -- Pretty-printing built-in types (e.g., map, slice, and channel)
ifeq "" "$(GOROOT)"
$(error invalid GOROOT="$(GOROOT)")
endif
GDBRTL ?= "$(wildcard $(GOROOT)/src/runtime/runtime-gdb.py)"
endif

# +----------------------------------------------------------------------------+
# | project symbols exported verbatim via go linker                            |
# +----------------------------------------------------------------------------+

PROJECT   ?= my-project
IMPORT    ?= host/user/$(PROJECT)
VERSION   ?= 0.1.0
BUILDTIME ?= $(shell date -u '+%FT%TZ')
PLATFORM  ?= linux-amd64

# Determine Git branch and revision (if metadata exists).
ifneq "" "$(wildcard $(GOPATH)/src/$(IMPORT)/.git)"
# Verify we have the Git executable installed on our PATH.
ifneq "" "$(shell which git)"
BRANCH   ?= $(shell git symbolic-ref --short HEAD)
REVISION ?= $(shell git rev-parse --short HEAD)
endif
endif

# Makefile identifiers to export (as strings) via Go linker. If the project is
# not contained within a Git repository, BRANCH and REVISION will not be defined
# or exported for the application.
EXPORTS ?= PROJECT IMPORT VERSION BUILDTIME PLATFORM \
	$(and $(BRANCH),BRANCH) $(and $(REVISION),REVISION)

# +----------------------------------------------------------------------------+
# | build paths and project files                                              |
# +----------------------------------------------------------------------------+

# If the command being built is different than the project import path, define
# GOCMD as that import path. This will be used as the output executable when
# making targets "build", "run", "install", etc. For example, a common practice
# is to place the project's main package in a "cmd" subdirectory.
ifneq "" "$(wildcard cmd/$(PROJECT))"
# If a directory named PROJECT is found in the "cmd" subdirectory, use it as
# the main package.
GOCMD ?= $(IMPORT)/cmd/$(PROJECT)
else
GOCMD ?= # Otherwise, if GOCMD left undefined, use IMPORT.
endif

# Command executable (e.g., targets "build", "run")
BINPATH ?= bin
# Release package (e.g., targets "zip", "tgz", "tbz")
PKGPATH ?= dist

# Consider all Go source files recursively from working directory.
SOURCES ?= $(shell find . -type f -name '*.go')

# Other non-Go source files that may affect build staleness.
METASOURCES ?= Makefile $(wildcard go.mod)

# Other files to include with distribution packages (sort removes duplicates)
EXTRAFILES ?= $(sort $(wildcard LICENSE*) $(wildcard README*) \
	$(wildcard *.md) $(wildcard *.rst) $(wildcard *.adoc))

# Go package where the exported symbols will be defined.
EXPORTPATH ?= main

#        +==========================================================+
#   --=<])  YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE  ([>=--
#        +==========================================================+

# +----------------------------------------------------------------------------+
# | constants and derived variables                                            |
# +----------------------------------------------------------------------------+

# Supported platforms (GOARCH-GOOS):
platforms :=                                           \
	linux-amd64 linux-386 linux-arm64 linux-arm          \
	darwin-amd64 darwin-arm64                            \
	windows-amd64 windows-386                            \
	freebsd-amd64 freebsd-386 freebsd-arm                \
	android-amd64 android-386 android-arm64 android-arm

# Verify a valid build target was provided.
ifeq "" "$(strip $(filter $(platforms),$(PLATFORM)))"
$(error unsupported PLATFORM "$(PLATFORM)" (see: "make help"))
endif

# Parse arch (386, amd64, ...) and OS (linux, darwin, ...) from platform.
os   := $(word 1,$(subst -, ,$(PLATFORM)))
arch := $(word 2,$(subst -, ,$(PLATFORM)))

# Output file extensions:
binext := $(and $(filter windows,$(os)),.exe)
tgzext := .tar.gz
tbzext := .tar.bz2
zipext := .zip

# Invoke system commands using their full executable path to override any shell
# functions or aliases (which might conflict with the given flags or produce
# unexpected output). If "type" fails, fallback on shell built-in "command".
echo  := echo
test  := test
cd    := cd
rm    := rm -rvf
rmdir := rmdir
cp    := cp -rv
mkdir := mkdir -pv
chmod := chmod -v
tail  := tail
ls    := command ls
grep  := command grep
sed   := command sed
tgz   := tar -czvf
tbz   := tar -cjvf
zip   := zip -vr

# Always call "go" with our Makefile-selected platform, which effectively
# provides support for cross-compilation.
go := GOOS="$(os)" GOARCH="$(arch)" command go

# Export variables as strings to the selected package, and, if a debugger was
# selected, disable most Go compiler optimizations.
goflags ?= -v \
	-ldflags='-w -s $(foreach %,$(EXPORTS),-X "$(EXPORTPATH).$(%)=$($(%))")' \
	$(and $(strip $(DEBUG)),-gcflags=all="-N -l")

# Output paths derived from current configuration:
srcdir := $(or $(GOCMD),$(IMPORT))
bindir := $(GOPATH)/bin
binexe := $(bindir)/$(PROJECT)$(binext)
outdir := $(BINPATH)/$(PLATFORM)
outexe := $(outdir)/$(PROJECT)$(binext)
pkgver := $(PKGPATH)/$(VERSION)
triple := $(PROJECT)-$(VERSION)-$(PLATFORM)

# Targets for directories to clean when all of their content is removed.
mclean := $(addprefix clean-,$(BINPATH) $(PKGPATH))

# Since it isn't possible to pass arguments from "make" to the target executable
# (without, e.g., inline variable definitions), we simply use a separate shell
# script that builds the project and calls the executable.
# You can thus call this shell script, and all arguments will be passed along.
# Use "make run" to generate this script in the project root.
runsh := run.sh
define __RUNSH__
#!/bin/sh
# Description:
# 	Rebuild (via "make build") and run $(PROJECT)$(binext) with given arguments.
#
# Usage:
# 	./$(runsh) [arg ...]
#
if make -s build; then
	"$(outexe)" "$${@}"
fi
endef
export __RUNSH__

# +----------------------------------------------------------------------------+
# | make targets                                                               |
# +----------------------------------------------------------------------------+

.PHONY: all
all: build

# clean-DIR calls rmdir on DIR if and only if it is an empty directory.
clean-%: 
	@$(test) ! -d "$(*)" || $(test) `$(ls) -v "$(*)"` || $(rmdir) -v "$(*)"

.PHONY: flush
flush:
	$(go) clean
	$(rm) "$(outdir)" "$(pkgver)"

.PHONY: clean
clean: tidy flush $(mclean)

.PHONY: tidy
ifneq "" "$(strip $(filter %go.mod,$(METASOURCES)))"
tidy: $(and "$(strip $(filter %go.mod,$(METASOURCES)))",mod)
	@$(go) mod tidy
else
tidy:
endif

.PHONY: mod
mod: go.mod

.PHONY: build
build: tidy $(outexe)

.PHONY: install
install: tidy
	$(go) install $(goflags) "$(srcdir)"
	@$(echo) " -- success: $(binexe)"

.PHONY: vet
vet: tidy $(SOURCES) $(METASOURCES)
	$(go) vet "$(IMPORT)" $(and $(GOCMD),"$(GOCMD)")

.PHONY: run
run: $(runsh)

go.mod:
	@$(go) mod init

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
	@$(sed) -nE '/^#!/,/^\s*[^#]/{ /^\s*#([^!]|$)/{ s/^(\s*)#/  |\1/;p } }' "$(@)"

.PHONY: debug
debug:
ifeq "gdb" "$(DEBUG)"
	@$(echo) "gdb: $(DEBUG) $(GDBRTL)"
else ifeq "dlv" "$(DEBUG)"
	@$(echo) "dlv: $(DEBUG) $(GDBRTL)"
else
	@$(echo) "none: $(DEBUG) $(GDBRTL)"
endif

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

