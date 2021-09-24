.. _qus:tests:

Tests
#####

Multiple alternatives exist to install QEMU, to register the interpreter and/or to use OCI containers. The table below summarizes all the combinations that are tested on CI services (GitHub Actions and Travis CI):

.. exec::
  from table import TestsTable
  TestsTable()

.. TIP::
  ``n`` is about executing a binary on the host, not inside a container.


where:

* ``file`` is the ``qemu-*-static`` binary corresponding to the target architecture. In these tests: ``file=qemu-aarch64-static``.
* ``-r|--clear|``: clean any registered ``qemu-*`` interpreter.
* ``-s|--static``: add ``--suffix -static`` to the args for ``qemu-binfmt-conf.sh``.
* ``-p|--persistent``: if yes, the interpreter is loaded when ``binfmt`` is configured and remains in memory. All future uses are cloned from the open file.
* ``vol``: whether the QEMU binary must be bind between the host and the container where target binaries are located. None of the methods with ``vol=y`` can be used for ``docker build``.
