# Copyright 2020-2021 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from subprocess import check_call

from getter import Getter


def _check_call(cmd):
    print(cmd, flush=True)
    check_call(cmd, shell=True)


class Builder(Getter):
    """
    Build allows building qus docker images for native or foreign architectures.
    """

    def __init__(self, getter):
        super().__init__(getter._archs)

    def register_interpreter(self, host, target):
        """
        Register a foreign interpreter. To be used before building a foreign image.
        """
        print(
            "[Builder] register_interpreter %s %s" % (host, target),
            flush=True,
        )
        # TODO Now 'host' is ignored and an existing aptman/qus manifest is used
        # This should be optionally done through 'get_package_binaries'
        # getAndRegisterSingleQemuUserStatic
        _check_call("docker run --rm --privileged aptman/qus -s -- -p %s" % self.normalise_arch("qemu", target))

    def _image_name(self, source, host, repo):
        """
        Get normalised image name.
        """
        return "%s:%s-%s%s" % (
            repo,
            self.normalise_arch(None, host),
            source[0],
            self._version(source, host)[0],
        )

    def generate_pkg_image(self, source, host, repo):
        """
        Build qus:*-pkg image.
        """
        print(
            "[Builder] generate_pkg_image | source: %s | host: %s | repo: %s" % (source, host, repo),
            flush=True,
        )
        img = self._image_name(source, self.normalise_arch(None, host), repo) + "-pkg"
        print("[Builder] generate_pkg_image {}".format(img), flush=True)
        _check_call(
            """docker build -t '{}' ./bin-static -f-<<EOF
FROM scratch
COPY ./* /usr/bin/
EOF
""".format(
                img
            )
        )

    def generate_register_images(self, source, host, repo):
        """
        Build qus:*-register and qus:* images. Note that qus:* images depend on corresponding qus:*-pkg images.
        """
        print(
            "[Builder] generate_register_images | source: %s | host: %s | repo: %s" % (source, host, repo),
            flush=True,
        )
        arch = self.normalise_arch(None, host)
        img = self._image_name(source, arch, repo)
        print("[Builder] generate_register_images {}".format(img), flush=True)

        _check_call(
            """docker build -t '{0}' . -f-<<EOF
FROM {1}/busybox
ENV QEMU_BIN_DIR=/qus/bin
COPY ./register.sh /qus/register
ADD https://raw.githubusercontent.com/umarcor/qemu/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh /qus/qemu-binfmt-conf.sh
RUN chmod +x /qus/qemu-binfmt-conf.sh
ENTRYPOINT ["/qus/register"]
EOF
""".format(
                img + "-register", arch
            )
        )

        _check_call("docker images")

        _check_call(
            """docker build -t '{0}' . -f-<<EOF
FROM {0}-register
COPY --from={0}-pkg /usr/bin/qemu-* /qus/bin/
VOLUME /qus
EOF
""".format(
                img
            )
        )

        _check_call("docker run --rm --privileged '%s' -l -- -t" % img)
