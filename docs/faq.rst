.. _qus:faq:

Frequently Asked Questions (FAQ)
################################

Does `qus` work for building images?
====================================

Yes, once the QEMU binary is configured/loaded, both building images and running containers is supported.

Do I need to install ``qemu-*-static`` on the host, even though it is only needed by the containers?
====================================================================================================

You can use static binaries at any location. So, you don't need to install all the ``qemu-*-static`` on the host. You just download the ones you want/need to a temporal folder. See cases ``c``, ``C``, ``v`` or ``V`` in :qussrc:`tests <tests.md>`.

It is still a downside that any other process in the host will use these binaries. However, the advantage is that you don't need to copy anything in the docker images. You can use them straight away. Furthermore, you can run multiple foreign containers with a single binary, instead of copying it to all the images.

If the container depends on a given minimum QEMU version, do I need to ensure that the host provides this version?
==================================================================================================================

You can put the ``qemu-*-static`` binaries of the version you want in a temporal folder on the host (and only for the foreign architectures you need). Then, temporally use those binaries system-wide, as commented above. When you are done, just reset the registered formats. See ``QEMU_BIN_DIR`` in register script.

How can I use ``qemu-*-static`` binaries without registering them with the *persistent* flag and without installing them in the container image?
================================================================================================================================================

If you don't use ``-p``, you can still share the binary/ies from the host with the containers. The advantages of this approach are that you can use a single binary for multiple containers, you can use the version of qemu that you want, and other processes on the host can use different versions of QEMU. The downside is that we don't know how to make it work with ``docker build`` yet. See cases ``v`` or ``V`` in `tests <tests.md>`__.

Moreover, the ``qemu-*-static`` binaries can be saved in a docker volume. This allows to avoid saving them on the host and to run multiple containers with ``--volumes-from``.

How can the scripts in aptman/qus be customized?
================================================

For testing purposes, it is possible to customize scripts ``register.sh`` or ``qemu-binfmt-conf.sh``, which are the default entrypoint in image aptman/qus. In order to do so, get a copy of any or both of them, and modify it locally. Then:

* Test that you can overwrite the copy inside the container with it:

  .. code-block:: sh

    $ docker run --rm --privileged -itv $(pwd)/qemu-binfmt-conf.sh:/qus/qemu-binfmt-conf.sh --entrypoint=sh aptman/qus
    # cat /qus/qemu-binfmt-conf.sh

* If successful, use it to run *regular* commands:

 .. code-block:: sh

   docker run --rm --privileged -v $(pwd)/qemu-binfmt-conf.sh:/qus/qemu-binfmt-conf.sh aptman/qus -s -- -p


For instance, this is used in `dbhi/qus#4 <https://github.com/dbhi/qus/issues/4>`__, to work around an upstream bug that prevents 32-bit ARM interpreters from being registered on 64-bit only ARM hosts.
