.. |SHIELD:WorkflowTest| image:: https://img.shields.io/github/workflow/status/dbhi/qus/Test?longCache=true&style=flat-square&logo=github&label=Test
   :alt: 'Test' workflow Status
   :height: 22
   :target: https://github.com/dbhi/qus/actions?query=workflow%3ATest

.. |SHIELD:GitHubRepo| image:: https://img.shields.io/github/stars/dbhi/qus?longCache=true&style=flat-square&label=dbhi%2Fqus&logo=github&color=d45500
   :alt: 'dbhi/qus' GitHub repository
   :height: 22
   :target: https://github.com/dbhi/qus

.. |SHIELD:ContainerRegistri| image:: https://img.shields.io/docker/pulls/aptman/qus.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff&label=aptman%2Fqus
   :alt: Docker Hub
   :height: 22
   :target: https://hub.docker.com/r/aptman/qus/

.. |SHIELD:CommitsSince| image:: https://img.shields.io/github/commits-since/dbhi/qus/latest.svg?longCache=true&style=flat-square&logo=git&logoColor=fff
   :alt: Releases
   :height: 22
   :target: https://github.com/dbhi/qus/releases

.. |SHIELD:Citation| image:: https://img.shields.io/badge/-View%20citation%20file-555555?longCache=true&style=flat-square&logo=LaTeX&logoColor=fff
   :alt: Cite this project
   :height: 22
   :target: https://github.com/dbhi/qus/blob/main/CITATION.cff

.. |SHIELD:GitterRoom| image:: https://img.shields.io/badge/chat-on%20gitter-4db797.svg?longCache=true&style=flat-square&logo=gitter&logoColor=e8ecef
   :alt: Join the chat at gitter.im/hdl/community
   :height: 22
   :target: https://gitter.im/hdl/community

.. _qus:

qemu-user-static (qus) and containers
#####################################

.. only:: html

  |SHIELD:GitHubRepo|
  |SHIELD:ContainerRegistri|
  |SHIELD:CommitsSince|
  |SHIELD:Citation|
  |SHIELD:GitterRoom|      

.. raw:: html

  <hr>

.. image:: _static/logo/logo.png
   :width: 500 px
   :align: center
   :target: https://github.com/dbhi/qus

.. raw:: html

  <br>

Welcome to the Documentation of *qemu-user-static (qus) and containers*!
Build and execute OCI images for foreign architectures using QEMU's user-mode emulation.

*qus* is a compilation of utilities, examples and references to build and execute OCI images :cite:p:`opencontainers` (aka
Docker :cite:p:`docker` images) for foreign architectures, using QEMU's :cite:p:`bellard05` :cite:p:`qemu` user-mode emulation.

.. TIP::
  * **W** `Docker (software) <https://en.wikipedia.org/wiki/Docker_%28software%29>`__, `Open Container Initiative <https://en.wikipedia.org/wiki/Open_Container_Initiative>`__, `QEMU <https://en.wikipedia.org/wiki/QEMU>`__
  * **GH** `docker <https://github.com/docker>`__, `opencontainers <https://github.com/opencontainers>`__, `qemu <https://github.com/qemu>`__


Ready-to-use docker images are provided for each of seven host architectures officially supported by Docker, Inc. or built by official images :cite:p:`docker-official-images`: ``amd64``, ``i386``, ``arm64v8``, ``arm32v7``, ``arm32v6``, ``s390x`` and ``ppc64le``.

Multiple minimal working setups to build and execute ``arm64v8`` containers on ``amd64`` are configured and tested on Continuous Integration (CI) services (GitHub Actions :cite:p:`gha`). The full flow is public, for other users to learn and adapt these resources to their needs. See `github.com/dbhi/qus/actions <https://github.com/dbhi/qus/actions>`__.

.. TIP::
  * **W** `Continuous integration <https://en.wikipedia.org/wiki/Continuous_integration>`__ `GitHub · GitHub.com <https://en.wikipedia.org/wiki/GitHub#GitHub.com>`__, `Travis CI <https://en.wikipedia.org/wiki/Travis_CI>`__

  * |SHIELD:WorkflowTest|

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
   references

