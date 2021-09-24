.. _qus:intro:

Introduction
############

The widespread adoption of single-board computers (SBCs), along with the evolution of FPGAs into complex system on chip (SoC) circuits with Linux-capable hard CPUs, has increased the demand of (cross-)compiling and testing strategies for applications targeting architectures other than ``x86``/``x86-64``/``amd64``. Apart from the most known `Raspberry Pi <https://www.raspberrypi.org/>`__ and other similar low-cost devices, many actual SoCs with a programmable region [#f1]_ (PR) include multi-core ARM subsystems. Nonetheless, since devices for embedded applications are typically less powerful than regular workstations, it is common to develop applications on ``x86-64`` and then deploy/use them on the target devices.

.. TIP::
  **W** `Single-board computer <https://en.wikipedia.org/wiki/Single-board_computer>`__, 
  `System on a chip <https://en.wikipedia.org/wiki/System_on_a_chip>`__, 
  `Raspberry Pi <https://en.wikipedia.org/wiki/Raspberry_Pi>`__


The traditional approach involves installing cross-compilation toolchains on the workstation. However, cross-platform packages pollute the development environment, and might need to be built from sources. In order to reduce the burden of setting up and maintaining a development environment up to date, packaging solutions are used. The most known environment packaging solution are Virtual Machines (VMs), which effectively emulate full machines (from hardware to system libraries, including the kernel). Yet, using VMs might be overkill for developing user-space applications. On the other hand, containers :cite:p:`opencontainers` :cite:p:`docker` are a mechanism to package system and user libraries only, while using the hardware (including the kernel) of the host. In behalf of containers reducing both the setup and startup burden, most used distributions (busybox, ubuntu, centos, debian, fedora, alpine, opensuse, etc.) are already available :cite:p:`docker-official-images` as Docker images for architectures such as ARM, s390x or PPC.

.. TIP::
  Note that naming of ARM architectures is not consistent: ARM (Armv7, Armv8, AArch32, AArch64...), Docker (arm32v7,
  arm64v8...), Debian (armel, armhf, aarch64...), Fedora (armv7hl, aarch64...). In this document, all of them are used 
  equally. See functions ``pkg_arch`` and ``guest_arch`` in :qussrc:`run.sh <run.sh>` for details about equivalencies.


Unfortunately, due to containers reusing the kernel of the host, images for foreign architectures cannot be executed on a regular container runtime. Trying to do so will likely produce the same error as executing any foreign binary directly on the host. Thankfully, QEMU :cite:p:`qemu` can emulate a foreign architectures through dynamic binary modification/translation (DBM). Thus, it can translate foreign instructions/signals for the kernel to understand them, and vice versa. On that account, the purpose of this repository and this article is to document how to use OCI containers along with QEMU.

The remainder of the document is organized as follows. In the next two sections, QEMU's different operating modes are explained, and the images generated and published by the author are described. Then, the test suite that allows to continuously check the whole set of images is explained. Thereupon, development details are provided. There is also a section about frequently asked questions. Last, references to related blog posts and similar projects are listed.

.. TIP::
  **W** `Binary translation <https://en.wikipedia.org/wiki/Binary_translation>`__


.. [#f1] *Programmable Region* is a term used by `Xilinx <https://www.xilinx.com/>`__ to refer to the reconfigurable part of their SoCs. The PR is commonly referred to as *FPGA* for historical reasons.