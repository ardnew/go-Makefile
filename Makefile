# ------------------------------------------------------------------------------
#  project configuration

project   ?= svngrab
version   ?= 0.2.1
branch    ?= $(shell git symbolic-ref --short HEAD)
revision  ?= $(shell git rev-parse --short HEAD)
buildtime ?= $(shell date -u '+%FT%TZ')

# default build target
platform ?= linux-amd64

# default output paths
binpath ?= bin
pkgpath ?= pkg

# other files to include with distribution packages
extrafiles ?= LICENSE README.md

# Makefile identifiers to export to Go via linker
exports ?= project version branch revision buildtime

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
ifeq "" "$(strip $(filter $(platforms),$(platform)))"
$(error unsupported platform "$(platform)" (see: "make help"))
endif

# parse OS (linux, darwin, ...) and arch (386, amd64, ...) from platform
os   := $(word 1,$(subst -, ,$(platform)))
arch := $(word 2,$(subst -, ,$(platform)))

# output file extensions
binext := $(if $(filter windows,$(os)),.exe,)
tgzext := .tar.gz
tbzext := .tar.bz2
zipext := .zip

# system commands
rm    := rm -rvf
go    := GOOS="$(os)" GOARCH="$(arch)" go
mkdir := mkdir -pv
mv    := mv -v
cp    := cp -rv
tgz   := tar -czvf
tbz   := tar -cjvf
zip   := zip -vr

# go build flags
goflags ?= -v -ldflags='-w -s $(foreach %,$(exports),-X "main.$(%)=$($(%))")'

# output paths
bindir := $(binpath)/$(platform)
binexe := $(bindir)/$(project)$(binext)
pkgver := $(pkgpath)/$(version)
triple := $(project)-$(version)-$(platform)

# ------------------------------------------------------------------------------
#  make targets

.PHONY: all
all: build

.PHONY: clean
clean:
	$(rm) "$(bindir)" "$(pkgver)/$(triple)" "$(pkgver)/$(triple)$(zipext)" "$(pkgver)/$(triple)$(tgzext)" "$(pkgver)/$(triple)$(tbzext)"
	$(go) clean

.PHONY: build
build: $(binexe)

.PHONY: vet
vet:
	$(go) vet

.PHONY: run
run: $(binexe)
	@"$(binexe)"

$(bindir) $(pkgver) $(pkgver)/$(triple):
	@test -d "$(@)" || $(mkdir) "$(@)"

$(binexe): $(bindir)
	$(go) build -o "$(@)" $(goflags)

# ------------------------------------------------------------------------------
#  targets for creating versioned packages (.zip, .tar.gz, or .tar.bz2)

.PHONY: zip
pkg: clean $(pkgver)/$(triple)$(zipext)

$(pkgver)/%$(zipext): $(binexe) $(pkgver) $(pkgver)/%
	$(cp) "$(<)" $(extrafiles) "$(@D)/$(*)"
	cd "$(@D)" && $(zip) "$(*)$(zipext)" "$(*)"

.PHONY: tgz
pkg: clean $(pkgver)/$(triple)$(tgzext)

$(pkgver)/%$(tgzext): $(binexe) $(pkgver) $(pkgver)/%
	$(cp) "$(<)" $(extrafiles) "$(@D)/$(*)"
	cd "$(@D)" && $(tgz) "$(*)$(tgzext)" "$(*)"

.PHONY: tbz
pkg: clean $(pkgver)/$(triple)$(tbzext)

$(pkgver)/%$(tbzext): $(binexe) $(pkgver) $(pkgver)/%
	$(cp) "$(<)" $(extrafiles) "$(@D)/$(*)"
	cd "$(@D)" && $(tbz) "$(*)$(tbzext)" "$(*)"

