# Musl Libc with Program Repository Support

This git repository contains a copy of musl libc (forked from [musl-libc@`cfdfd5ea`](http://git.musl-libc.org/cgit/musl/commit/?id=cfdfd5ea3ce14c6abf7fb22a531f3d99518b5a1b) with work-in-progress modifications to output to a Program Repository.

Our approach here will be to [port musl libc](http://wiki.musl-libc.org/wiki/Porting) to the [program repository](https://github.com/SNSystems/llvm-project-prepo).

## Build musl-libc with the Program Repository Compiler

First create the [llvm-prepo container](https://hub.docker.com/r/paulhuggett/llvm-prepo), then use the following series of commands to install various third-party tools on which the build depends.
```
sudo apt-get update
sudo apt-get install -y git python ninja-build
```
Clone the musl-prepo project via:
```
git clone --depth=1 https://github.com/MaggieYingYi/musl-prepo.git
```
Then configure via:
```
./configure --disable-shared --prefix=~/musl
```
Perform the build of musl-prepo.
```
make -j 8
```
Finally, install musl-prepo.
```
make install
```

# Musl Libc

    musl libc

musl, pronounced like the word "mussel", is an MIT-licensed
implementation of the standard C library targetting the Linux syscall
API, suitable for use in a wide range of deployment environments. musl
offers efficient static and dynamic linking support, lightweight code
and low runtime overhead, strong fail-safe guarantees under correct
usage, and correctness in the sense of standards conformance and
safety. musl is built on the principle that these goals are best
achieved through simple code that is easy to understand and maintain.

The 1.1 release series for musl features coverage for all interfaces
defined in ISO C99 and POSIX 2008 base, along with a number of
non-standardized interfaces for compatibility with Linux, BSD, and
glibc functionality.

For basic installation instructions, see the included INSTALL file.
Information on full musl-targeted compiler toolchains, system
bootstrapping, and Linux distributions built on musl can be found on
the project website:

    http://www.musl-libc.org/
