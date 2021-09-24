.. _qus:images:

Provided container images
#########################

When QEMU is installed from distribution package managers, it is normally set up along with `binfmt_misc`.
Nonetheless, in the context of this project we want to configure it with custom options, instead of relying on the defaults. A script provided by QEMU, `qemu-binfmt-conf.sh <https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh>`__, can be used to do so. Among other options, the flag that tells `binfmt` to hold interpreters in memory is supported in `qemu-binfmt-conf.sh` as `-p`.

This project uses a modified version of ``qemu-binfmt-conf.sh`` [#f1]_, which includes the following enhancements:


- Optionally, the list of QEMU interpreters to be registered on the host can be limited.
- Add option ``--clear``.
- Add option ``--test``.

.. TIP::
  These patches have already been submitted upstream and will be hopefully included in future releases.


In fact, the entrypoint to the following docker images is a wrapper [#f2]_ around ``qemu-binfmt-conf.sh`` to provide some synctactic sugar.

Manifests
=========

Manifests are provided for the following hosts: ``amd64``, ``arm64v8``, ``arm32v7``, ``arm32v6``, ``i386``, ``s390x`` or ``ppc64le``. That is, any of the target architectures provided by QEMU can be used on any of those hosts.

The procedure to generate each image involves extracting pre-built binaries and packaging them in container images,
along with helper scripts. Hence, multiple images are generated in the process:

.. TIP:: 
  Find usage instructions in the `README <https://github.com/dbhi/qus/tree/main#usage>`__.


- ``aptman/qus:pkg``: all the ``qemu-*-static`` binaries from `packages.debian.org/sid/qemu-user-static <https://packages.debian.org/sid/qemu-user-static>`__ extracted on a ``scratch`` image.
- ``aptman/qus:register``: a ``busybox`` image with `register.sh <./register.sh>`__ and `qemu-binfmt-conf.sh <https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh>`__. The entrypoint is set to ``register.sh``.
- ``aptman/qus``: union of the two previous images.

Debian [5.0]
============

For each ``HOST_ARCH``, an image named ``${HOST_ARCH}-d${VERSION}${TAG}`` is published; where ``TAG`` is ``-pkg|-register|""``. Moreover, three manifests are available: ``aptman/qus:d${VERSION}-pkg``, ``aptman/qus:d${VERSION}-register`` and ``aptman/qus:d${VERSION}``.

.. TIP::
  ``latest``/default versions above correspond to these Debian variants. Therefore, running ``aptman/qus`` on an 
  ``amd64`` host is equivalent to running ``aptman/qus:d5.0`` or ``aptman/qus:amd64-d5.0``.


Apart from those, ``aptman/qus:mips-pkg`` and ``aptman/qus:mips64el-pkg`` are also available.

Fedora [5.0.0]
==============

For each ``HOST_ARCH`` (except ``arm32v6``), an image named ``${HOST_ARCH}-f${VERSION}${TAG}`` is published; where ``TAG`` is ``-pkg|-register|""``. Moreover, three manifests are available: ``aptman/qus:f${VERSION}-pkg``, ``aptman/qus:f${VERSION}-register`` and ``aptman/qus:f${VERSION}``.

.. [#f1] See `umarcor/qemu: series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh <https://github.com/umarcor/qemu/blob/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh>`__.

.. [#f2] See :qussrc:`register.sh <register.sh>`.