<p align="center">
  <img src="./logo/light.png" width="550"/>
</p>

<p align="center">
  <a title="'push' workflow Status" href="https://github.com/dbhi/qus/actions?query=workflow%3Apush"><img alt="'push' workflow Status" src="https://img.shields.io/github/workflow/status/dbhi/qus/push?longCache=true&style=flat-square&logo=github&label=push"></a><!--
  -->
  <a title="Build Status" href="https://travis-ci.com/dbhi/qus/builds"><img src="https://img.shields.io/travis/com/dbhi/qus/master.svg?longCache=true&style=flat-square&logo=travis-ci&logoColor=fff&label=travis"></a><!--
  -->
  <a title="Docker Hub" href="https://hub.docker.com/r/aptman/qus/"><img src="https://img.shields.io/docker/pulls/aptman/qus.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff&label=aptman%2Fqus"></a><!--
  -->
  <a title="Releases" href="https://github.com/dbhi/qus/releases"><img src="https://img.shields.io/github/commits-since/dbhi/qus/latest.svg?longCache=true&style=flat-square"></a>
</p>

*qemu-user-static* (**qus**) is a compilation of utilities, examples and references to build and execute OCI images (aka [docker](https://www.docker.com/) images) for foreign architectures using [QEMU](https://www.qemu.org/)'s user-mode emulation.

- Multiple minimal working setups to build and execute `arm64v8` containers on `amd64` are configured and tested on [GitHub Actions](https://github.com/dbhi/qus/actions) and on [Travis CI](https://travis-ci.com/dbhi/qus/builds). The full flow is public, for other users to learn and adapt these resources to their needs.
- Ready-to-use docker images are provided for each of seven host architectures officially supported by Docker, Inc. or built by official images ([docker-library/official-images: Architectures other than amd64?](https://github.com/docker-library/official-images#architectures-other-than-amd64)): `amd64`, `i386`, `arm64v8`, `arm32v7`, `arm32v6`, `s390x` and `ppc64le`.
- These resources are tested on GNU/Linux and Windows 10 (Docker Desktop). Contributions to test them on other host OSs are welcome!

# Overview

As explained at [qemu.org/download](https://www.qemu.org/download/), QEMU is packaged by most Linux distributions, so either of `qemu-user` or `qemu-user-static` can be installed through package managers. Furthermore, since `qemu-user-static` packages contain [statically built](https://en.wikipedia.org/wiki/Static_build) binaries, it is possible to extract them directly. Alternatively, QEMU can be built from sources.

Either of these allow to execute a binary for a foreign architecture by prepending the corresponding QEMU binary. E.g.:

``` bash
qemu-<arch>[-static] <binary>
```

Although straightforward to explicitly execute a few binaries, this is not practical in the context of docker images, because it would require dockerfiles and scripts to be modified. Fortunately, the Linux kernel has a capability named `binfmt_misc` which allows arbitrary executable file formats to be recognized and passed to certain applications. This is either done directly by sending special sequences to the register file in a special purpose file system interface (usually mounted under part of `/proc`), or using a wrapper (like Debian-based distributions) or systemd's `systemd-binfmt.service`.

When QEMU is installed from distribution package managers, it is normally set up along with `binfmt_misc`. Nonetheless, in the context of this project we want to configure it with custom options. A script provided by QEMU, [`qemu-binfmt-conf.sh`](https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh), can be used to do so. Precisely, [`register.sh`](./register.sh) is a wrapper around it, which provides some additional options.

Moreover, in version 4.8 of the kernel a new flag was added to the `binfmt` handlers. It allows to open the emulation binary when it is registered, so in future it is cloned from the open file. This is specially useful because it allows to work with foreign architecture containers without contaminating the container image. This flag is supported in `qemu-binfmt-conf.sh` as `-p`.

For further info, see:

- [Context](docs/context.md)
- [Tests](docs/tests.md)
- [Development](docs/dev.md)
- [Frequently Asked Questions](docs/faq.md)
- [References](docs/refs.md)

# Usage

> NOTE: Although `docker` is used in these examples, users have reported that other engines such as [podman](https://podman.io/) can also be used. See also [kata-containers/runtime#1280](https://github.com/kata-containers/runtime/issues/1280).

The recommended approach is to run the following container:

``` bash
docker run --rm --privileged aptman/qus -s -- -p [TARGET_ARCH]
```

> NOTE: since `aptman/qus` is a manifest, this command works on `amd64`, `arm64v8`, `arm32v7`, `arm32v6`, `i386`, `s390x` or `ppc64le` hosts.

The required `qemu-*-static` binaries (which are all included in the image) will be loaded and registered. The container will then exit. From there on, images and/or binaries for foreign architectures can be executed.

Optional argument `TARGET_ARCH` is the target architecture to be translated through QEMU. If it is omitted, all available targets will be registered and loaded. The supported values are the following:

```
i386 i486 alpha arm armeb sparc32plus ppc ppc64 ppc64le m68k mips mipsel mipsn32 mipsn32el mips64 mips64el sh4 sh4eb s390x aarch64 aarch64_be hppa riscv32 riscv64 xtensa xtensaeb microblaze microblazeel or1k x86_64
```

> NOTE: sudo privileges on the host are required in order to register `binfmt` formats.
> On GNU/Linux, it is possible to execute `register.sh` directly.
> On Windows, a container must be used, so that changes are applied to the underlying VM, since no kernel is available on the host.
> I.e., from the [test list](docs/tests.md), only `C`, `V`, `I` or `D` will work on Windows.

---

In order to unset the registered formats, and unload the binaries, run:

``` bash
docker run --rm --privileged aptman/qus -- -r
```

## Bandwidth-efficient procedure

In contexts such as CI pipelines it might be desirable to reduce the required bandwidth. Hence, instead of using `aptman/qus` images —which include all the binaries for all the supported target architectures—, individual tarballs are available through GitHub Releases. These can be used along with `aptman/qus:register` images or with [`register.sh`](./register.sh) (without an OCI runtime). See either `f`, `F`, `c`, `C`, `v` or `V` in the table below for examples of these use cases.

# Available docker images

Manifests for `amd64`, `arm64v8`, `arm32v7`, `arm32v6`, `i386`, `s390x` or `ppc64le` hosts:

- `aptman/qus:pkg`: all the `qemu-*-static` binaries from [packages.debian.org/sid/qemu-user-static](https://packages.debian.org/sid/qemu-user-static) extracted on a `scratch` image.
- `aptman/qus:register`: a `busybox` image with [`register.sh`](./register.sh) and [`qemu-binfmt-conf.sh`](https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh). The entrypoint is set to `register.sh`.
- `aptman/qus`: union of the two previous images.

## Debian [5.0]

For each `HOST_ARCH`, an image named `${HOST_ARCH}-d${VERSION}${TAG}` is published; where `TAG` is `-pkg, -register, ""`. Moreover, three manifests are available: `aptman/qus:d${VERSION}-pkg`, `aptman/qus:d${VERSION}-register` and `aptman/qus:d${VERSION}`.

> NOTE: latest/default versions above correspond to these Debian variants. Therefore, running `aptman/qus` on an `amd64` host is equivalent to running `aptman/qus:d5.0` or `aptman/qus:amd64-d5.0`.

Apart from those, `aptman/qus:mips-pkg` and `aptman/qus:mips64el-pkg` are also available.

## Fedora [4.2.0]

For each `HOST_ARCH` (except `arm32v6`), an image named `${HOST_ARCH}-f${VERSION}${TAG}` is published; where `TAG` is `-pkg, -register, ""`. Moreover, three manifests are available: `aptman/qus:f${VERSION}-pkg`, `aptman/qus:f${VERSION}-register` and `aptman/qus:f${VERSION}`.
