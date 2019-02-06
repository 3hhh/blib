# blib - a bash library

blib is a lightweight general purpose library for bash developers written in pure bash.

It attempts to provide robust implementations for commonly encountered issues whilst leaving the bash syntax as it is.

## Functionality

blib currently provides functionality in the following areas:

* [logging](https://3hhh.github.io/blib-doc/blib.html#flog)
* [mutexes](https://3hhh.github.io/blib-doc/blib.html#mtx)
* [code documentation](https://3hhh.github.io/blib-doc/blib.html#cdoc)
* [config files](https://3hhh.github.io/blib-doc/blib.html#ini)
* [OS identification](https://3hhh.github.io/blib-doc/blib.html#ososid)
* [data typing](https://3hhh.github.io/blib-doc/blib.html#types)
* [terminal colors](https://3hhh.github.io/blib-doc/blib.html#tcolors)
* [traps](https://3hhh.github.io/blib-doc/blib.html#traps)
* [module management](https://3hhh.github.io/blib-doc/blib.html#b_import)
* [error reporting & handling](https://3hhh.github.io/blib-doc/blib.html#B_E)
* [privilege elevation](https://3hhh.github.io/blib-doc/blib.html#b_execFuncAs)
* [inter-process communication](https://3hhh.github.io/blib-doc/blib.html#ipcv)
* [Qubes OS](https://3hhh.github.io/blib-doc/blib.html#osqubes4dom0): [RPC](https://3hhh.github.io/blib-doc/blib.html#b_dom0_execFuncIn), [file attaching](https://3hhh.github.io/blib-doc/blib.html#b_dom0_attachFile), ...

The various topics are grouped into dedicated modules which can be imported into the global bash namespace at will.

A complete overview of the available list of modules and functions can be obtained from the [Documentation](#documentation).

## Table of contents

- [Installation](#installation)
  - [Functionality Tests](#functionality-tests)
- [Usage](#usage)
  - [Command-line](#command-line)
  - [Library](#library)
- [Documentation](#documentation)
- [Uninstall](#uninstall)
- [Copyright](#copyright)

## Installation

Check out a copy of the blib repository and then run the provided `installer` script, e.g.

```
git clone https://github.com/3hhh/blib.git
cd blib
sudo ./installer install
```

The default installation goes to `/usr/lib`, but you can choose a different prefix as installation parameter.

If you would like to generate the offline html, pdf and manpage [documentation](#documentation) as part of the installation, please install [pandoc](https://pandoc.org/) first. [pandoc](https://pandoc.org/) is available from the repositories of many operating systems. You may however also omit this step and re-run the documentation generation with `blib gendoc` at any later time.

blib requires bash version 4.2 or higher.

### Functionality Tests

After the installation it is recommended to make sure that all blib modules behave as expected on your system by running the unit tests shipped with blib:

```
blib test
```

This requires [bats](https://github.com/bats-core/bats-core) to be installed beforehand.

## Usage

blib is meant to be used as a bash library, but provides a few features on the command-line as well.

### Command-line

Run `blib` without any parameters to display its command-line help.

### Library

In order to import e.g. the functions of the `str` module to your bash namespace, simply execute the following at the top of your script:

```bash
source blib
b_import str
```

## Documentation

The blib code reference is available in many formats:

1. **Command-line**: `blib list` and `blib info [module]`
2. **Online**: (possibly outdated)
  * [Code Reference (html)](https://3hhh.github.io/blib-doc/blib.html)
  * [Code Reference (pdf)](https://3hhh.github.io/blib-doc/blib.pdf)
3. **Manpage**: `man blib` (requires [pandoc](https://pandoc.org/) during installation)
4. **Offline**: as `html` and `pdf` in `/usr/lib/blib/doc` (requires [pandoc](https://pandoc.org/) during installation)

## Uninstall

Use the installer script as follows:

```
cp /usr/lib/blib/installer /tmp/
cd /tmp/
sudo ./installer uninstall
rm /tmp/installer
```

If you didn't install to `/usr/lib`, you'll have to provide the installer script the location from which to uninstall.

## Copyright

© 2018 David Hobach

blib is released under the LGPLv3 license; see `LICENSE` for details.
