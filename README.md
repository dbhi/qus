# **qemu-user-static (qus) and docker**

<p align="center">
  <img src="./logo/light.png" width="550"/>
</p>

<p align="center">
  <a title="Build Status" href="https://travis-ci.com/umarcor/qus/builds"><img src="https://img.shields.io/travis/com/umarcor/qus/master.svg?longCache=true&style=flat-square&logo=travis-ci&logoColor=fff&label=qus"></a><!--
  -->
  <a title="Docker Hub" href="https://hub.docker.com/r/aptman/qus/"><img src="https://img.shields.io/docker/pulls/aptman/qus.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff&label=aptman%2Fqus"></a><!--
  -->
  <a title="Releases" href="https://github.com/umarcor/qus/releases"><img src="https://img.shields.io/github/commits-since/umarcor/qus/latest.svg?longCache=true&style=flat-square"></a>
</p>

---

This repository contains utilities, examples and references to build and execute [Docker](https://www.docker.com/) images for foreign architectures using [QEMU](https://www.qemu.org/)'s user-mode emulation. Multiple minimal working and non-working setups to build and execute `arm64v8` containers on `x86-64` are configured and tested on [Travis CI](https://travis-ci.com/), so that the full flow is public. Moreover, three complementary docker images are provided for each of seven host architectures officially supported by Docker, Inc. or built by official images ([docker-library/official-images: Architectures other than amd64?](https://github.com/docker-library/official-images#architectures-other-than-amd64)): `amd64`, `i386`, `arm64v8`, `arm32v7`, `arm32v6`, `s390x` and `ppc64le`.

## Overview

As explained at [qemu.org/download](https://www.qemu.org/download/), QEMU is packaged by most Linux distributions, so either of `qemu-user` or `qemu-user-static` can be installed through package managers. Furthermore, since `qemu-user-static` packages contain [statically built](https://en.wikipedia.org/wiki/Static_build) binaries, it is possible to extract them directly. Alternatively, it can be built from sources.

Either of these allow to execute a binary for a foreign architecture by prepending the corresponding QEMU binary. E.g.:

``` bash
qemu-<arch>[-static] <binary>
```

Even though this is straighforward to explicitly execute a few binaries, it is not practical in the context of docker images, because it would require dockerfiles and scripts to be modified. Fortunately, the Linux kernel has a capability named `binfmt_misc` which allows arbitrary executable file formats to be recognized and passed to certain applications. This is either done directly by sending special sequences to the register file in a special purpose file system interface (usually mounted under part of `/proc`), or using a wrapper (like Debian-based distributions) or systemd's `systemd-binfmt.service`.

When QEMU is installed from distribution package managers, it is normally set up along with `binfmt_misc`. Nonetheless, in the context of this project we want to configure it with custom options. A script provided by QEMU, [`qemu-binfmt-conf.sh`](https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh), can be used to do so. Precisely, [`register.sh`](./register.sh) is a wrapper around it, which provides some additional options.

Moreover, in version 4.8 of the kernel a new flag was added to the `binfmt` handlers. It allows to open the emulation binary when it is registered, so in future it is cloned from the open file. This is specially useful because it allows to work with foreign architecture containers without contaminating the container image. This flag is supported in `qemu-binfmt-conf.sh` as `-p`.

For further info, see:

- [Wikipedia: Binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc)
- [KernelNewbies: Linux_4.8](https://kernelnewbies.org/Linux_4.8?highlight=%28binfmt%29)
- [lwn.net: Architecture emulation containers with binfmt_misc](https://lwn.net/Articles/679308/)
- [Commit by James Bottomley](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=948b701a607f123df92ed29084413e5dd8cda2ed)

> NOTE: this project uses a modified `qemu-binfmt-conf.sh` script from [umarcor/qemu](https://github.com/umarcor/qemu/tree/feat-qemu-binfmt-conf), which includes some additional features, such as `-r|--clear`. These patches have already been pushed upstream, so they will be included in future releases. Therefore, this project will be updated accordingly in the following weeks/months.

## Usage

The recommended approach is to run the following container:

``` bash
docker run --rm --privileged aptman/qus -s -- -p [TARGET_ARCH]
```

The required `qemu-*-static` binaries (which are all included in the image) will be loaded and registered. The container will then exit. From there on, binaries for foreign architectures can be executed.

Optional argument `TARGET_ARCH` is the target architecture to be translated through QEMU. If it is omitted, all available targets will be registered and loaded. The supported values are the following:

```
i386 i486 alpha arm armeb sparc32plus ppc ppc64 ppc64le m68k mips mipsel mipsn32 mipsn32el mips64 mips64el sh4 sh4eb s390x aarch64 aarch64_be hppa riscv32 riscv64 xtensa xtensaeb microblaze microblazeel or1k x86_64
```

> NOTE: sudo privileges on the host are required in order to register `binfmt` formats.
> On GNU/Linux, it is possible to execute `register.sh` directly.
> On Windows, a container must be used, so that changes are applied to the underlying VM, since no kernel is available on the host.
> I.e., from the test list below, only `C`, `V`, `I` or `D` will work on Windows.

> NOTE: `aptman/qus` is a manifest, so the commans below will work on `amd64`, `arm64v8`, `arm32v7`, `arm32v6`, `i386`, `s390x` or `ppc64le` hosts.

---

In order to unset the registered formats, and unload the binaries, run:

``` bash
docker run --rm --privileged aptman/qus -- -r
```

### Bandwidth-efficient procedure

In contexts such as CI services it might be desirable to reduce the required bandwidth. Hence, instead of using `aptman/qus` images —which include all the binaries for all the supported target architectures—, individual tarballs are available through GitHub Releases. These can be used along with `aptman/qus:register` images or with [`register.sh`](./register.sh). See either `f`, `F`, `c`, `C`, `v` or `V` in the table below for examples of these use cases.

## Available docker images

Manifests for `amd64`, `arm64v8`, `arm32v7`, `arm32v6`, `i386`, `s390x` or `ppc64le` hosts:

- `aptman/qus:pkg`: all the `qemu-*-static` binaries from [packages.debian.org/sid/qemu-user-static](https://packages.debian.org/sid/qemu-user-static) extracted on a `scratch` image.
- `aptman/qus:register`: a `busybox` image with [`register.sh`](./register.sh) and [`qemu-binfmt-conf.sh`](https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh). The entrypoint is set to `register.sh`.
- `aptman/qus`: union of the two previous images.

Apart from those, `aptman/qus:mips-pkg` and `aptman/qus:mips64el-pkg` are also available.

## Tests

| Job | Register method       | -r | -s | -p | Dependecy          | Install method   | vol |
|:---:|:---------------------:|:--:|:--:|:--:|:------------------:|------------------|:---:|
|     | `aptman/qus`          | n  | y  | y  | -                  |                  | n   |
| f   | `register.sh`         | n  | y  | y  | `/usr/bin/$file`   | host  [curl]     | n   |
| F   | `aptman/qus:register` | n  | y  | y* | `/usr/bin/$file`   | host  [curl]     | n   |
| c   | `register.sh`         | n  | y  | y  | `$(pwd)/$file`     | host  [curl]     | n   |
| C   | `aptman/qus:register` | n  | y  | y* | `$(pwd)/$file`     | host  [curl]     | n   |
| v   | `register.sh`         | n  | y  | n  | `$(pwd)/$file`     | host  [curl]     | y   |
| V   | `aptman/qus:register` | n  | y  | n  | `$(pwd)/$file`     | host  [curl]     | y   |
| i   | `register.sh`         | n  | y  | n  | `$file`            | image [add/copy] | n   |
| I   | `aptman/qus:register` | n  | y  | n  | `$file`            | image [add/copy] | n   |
| d   | `register.sh`         | n  | y  | n  | `qemu-user`        | image [apt]      | n   |
| D   | `aptman/qus:register` | n  | y  | n  | `qemu-user`        | image [apt]      | n   |
| r   | `register.sh`         | y  | y  | y  | `qemu-user-static` | host  [apt]      | n   |
| R   | `aptman/qus:register` | y  | y  | y* | `qemu-user-static` | host  [apt]      | n   |
| s   | -                     | -  | -  | -  | `qemu-user-static` | host  [apt]      | y   |
| n   | -                     | -  | -  | -  | `qemu-user-binfmt` | host  [apt]      | -   |
| h   | `register.sh`         | y  | n  | y  | `qemu-user`        | host  [apt]      | n   |
| H   | `aptman/qus:register` | y  | n  | y* | `qemu-user`        | host  [apt]      | n   |

where:

- `file` is the `qemu-*-static` binary corresponding to the target architecture. In these tests: `file=qemu-aarch64-static`.
- `-r|--clear|`: clean any registered `qemu-*` interpreter
- `-s|--static`: add `--suffix -static` to the args for `qemu-binfmt-conf.sh`
- `-p|--persistent`: if yes, the interpreter is loaded when `binfmt` is configured and remains in memory. All future uses are cloned from the open file.
- `vol`: whether the QEMU binary must be bind between the host and the container where target binaries are located. None of the methods with `vol=y` can be used for `docker build`.

> NOTE: `n` is about executing a binary on the host, not inside a container.

## Similar projects, blog posts and other references

> NOTE: there is some info about QEMU and Docker at [wiki.qemu.org/Testing/DockerBuild](https://wiki.qemu.org/Testing/DockerBuild). However, it is focused on building and testing QEMU itself, and details about how to set `binfmt` interpreters are not explained.

The use cases in the following references are similar to the ones in this project:

- [multiarch/qemu-user-static](https://github.com/multiarch/qemu-user-static)
- [Travis with Docker and QEMU for multi-architecture CI workflow](https://developer.ibm.com/linuxonpower/2017/07/28/travis-multi-architecture-ci-workflow/)
- [ownyourbits.com](https://ownyourbits.com)
    - [Running and building ARM Docker containers in x86](https://ownyourbits.com/2018/06/27/running-and-building-arm-docker-containers-in-x86/)
    - [Transparently running binaries from any architecture in Linux with QEMU and binfmt_misc](https://ownyourbits.com/2018/06/13/transparently-running-binaries-from-any-architecture-in-linux-with-qemu-and-binfmt_misc/)
- [rmoriz/multiarch-test](https://github.com/rmoriz/multiarch-test). It tries to fix [moby/moby#36552](https://github.com/moby/moby/issues/36552) in `hooks/build`, but we have not found that issue in this project yet.
- [fkrull/docker-qemu-user-static](https://github.com/fkrull/docker-qemu-user-static/) is probably the most similar to this project, because QEMU binaries are also loaded persistently. However, @fkrull uses some custom Python scripts, instead of relying on `qemu-binfmt-conf.sh`.

The main enhancements provided by *qus* are the following:

- Do not require the addition of any binary to the docker images.
- Optionally, limit the list of QEMU binaries to be registered on the host.
- Provide docker images for host architectures other than `amd64`.

## Dropping the kernel dependency

Sudo privileges, which are required in order to register `binfmt` formats, are not available in all contexts. See, for example, [play-with-docker/play-with-docker#276](https://github.com/play-with-docker/play-with-docker/issues/276). In [balena.io/blog: Building ARM containers on any x86 machine, even DockerHub](https://www.balena.io/blog/building-arm-containers-on-any-x86-machine-even-dockerhub/), an alternative to `binfmt` is proposed. However, this approach has not been implemented in this repo yet.