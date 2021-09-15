.. _qus:development:

Development
###########

## Continuous Integration/Delivery

Currently, two CI services are triggered after each push:

- GitHub Actions: docker images and manifests are built and pushed to the registry.
- Travis CI: on tagged commits, deb packages are extracted and artifacts are pushed to GitHub Releases.

Moreover, [tests](#tests) are executed on both services.

## Roadmap

- This project uses a modified `qemu-binfmt-conf.sh` script from [umarcor/qemu](https://github.com/umarcor/qemu/tree/series-qemu-binfmt-conf), which includes some enhancements. These patches have already been submitted upstream and will be hopefully included in future releases.

- *CLI*: apart from checking whether a new version is available upstream, the Python CLI tool (see [`cli`](https://(ref:repoTree)/cli)) can provide tables showing the available assets/packages. It would be interesting to add that info to the web site. On the other hand, builds and tests are currently written in [`run.sh`](https://(ref:repoTree)/run.sh). Ideally, those would be migrated/merge into the CLI tool.

- Deploy assets from GHA, instead of doing it from Travis.

- *Dropping the kernel dependency*: `sudo` privileges, which are required in order to register `binfmt` formats, are not available in all contexts^[See, for example, [play-with-docker/play-with-docker#276](https://github.com/play-with-docker/play-with-docker/issues/276).]. In [@angelatos15], an alternative to `binfmt` is proposed. However, this approach has not been implemented in this repo yet.
