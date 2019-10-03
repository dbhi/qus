# References

- [Wikipedia: Binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc)
- [KernelNewbies: Linux_4.8](https://kernelnewbies.org/Linux_4.8?highlight=%28binfmt%29)
- [lwn.net: Architecture emulation containers with binfmt_misc](https://lwn.net/Articles/679308/)
- [Commit by James Bottomley](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=948b701a607f123df92ed29084413e5dd8cda2ed)
- [Let's add Fedora multiarch containers to your CI](https://github.com/junaruga/fedora-workshop-multiarch/blob/master/slides/Lets-add-Fedora-multiarch-to-CI.pdf) is a talk by one of the maintainers of [multiarch/qemu-user-static](https://github.com/multiarch/qemu-user-static) that provides an introduction to contexts where these projects are useful.

> NOTE: there is some info about QEMU and Docker at [wiki.qemu.org/Testing/DockerBuild](https://wiki.qemu.org/Testing/DockerBuild). However, it is focused on building and testing QEMU itself, and details about how to set `binfmt` interpreters are not explained.

---

Despite the use cases in the following similar projects or blog posts being similar to the ones in *qus*, some enhancements/features are unique to *qus*:

- Optionally, limit the list of QEMU binaries to be registered on the host.
- Provide docker images for host architectures other than `amd64`.

## Blog posts

- [Travis with Docker and QEMU for multi-architecture CI workflow](https://developer.ibm.com/linuxonpower/2017/07/28/travis-multi-architecture-ci-workflow/)
- [ownyourbits.com](https://ownyourbits.com)
    - [Running and building ARM Docker containers in x86](https://ownyourbits.com/2018/06/27/running-and-building-arm-docker-containers-in-x86/)
    - [Transparently running binaries from any architecture in Linux with QEMU and binfmt_misc](https://ownyourbits.com/2018/06/13/transparently-running-binaries-from-any-architecture-in-linux-with-qemu-and-binfmt_misc/)

## Similar projects

### [multiarch/qemu-user-static](https://github.com/multiarch/qemu-user-static)

This is the most similar to *qus*. Script `register.sh` in *qus* was initially based on *multiarch*'s. Later, *qus* was used as a reference by *multiarch*, in order to implement *persistent* loading. The main difference is that *multiarch* does not provide images for host architectures other than `amd64`.

### [fkrull/docker-qemu-user-static](https://github.com/fkrull/docker-qemu-user-static/)

QEMU binaries are also loaded persistently. However, @fkrull uses some custom Python scripts, instead of relying on `qemu-binfmt-conf.sh`.

### [rmoriz/multiarch-test](https://github.com/rmoriz/multiarch-test)

Tries to fix [moby/moby#36552](https://github.com/moby/moby/issues/36552) in `hooks/build`, but we have not found that issue in this project yet.

### linuxkit/binfmt | docker/binfmt

Although not well documented, since version 1.13.0 (2017-01-19), QEMU is installed by default with Docker Desktop and a tool written in golang (named `binfmt`) is used to register interpreters in the kernel. The upstream project is [linuxkit/linuxkit](https://github.com/linuxkit/linuxkit), and the actual project from docker is [docker/binfmt](https://github.com/docker/binfmt).

For further details about similarities/differences, see:

- [docker/binfmt#17](https://github.com/docker/binfmt/issues/17)
- [linuxkit/linuxkit#3401](https://github.com/linuxkit/linuxkit/issues/3401)
