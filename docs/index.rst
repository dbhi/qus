.. |SHIELD:WorkflowTest| image:: https://img.shields.io/github/workflow/status/dbhi/qus/Test?longCache=true&style=flat-square&logo=github&label=Test
   :alt: 'Test' workflow Status
   :height: 22
   :target: https://github.com/dbhi/qus/actions?query=workflow%3ATest

.. |SHIELD:GitHubRepo| image:: https://img.shields.io/github/stars/dbhi/qus?longCache=true&style=flat-square&label=dbhi%2Fqus&logo=github&color=d45500
   :alt: 'dbhi/qus' GitHub repository
   :height: 22
   :target: https://github.com/dbhi/qus

.. |SHIELD:ContainerRegistry| image:: https://img.shields.io/docker/pulls/aptman/qus.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff&label=aptman%2Fqus
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

  .. centered::
    |SHIELD:GitHubRepo|
    |SHIELD:ContainerRegistry|
    |SHIELD:CommitsSince|
    |SHIELD:Citation|
    |SHIELD:GitterRoom|
    |SHIELD:WorkflowTest|

.. image:: _static/logo/logo.png
   :width: 500 px
   :align: center
   :target: https://github.com/dbhi/qus

.. raw:: html

  <br>

Welcome to the Documentation of *qemu-user-static and containers (qus)*!
Build and execute `OCI <https://opencontainers.org/>`__ images for foreign architectures using `QEMU <https://www.qemu.org/>`__'s
user-mode emulation.

*qus* is a compilation of utilities, examples and references to build and execute OCI images :cite:p:`opencontainers` :cite:p:`w:opencontainers` :cite:p:`gh:opencontainers` (aka
Docker :cite:p:`docker` :cite:p:`w:docker` :cite:p:`gh:docker` images) for foreign architectures, using QEMU's
:cite:p:`bellard05` :cite:p:`qemu` :cite:p:`w:qemu` user-mode emulation.

Ready-to-use docker images are provided for each of seven host architectures officially supported by Docker, Inc. or
built by official images :cite:p:`docker-official-images`:

* **amd64**
* **i386**
* **arm64v8**
* **arm32v7**
* **arm32v6**
* **s390x**
* **ppc64le**

Multiple minimal working setups to build and execute ``arm64v8`` containers on ``amd64`` are configured and tested on
Continuous Integration (CI) :cite:p:`w:continuousintegration` services (GitHub Actions :cite:p:`gha` :cite:p:`w:github`).
The full flow is public, for other users to learn and adapt these resources to their needs.
See `github.com/dbhi/qus/actions <https://github.com/dbhi/qus/actions>`__.

These resources are tested on GNU/Linux and Windows 10 (Docker Desktop).
Contributions to test them on other host OSs are welcome!

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
