# Development

## Continuous Integration/Delivery

Currently, two CI services are triggered after each push:

- GitHub Actions: docker images and manifests are built and pushed to the registry.
- Travis CI: on tagged commits, deb packages are extracted and artifacts are pushed to GitHub Releases.

Moreover, [tests](tests.md) are executed in both services.

## Roadmap

> NOTE: this project uses a modified `qemu-binfmt-conf.sh` script from [umarcor/qemu](https://github.com/umarcor/qemu/tree/series-qemu-binfmt-conf), which includes some additional features, such as `-r|--clear`. These patches have already been submitted upstream and will be hopefully included in future releases. This project will be updated accordingly in the following months.

### Dropping the kernel dependency

Sudo privileges, which are required in order to register `binfmt` formats, are not available in all contexts. See, for example, [play-with-docker/play-with-docker#276](https://github.com/play-with-docker/play-with-docker/issues/276). In [balena.io/blog: Building ARM containers on any x86 machine, even DockerHub](https://www.balena.io/blog/building-arm-containers-on-any-x86-machine-even-dockerhub/), an alternative to `binfmt` is proposed. However, this approach has not been implemented in this repo yet.
