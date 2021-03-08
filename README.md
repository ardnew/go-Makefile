# go-Makefile
#### A simple Makefile for cross-compiling Go projects

## Usage

Simply call `make` without arguments to build the project with default target `build`. Other targets include `clean`, `run`, `vet`, `zip`, `tgz`, and `tbz`. 

The `run` target generates a shell script `./run.sh`. This shell script runs `make build` and then calls the project executable with all command-line arguments given to `run.sh`. This script is used because GNU Make does not have the explicit capability of forwarding arguments given to the `make` command on to an invoked executable. Therefore, instead of calling `make` directly, it is recommended to use this shell script for your normal edit-build-run development cycle.

To cross-compile the project for a different target, provide a `PLATFORM` variable definition with a valid `${GOOS}-${GOARCH}` tuple as argument. Other variables may also be specified this way. For example, to create a 64-bit Windows zip package with a specific version:

```
$ make zip PLATFORM=windows-amd64 VERSION=1.2.3
```

### Configuration

At the top of the `Makefile`, there are several variables that are used for configuration, each of which may also be overridden at the command line.

In particular, you will probably want to set `PROJECT` and `VERSION` so that you don't have to specify them every time you rebuild:

```make
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

# other non-Go source files that may affect build freshness
METASOURCES ?= Makefile go.mod

# other files to include with distribution packages
EXTRAFILES ?= LICENSE README.md

# Go package import path where the exported symbols will be defined
IMPORTPATH ?= main

# Makefile identifiers to export (as strings) via Go linker
EXPORTS ?= PROJECT VERSION BRANCH REVISION BUILDTIME PLATFORM
```

By default, the `Makefile` expects your project to be in a Git repository. Because, when building, the `BRANCH` and `REVISION` variables are pulled from `git`. These can be replaced with calls to `svn`, `hg`, etc., or removed altogether if preferred.

These identifiers and others spcified in variable `EXPORTS` are automatically exported to your Go program, in package `IMPORTPATH`, via the `go` linker, and so may be used from your Go source code. This provides a way to share version, build date, and other information with your Go program.

## Installation

Copy `Makefile` to the root of your project's import path. Then, optionally, call `make run` to generate the `run.sh` script described in [Usage](#usage) above.

