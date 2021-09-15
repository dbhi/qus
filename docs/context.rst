.. _qus:context:

Context: containers and QEMU
############################

> [[wikipedia: Docker_(software)](https://en.wikipedia.org/wiki/Docker_(software))]
>
> Docker is a computer program that performs operating-system-level virtualization, also known as "containerization". (..) Containers are (software packages) isolated from each other and bundle their own application, tools, libraries and configuration files; (...) All containers are run by a single operating-system kernel and are thus more lightweight than virtual machines.
>
> Docker (...) uses the resource isolation features of the Linux kernel such as cgroups and kernel namespaces, and a union-capable file system such as OverlayFS and others to allow independent "containers" to run within a single Linux instance, avoiding the overhead of starting and maintaining virtual machines (VMs). The Linux kernel's support for namespaces mostly isolates an application's view of the operating environment, including process trees, network, user IDs and mounted file systems, while the kernel's cgroups provide resource limiting for memory and CPU.

> [[wikipedia: QEMU](https://en.wikipedia.org/wiki/QEMU)]
>
> QEMU (short for Quick Emulator) is a free and open-source emulator that performs hardware virtualization. (...) it emulates the machine's processor through dynamic binary translation and provides a set of different hardware and device models for the machine, enabling it to run a variety of guest operating systems. It also can be used with KVM to run virtual machines at near-native speed (by taking advantage of hardware extensions such as Intel VT-x). QEMU can also do emulation for user-level processes, allowing applications compiled for one architecture to run on another.

The main issue to underline is that QEMU provides multiple operating modes: [full-system emulation](https://qemu.weilnetz.de/doc/qemu-doc.html#QEMU-System-emulator-for-non-PC-targets), [user-mode emulation](https://qemu.weilnetz.de/doc/qemu-doc.html#QEMU-User-space-emulator) and [virtualization](https://wiki.qemu.org/Features/KVM). Some of them allow dynamic binary translation of the instruction set, endianness and 32/64 bit mismatches. Besides, some focus on isolation between the host and the guest, and/or on performance.

Virtualization and full-system emulation (when the guest architecture is the same as the host's) are similar to docker containers, but each machine runs it's own kernel while containers use/share the kernel of the host. This has been addressed from different perspectives. For example, the content of a docker image can extracted and used in a QEMU machine [@rottenkolber15]. Conversely, a QEMU image in QCOW2 format can be converted to a docker image [@golfayi]. Furthermore, approaches such as Kata Containers [@katacontainers] provide alternative runtimes for docker to seamlessly bring the best of both: execute containers on top of QEMU virtualization.

Unfortunately, virtualization of foreign architectures is not supported^[See [wiki.qemu.org: Features/KVM](https://wiki.qemu.org/Features/KVM).], so it is out of the scope of Kata Containers for now^[See [kata-containers/runtime#1280](https://github.com/kata-containers/runtime/issues/1280).]. As a result, execution of docker containers on a qemu-system VM requires the user to learn how to handle images, launch options and communication between the host and the VM. For example, in [@taylor16], an image for RPi is created. On the one hand, the process requires manual steps (although it can be probably automated as in [rouault/gdal_coverage: .travis.yml](https://github.com/rouault/gdal_coverage/blob/freebsd9.2/.travis.yml) from [@rouault16]). On the other hand, the execution command is not friendly for new users: `qemu-system-arm -kernel raspberry-qemu/kernel-qemu -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" -net user,hostfwd=tcp::10022-:22 -net nic -display none -hda 2015-11-21-raspbian-jessie-lite.img`. Moreover, that example does not consider the execution of docker, which is the target of this project.

<aside>
Contributions of example scripts to automatically provision QEMU images for some known SBC (such as [PYNQ](http://www.pynq.io/board.html), [Raspberry Pi](https://www.raspberrypi.org/), [96boards.org](https://www.96boards.org/), [Pine64](https://www.pine64.org), etc.) allowing running docker images, are welcome! Please [open a pull request](https://github.com/dbhi/qus/compare).
</aside>

Alternatively, in user-mode emulation, QEMU runs a program for another Linux/BSD on any supported architecture. System calls are thunked for endianness and for 32/64 bit mismatches, so that the program is executed as any other application on the host.

It is to be noted that user-mode emulation has three main caveats. First, user-mode emulation seems to be less polished than full-system emulation, so it might crash if non-supported features are used [@voipio17]. Second, because the underlying machine is the host, there is no emulated kernel and hardware resources specific to the target device/system are not available (unlike in a fully-featured VM). Third, there is no isolation between the program and the host, so malicious programs can gain privileges.

Nevertheless, within its contraints, it is a very valuable solution for cross-building and executing foreign docker images. This is specially so in free/public CI environments, because most provides do not support native architectures others than x86-64. Hence, QEMU allows to build, for instance, docker images for Raspberry Pi in GitHub Actions. Precisely, *qus* is used in dbhi/docker [@dbhi-docker] to build multiarch images (for `arm32v7`, `arm64v8` and `amd64`). Moreover, since 2017, QEMU is installed and enabled by default with Docker Desktop^[See [linuxkit/binfmt | docker/binfmt](#linuxkitbinfmt-dockerbinfmt) below.]; thus, features equivalent to a subset of what *qus* provides are available off the shelf on Windows and macOS. Regarding isolation, the fact that programs are executed inside docker containers does allow to partially restrict the programs^[See [docs.docker.com: Docker security](https://docs.docker.com/engine/security/security/) and [mviereck/x11docker: Security](https://github.com/mviereck/x11docker#security)].

Summarizing, this repository is focused on alternatives to configure and use QEMU in user-mode emulation mode. Nonetheless, we are open to contributions of examples with system-mode emulation.

As explained at [qemu.org/download](https://www.qemu.org/download/), QEMU is packaged by most Linux distributions, so either of `qemu-user` or `qemu-user-static` can be installed through package managers. Furthermore, since `qemu-user-static` packages contain statically built binaries, it is possible to extract them directly. That is, to retrieve pre-built packages, extract the desired binary, and copy it to the development workstation. Alternatively, QEMU can be built from sources.

<aside>
**W** [Static build](https://en.wikipedia.org/wiki/Static_build)
</aside>

Either of the installation procedures allows to execute a binary for a foreign architecture by prepending the corresponding QEMU executable. E.g.:

``` bash
qemu-<arch>[-static] <binary>
```

This procedure is straightforward for explicitly executing a few binaries. However, it is not practical in the context of docker images, because it would require dockerfiles and scripts to be modified ad-hoc. Fortunately, the Linux kernel has a capability named `binfmt_misc` which allows arbitrary executable file formats to be transparently recognized and passed to certain applications [@bottomley16] [@corbet16]. This is configured either by directly sending special sequences to the register file in a special purpose file system interface (usually mounted under part of `/proc`), or using a wrapper (like Debian-based distributions) or systemd's `systemd-binfmt.service`.

<aside>
**W** [binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc)
</aside>

Moreover, in version 4.8 of the kernel a new flag was added to the `binfmt` handlers [@kernelnewbies]. It allows to open the emulation binary when it is registered, so in future it is cloned from the open file. This is specially useful because it allows to work with foreign architecture containers without contaminating the container image.
