The main purpose of this repository is raising awareness about a technical solution that exists. Therefore, it is the intent of the author to make sources reusable with minimal legal constraints:

- Both Docker and QEMU are independent third-party projects which are explicitly licensed.
- The custom `qemu-binfmt-conf.sh` used in this project (see [umarcor/qemu: scripts/qemu-binfmt-conf.sh](https://github.com/umarcor/qemu/blob/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh)) has been proposed upstream (see [:patchew](https://patchew.org/search?q=project%3AQEMU+qemu-binfmt-conf.sh)); hence, it is licensed as specified by QEMU.
- Other shell scripts and local Python package [cli](cli) are licensed under [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
- The [documentation](docs) can be quoted/copied for fair-use and cited in academic contexts. Apart from that, it is licensed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
- CI workflow files are *just the most obvious implementation*; thus, free to be used, remixed, transformed and built upon for any purpose, even commercially.

Should you be unsure about reusing some piece of this project, please [raise an issue](https://github.com/dbhi/qus/issues).
