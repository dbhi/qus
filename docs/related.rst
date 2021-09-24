.. _qus:related:

Other related sources
#####################

Some of these projects were developed in parallel to *qus*, and there has been feedback; so, some features and use cases are equivalent. Currently, the enhancements which might be unique to *qus* are 1) providing docker images for host architectures other than ``amd64``; and 2) optionally, limiting the list of QEMU binaries to be registered on the host.

.. TIP::
  There is some info about QEMU and Docker at 
  `wiki.qemu.org/Testing/DockerBuild <https://wiki.qemu.org/Testing/DockerBuild>`__. 
  However, it is focused on building and testing QEMU itself, and details about how to set 
  ``binfmt`` interpreters are not explained.


`multiarch/qemu-user-static <https://github.com/multiarch/qemu-user-static>`__
==============================================================================

This is the most similar to *qus*. Script ``register.sh`` in *qus* was initially based on *multiarch*'s. Later, *qus* was used as a reference by *multiarch*, in order to implement *persistent* loading. The main difference is that *multiarch* does not provide images for host architectures other than ``amd64``.

:cite:p:`aruga19` is a talk by one of the maintainers of `multiarch/qemu-user-static <https://github.com/multiarch/qemu-user-static>`__ that provides an introduction to contexts where these projects are useful.
See also :cite:p:`pradipta17`.

`fkrull/docker-qemu-user-static <https://github.com/fkrull/docker-qemu-user-static/>`__
=======================================================================================

QEMU binaries are also loaded persistently. However, *fkrull* uses some custom Python scripts, instead of relying on ``qemu-binfmt-conf.sh``.

`rmoriz/multiarch-test <https://github.com/rmoriz/multiarch-test>`__
====================================================================

Tries to fix `moby/moby#36552 <https://github.com/moby/moby/issues/36552>`__ in 
``hooks/build``, but we have not found that issue in this project yet.

.. _qus:related:linuxkit:

linuxkit/binfmt | docker/binfmt
===============================

Although not well documented, since version 1.13.0 (2017-01-19), QEMU is installed by default with Docker Desktop and a tool written in golang (named ``binfmt``) is used to register interpreters in the kernel. The upstream project is `linuxkit/linuxkit <https://github.com/linuxkit/linuxkit>`__.

For further details about similarities/differences, see:

* The project from docker (`docker/binfmt <https://github.com/docker/binfmt>`__) was deprecated in favour of `github.com/linuxkit/linuxkit/tree/master/pkg/binfmt <https://github.com/linuxkit/linuxkit/tree/master/pkg/binfmt>`__.

  * `docker/binfmt#17 <https://github.com/docker/binfmt/issues/17>`__

* `linuxkit/linuxkit#3401 <https://github.com/linuxkit/linuxkit/issues/3401>`__
* `moby/qemu <https://github.com/moby/qemu>`__

At DockerCon San Francisco 2019, a partnership with Arm was announced: `Building Multi-Arch Images for Arm and x86 with Docker Desktop <https://www.docker.com/blog/multi-arch-images/>`__.

Blog posts
==========

* `ownyourbits.com <https://ownyourbits.com>`__
  
  * `Running and building ARM Docker containers in x86 <https://ownyourbits.com/2018/06/27/running-and-building-arm-docker-containers-in-x86/>`__
 
  * `Transparently running binaries from any architecture in Linux with QEMU and binfmt_misc <https://ownyourbits.com/2018/06/13/transparently-running-binaries-from-any-architecture-in-linux-with-qemu-and-binfmt_misc/>`__
