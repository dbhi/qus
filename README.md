# **qemu-user-static (qus) and docker**

<p align="center">
  <img src="./logo/light.png" width="550"/>
</p>

<p align="center">
  <a title="Build Status" href="https://travis-ci.com/umarcor/qus/builds"><img src="https://img.shields.io/travis/com/umarcor/qus/qus.svg?longCache=true&style=flat-square&logo=travis-ci&logoColor=fff&label=qus"></a><!--
  -->
  <a title="Docker Hub" href="https://hub.docker.com/r/aptman/qus/"><img src="https://img.shields.io/docker/pulls/aptman/qus.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff&label=aptman%2Fqus"></a><!--
  -->
  <a title="Releases" href="https://github.com/umarcor/qus/releases"><img src="https://img.shields.io/github/commits-since/umarcor/qus/latest.svg?longCache=true&style=flat-square"></a>
</p>

---

This repository contains utilities, examples and references to build and execute [Docker](https://www.docker.com/) images for foreign architectures using [QEMU](https://www.qemu.org/)'s user-mode emulation. Multiple minimal working and non-working setups to build and execute `arm64v8` containers on `x86-64` are configured and tested on [Travis CI](https://travis-ci.com/), so that the full flow is public. Moreover, three complementary docker images are provided for each of seven host architectures officially supported by Docker, Inc. or built by official images ([docker-library/official-images: Architectures other than amd64?](https://github.com/docker-library/official-images#architectures-other-than-amd64)): `amd64`, `i386`, `arm64v8`, `arm32v7`, `arm32v6`, `s390x` and `ppc64le`.

## Overview

As explained at [qemu.org/download](https://www.qemu.org/download/), QEMU is packaged by most Linux distributions, so either of `qemu-user` or `qemu-user-static` can be installed through package managers. Furthermore, since `qemu-user-static` packages contain [statically built](https://en.wikipedia.org/wiki/Static_build) binaries, it is possible to extract them directly.
Alternatively, it can be built from sources.

Either of these allow to execute a binary for a foreign architecture by prepending the corresponding QEMU binary. E.g.:

``` bash
qemu-<arch>-user <binary>
```

Even though this is straighforward to explicitly execute a few binaries, it is not practical in the context of docker images, because it would require dockerfiles and scripts to be modified. Fortunately, the Linux kernel has a capability named `binfmt_misc` which allows arbitrary executable file formats to be recognized and passed to certain applications. This is either done directly by sending special sequences to the register file in a special purpose file system interface (usually mounted under part of `/proc`), or using a wrapper (like Debian-based distributions) or systemd's `systemd-binfmt.service`.

When QEMU is installed from distribution package managers, it is normally set up along with `binfmt_misc`. Nonetheless, in the context of this project we want to configure it with custom options. A script provided by QEMU, [`qemu-binfmt-conf.sh`](https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh), can be used to do so. Precisely, [`register.sh`](./register.sh) is a wrapper around it, which provides some additional options.

Moreover, in version 4.8 of the kernel a new flag was added to the binfmt handlers. It allows to open the emulation binary when it is registered, so in future it is cloned from the open file. This is specially useful because it allows to work with foreign architecture containers without contaminating the container image. This flag is supported in `qemu-binfmt-conf.sh` as `-p yes`.

For further info, see:

- [Wikipedia: Binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc)
- [KernelNewbies: Linux_4.8](https://kernelnewbies.org/Linux_4.8?highlight=%28binfmt%29)
- [lwn.net: Architecture emulation containers with binfmt_misc](https://lwn.net/Articles/679308/)
- [Commit by James Bottomley](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=948b701a607f123df92ed29084413e5dd8cda2ed)

## Usage

The recommended approach is to run the following container:

``` bash
docker run --rm --privileged aptman/qus [--targets <target_archs>] -s -- -p yes
```

The required `qemu-*-static` binaries (which are all included in the image) will be loaded and registered. The container will then exit. From there on, binaries for foreign architectures can be executed.

Optional argument `--target <target_archs` is a comma separated list of target architectures to be translated through QEMU. If it is omitted, all available targets will be registered and loaded. The supported values are the following:

```
i386 i486 alpha arm armeb sparc32plus ppc ppc64 ppc64le m68k mips mipsel mipsn32 mipsn32el mips64 mips64el sh4 sh4eb s390x aarch64 aarch64_be hppa riscv32 riscv64 xtensa xtensaeb microblaze microblazeel or1k x86_64
```

> NOTE: sudo privileges on the host are required in order to register `binfmt` formats.

> NOTE: `aptman/qus` is a manifest, so the commans below will work on `amd64`, `arm64v8`, `arm32v7`, `arm32v6`, `i386`, `s390x` or `ppc64le` hosts.

---

In order to unset the registered formats, and unload the binaries, run:

``` bash
docker run --rm --privileged aptman/qus -r
```

### Bandwidth-efficient procedure

In contexts such as CI services it might be desirable to reduce the required bandwidth. Hence, instead of using `aptman/qus` images —which include all the binaries for all the supported target architectures—, individual tarballs are available through GitHub Releases. These can be used along with `aptman/qus:register` images or with [`register.sh`](./register.sh).
