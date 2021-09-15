.. _qus:

qemu-user-static (qus) and containers
#####################################

.. raw:: html

    <p style="text-align: center;">
      <a
        title="'dbhi/qus' GitHub repository"
        href="https://github.com/dbhi/qus"
      ><img
        src="https://img.shields.io/github/stars/dbhi/qus?longCache=true&style=flat-square&label=dbhi%2Fqus&logo=github&color=d45500"
        data-external="1"
      ></a><!--
      -->
      <a
        title="Docker Hub"
        href="https://hub.docker.com/r/aptman/qus/"
      ><img
        src="https://img.shields.io/docker/pulls/aptman/qus.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff&label=aptman%2Fqus"
        data-external="1"
      ></a><!--
      -->
      <a
        title="Releases"
        href="https://github.com/dbhi/qus/releases"
      ><img
        src="https://img.shields.io/github/commits-since/dbhi/qus/latest.svg?longCache=true&style=flat-square&logo=git&logoColor=fff"
        data-external="1"
      ></a><!--
      -->
      <a
        title="Cite this project"
        href="https://github.com/dbhi/qus/blob/main/CITATION.cff"
      ><img
        src="https://img.shields.io/badge/-View%20citation%20file-555555?longCache=true&style=flat-square&logo=LaTeX&logoColor=fff"
        data-external="1"
      ></a><!--
      -->
      <a
        title="Join the chat at https://gitter.im/hdl/community"
        href="https://gitter.im/hdl/community"
      ><img
        src="https://img.shields.io/badge/chat-on%20gitter-4db797.svg?longCache=true&style=flat-square&logo=gitter&logoColor=e8ecef"
      ></a><!--
      -->
    </p>

    <hr>

.. image:: _static/logo/logo.png
   :width: 500 px
   :align: center
   :target: https://github.com/dbhi/qus

.. raw:: html

    <br>

Welcome to the Documentation of *qemu-user-static (qus) and containers*!
Build and execute OCI images for foreign architectures using QEMU's user-mode emulation.

*qus* is a compilation of utilities, examples and references to build and execute OCI images [@opencontainers] (aka
Docker [@docker] images) for foreign architectures, using QEMU's [@bellard05] [@qemu] user-mode emulation.

.. TIP::
  * **W** [Docker (software)](https://en.wikipedia.org/wiki/Docker_%28software%29), [Open Container Initiative](https://en.wikipedia.org/wiki/Open_Container_Initiative), [QEMU](https://en.wikipedia.org/wiki/QEMU)
  * **GH** [docker](https://github.com/docker), [opencontainers](https://github.com/opencontainers), [qemu](https://github.com/qemu)


Ready-to-use docker images are provided for each of seven host architectures officially supported by Docker, Inc. or built by official images [@docker-official-images]: `amd64`, `i386`, `arm64v8`, `arm32v7`, `arm32v6`, `s390x` and `ppc64le`.

Multiple minimal working setups to build and execute `arm64v8` containers on `amd64` are configured and tested on Continuous Integration (CI) services (GitHub Actions [@gha]). The full flow is public, for other users to learn and adapt these resources to their needs. See [github.com/dbhi/qus/actions](https://github.com/dbhi/qus/actions).

.. TIP::
  * **W** [Continuous integration](https://en.wikipedia.org/wiki/Continuous_integration) [GitHub · GitHub.com](https://en.wikipedia.org/wiki/GitHub#GitHub.com), [Travis CI](https://en.wikipedia.org/wiki/Travis_CI)

  * <a
    title="'Test' workflow Status"
    href="https://github.com/dbhi/qus/actions?query=workflow%3ATest"
  ><img
    alt="'Test' workflow Status"
    src="https://img.shields.io/github/workflow/status/dbhi/qus/Test?longCache=true&style=flat-square&logo=github&label=Test"
    data-external="1"
  ></a>

These resources are tested on GNU/Linux and Windows 10 (Docker Desktop). Contributions to test them on other host OSs are welcome!

.. toctree::
   :hidden:

   intro
   context
   images
   tests
   development
   faq
   related
