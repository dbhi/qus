# From [multiarch/qemu-user-static#37](https://github.com/multiarch/qemu-user-static/issues/37#issuecomment-465126390)

> @stefanklug:
> Using the -p flag. For this to work I ensure all qemu-xxx-static live in /usr/bin on the host machine. After calling `docker run --rm --privileged --name qemu multiarch/qemu-user-static:register --reset -p`, all binfmts are registered and the F flag is set. From now on every xxx app in an container is served using the qemu-xxx-static from the host.

Did you actually try this? I found it necessary to:

- Set `-p yes`. `-p` alone won't work.
- Add `-v=/usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static` so that binaries are found in the container.

> NOTE: I believe that it can be improved to share a single dir with all the `qemu-*-static` binaries.

---

> @stefanklug:
> This has two downsides:
>        * The need to install the qemu-xxx-static on the host, albeit these are only needed by the containers

You can use exactly the same binaries that you would put inside the container. So, you don't need to install all the `qemu-*-static` on the host. You just download the ones you want/need to a temporal folder. In [travis-ci.com/1138-4EB/test-qemu](https://travis-ci.com/1138-4EB/test-qemu/builds/101445338) only `qemu-aarch64-static` is downloaded and registered (see FIX and MULTILIB_FIX).

It is still a downside that any other process in the host will use these binaries. However, the advantage is that you don't need to copy anything in the docker images. You can use them straighaway. Furthermore, you can run multiple foreign containers with a single binary, instead of copying it to all the images.

>        * If the container depends on a given minimum qemu version (i.e. I saw instabilities with some older aarch64 versions) I need to ensure the host provides this version. This breaks encapsulation which is the main purpose of containers

You can put the `qemu-*-static` binaries of the version you want in a temporal folder on the host (and only for the foreign architectures you need). Then, temporally use those binaries system-wide, as commented above. When you are done, just reset the registered formats. See `QEMU_BIN_DIR` in register script.

---

>     2. Not using the -p flag. In this case `docker run --rm --privileged --name qemu multiarch/qemu-user-static:register --reset`just registers the binfmts in the kernel, no F flag and loading the interpreter happens at runtime in container space. **Now every container has to provide its own /usr/bin/qemu-xxx-static**.

If you don't use `-p`, you can still share the binary/ies from the host with the containers. See MULTILIB_VOLUME in [travis-ci.com/1138-4EB/test-qemu](https://travis-ci.com/1138-4EB/test-qemu/builds/101445338). The advantages of this approach are that you can use a single binary for multiple containers, you can use the version of qemu that you want, and other processes on the host can use different versions of qemu. The downside is that I don't know how to make it work with `docker build`.

Moreover, the `qemu-*-static` binaries can be saved in a docker volume. This allows to avoid saving them on the host. But it also allows to run multiple containers with `--volumes-from`.

> This is nice as it provides full encapsulation, but raises the question where to get the correct qemu-xxx-static for the container. I thought that was the main reason for the multiarch/qemu-user-static:x86_64-xxx containers.

It seems that the latest [qemu-user-static](https://apps.fedoraproject.org/packages/qemu-user-static/#) from Fedora is used (see [.travis.yml#L8](https://github.com/multiarch/qemu-user-static/blob/master/.travis.yml#L8) and [.travis.yml#L14-L16](https://github.com/multiarch/qemu-user-static/blob/master/.travis.yml#L14-L16)). However, I am unsure about what's the difference between `qemu-*` and `x86_64_qemu-*` as it seems that they should be the same (see [publish.sh#L24-L29](https://github.com/multiarch/qemu-user-static/blob/master/publish.sh#L24-L29)), but sizes do not match.
