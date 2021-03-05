# gomake
#### A simple Makefile for cross-compiling Go projects

## Usage

Simply call `make` without arguments to build the project with default target `build`. Other targets include `clean`, `run`, `vet`, `zip`, `tgz`, and `tbz`. The `run` target builds the executable and runs it directly instead of invoking `go run`, which avoids some subtle runtime differences.

To cross-compile the project for a different target, provide a `platform` variable definition with a valid `${GOOS}-${GOARCH}` tuple as argument. Other variables may also be specified this way. For example, to create a 64-bit Windows zip package with a specific version:

```
$ make zip platform=windows-amd64 version=1.2.3
```

### Configuration

At the top of the `Makefile`, there are several variables that are used for configuration, each of which may also be overridden at the command line.

In particular, you will probably want to set `project` and `version` so that you don't have to specify them every time:

```make
project   ?= project-name
version   ?= 1.0.0
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
```

By default, the `Makefile` expects your project to be in a Git repository. Because, when building, the `branch` and `revision` variables are pulled from `git`. These can be replaced with calls to `svn`, `hg`, etc., or removed altogether if preferred.

These identifiers and others spcified in variable `exports` are automatically exported to your Go program's `main` package via the `go` linker, and so may be used from your Go source code. This provides a way to share version, build date, and other information with your Go program.



## Installation

Copy `Makefile` to the root of your project's import path.

