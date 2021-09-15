.. _qus:tests:

Tests
#####

Multiple alternatives exist to install QEMU, to register the interpreter and/or to use OCI containers. The table below summarizes all the combinations that are tested on CI services (GitHub Actions and Travis CI):

| Job | Register method       | -r | -s | -p | Dependecy          | Install method   | vol |
|:---:|:---------------------:|:--:|:--:|:--:|:------------------:|------------------|:---:|
|     | `aptman/qus`          | n  | y  | y  | -                  |                  | n   |
| f   | `register.sh`         | n  | y  | y  | `/usr/bin/$file`   | host  [curl]     | n   |
| F   | `aptman/qus:register` | n  | y  | y* | `/usr/bin/$file`   | host  [curl]     | n   |
| c   | `register.sh`         | n  | y  | y  | `$(pwd)/$file`     | host  [curl]     | n   |
| C   | `aptman/qus:register` | n  | y  | y* | `$(pwd)/$file`     | host  [curl]     | n   |
| v   | `register.sh`         | n  | y  | n  | `$(pwd)/$file`     | host  [curl]     | y   |
| V   | `aptman/qus:register` | n  | y  | n  | `$(pwd)/$file`     | host  [curl]     | y   |
| i   | `register.sh`         | n  | y  | n  | `$file`            | image [add/copy] | n   |
| I   | `aptman/qus:register` | n  | y  | n  | `$file`            | image [add/copy] | n   |
| d   | `register.sh`         | n  | y  | n  | `qemu-user`        | image [apt]      | n   |
| D   | `aptman/qus:register` | n  | y  | n  | `qemu-user`        | image [apt]      | n   |
| r   | `register.sh`         | y  | y  | y  | `qemu-user-static` | host  [apt]      | n   |
| R   | `aptman/qus:register` | y  | y  | y* | `qemu-user-static` | host  [apt]      | n   |
| s   | -                     | -  | -  | -  | `qemu-user-static` | host  [apt]      | y   |
| n   | -                     | -  | -  | -  | `qemu-user-binfmt` | host  [apt]      | -   |
| h   | `register.sh`         | y  | n  | y  | `qemu-user`        | host  [apt]      | n   |
| H   | `aptman/qus:register` | y  | n  | y* | `qemu-user`        | host  [apt]      | n   |

<aside>
`n` is about executing a binary on the host, not inside a container.
</aside>

where:

- `file` is the `qemu-*-static` binary corresponding to the target architecture. In these tests: `file=qemu-aarch64-static`.
- `-r|--clear|`: clean any registered `qemu-*` interpreter
- `-s|--static`: add `--suffix -static` to the args for `qemu-binfmt-conf.sh`
- `-p|--persistent`: if yes, the interpreter is loaded when `binfmt` is configured and remains in memory. All future uses are cloned from the open file.
- `vol`: whether the QEMU binary must be bind between the host and the container where target binaries are located. None of the methods with `vol=y` can be used for `docker build`.
