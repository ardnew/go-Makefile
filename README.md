# go-Makefile
#### A simple Makefile for cross-compiling Go projects

## Usage

Simply call `make` without arguments to build the project with default target `build`. Other targets include `clean`, `run`, `tidy`, `vet`, `zip`, `tgz`, and `tbz`. 

The `run` target generates a shell script `./run.sh`. This shell script runs `make build` and then calls the project executable with all command-line arguments given to `run.sh`. This script is used because GNU Make does not have the explicit capability of forwarding arguments given to the `make` command on to an invoked executable. Therefore, instead of calling `make` directly, it is recommended to use this shell script for your normal edit-build-run development cycle: 

0.  Call `make run` only **one time**(!) to generate the `run.sh` script
1.  Edit sources
2.  Call `./run.sh [YOUR-PROGRAM-ARGS ...]` to rebuild and run the generated executable
3.  Goto 1.

### Cross-compiling

To cross-compile the project for a different target, provide a `PLATFORM` variable definition with a valid `${GOOS}-${GOARCH}` tuple as argument. Other variables may also be specified this way. For example, to create a 64-bit Windows zip package with a specific version:

```
$ make zip PLATFORM=windows-amd64 VERSION=1.2.3
```

### Configuration

At the top of the `Makefile`, there are several variables that are used for configuration, each of which may also be overridden at the command line.

In particular, you will probably want to set `PROJECT` and `VERSION` so that you don't have to specify them every time you rebuild:

```make
PROJECT   ?= my-project
IMPORT    ?= host/user/$(PROJECT)
VERSION   ?= 0.1.0
BUILDTIME ?= $(shell date -u '+%FT%TZ')
PLATFORM  ?= linux-amd64
```

And then optionally configure project file paths if you have unconventional project structure or content:

```make
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
```

### Main package location

If your main import path is in the project root directory (where this `Makefile` is installed), or if it is in the `cmd/` subdirectory and has the same base name as the project root (e.g., `import/path/foo/cmd/foo`) it will be detected automatically. Otherwise, configure `GOCMD` with the Go import path to your main package:

```make
# if the command being built is different than the project import path, define
# GOCMD as that import path. this will be used as the output executable when
# making targets "build", "run", "install", etc.
ifneq "" "$(wildcard cmd/$(PROJECT))"
GOCMD ?= $(IMPORT)/cmd/$(PROJECT)
else
GOCMD ?= # if left undefined, uses IMPORT
endif
```

### Branch and revision identification

By default, the `Makefile` expects your project to be in a Git repository. Because, when building, the `BRANCH` and `REVISION` variables are pulled from `git`. These can be replaced with calls to `svn`, `hg`, etc., or removed altogether if preferred. 

If the project is not inside a Git repository, or you do not have Git command-line tools installed, then the `BRANCH` and `REVISION` variables will silently remain undefined:

```make
# determine git branch and revision if metadata exists
ifneq "" "$(wildcard $(GOPATH)/src/$(IMPORT)/.git)"
# verify we have git installed
ifneq "" "$(shell which git)"
BRANCH   ?= $(shell git symbolic-ref --short HEAD)
REVISION ?= $(shell git rev-parse --short HEAD)
endif
endif
```

### Exported variables

By default, the project name, import path, version, buildtime, target platform, branch, and revision - specified, if available, in variable `EXPORTS` - are automatically exported to your Go program, in package `EXPORTPATH`, via the `go` linker, and so may be used from your Go source code. 

```make
# Makefile identifiers to export (as strings) via Go linker
EXPORTS ?= PROJECT IMPORT VERSION BUILDTIME PLATFORM \
	$(if $(BRANCH),BRANCH,) $(if $(REVISION),REVISION,) 
```

This provides a way to share version and build information with your Go program at build-time. You then only need to declare global identifiers in the package naamed by `EXPORTPATH` to access them:

```go
package main

import "fmt"

var PROJECT, IMPORT, VERSION, BUILDTIME, PLATFORM, BRANCH, REVISION string

func main() {
  fmt.Printf("%s %q v%s %s %s@%s %s\n", 
    PROJECT, IMPORT, VERSION, PLATFORM, BRANCH, REVISION, BUILDTIME)
}
```

## Installation

Copy `Makefile` to the root of your project's import path. Then, optionally, call `make run` to generate the `run.sh` script described in [Usage](#usage) above.

