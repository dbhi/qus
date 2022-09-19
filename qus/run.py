#!/usr/bin/env python

# Copyright 2019-2022 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
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

from os import environ
from pathlib import Path
from subprocess import check_call
from sys import argv as sys_argv, stdout, stderr

from qus.config import Config

REPO = environ.get("REPO", "docker.io/aptman/qus")

if sys_argv[1] == "-m":
    arch_list = ["amd64", "arm64v8", "i386", "s390x", "ppc64le"]
    for build in ["latest", "debian", "fedora"]:
        isFedora = build == "fedora"
        isLatest = build == "latest"
        b_arch_list = arch_list + ([] if isFedora else ["arm32v6", "arm32v7"])

        version = ("f" if isFedora else "d") + Config().version("fedora" if isFedora else "debian", "amd64")[0]

        for image in ["latest", "pkg", "register"]:
            b_prefix = image if isLatest else ("" if image == "latest" else f"-{image}")
            manifest = f"{REPO}:{'' if isLatest else version}{b_prefix}"

            i_prefix = "" if image == "latest" else f"-{image}"
            image_list = [f"{REPO}:{arch}-{version}{i_prefix}" for arch in b_arch_list]

            print(f"[qus] Docker manifest {manifest}")
            print(f"[qus] Images:")
            print("\n".join(image_list))
            print("[qus] Create")
            stdout.flush()
            stderr.flush()
            check_call(["docker", "manifest", "create", "-a", manifest] + image_list)
            print("[qus] Push")
            check_call(["docker", "manifest", "push", "--purge", manifest])
            stdout.flush()
            stderr.flush()

else:

    ROOT = Path(__file__).resolve().parent.parent

    QUS_CLI = ROOT / "qus/cli.py"

    env = environ.copy()
    env.update(
        {
            "QUSCLI": QUS_CLI,
            "REPO": REPO,
            "HOST_ARCH": environ.get("HOST_ARCH", "x86_64"),
        }
    )

    check_call(
        f"""
set -e

. {ROOT / 'utils.sh'}

pkg_arch () {{
  {QUS_CLI} arch -u "$PKG_SOURCE" -a "$1"
}}

guest_arch() {{
  {QUS_CLI} arch -u qemu -a "$(pkg_arch ${{BASE_ARCH}})"
}}

"""
        + """

getSingleQemuUserStatic () {
  HARCH="$(pkg_arch ${HOST_ARCH})"
  GARCH="$(guest_arch)"
  case "$PKG_SOURCE" in
    fedora)
      URL="https://kojipkgs.fedoraproject.org/packages/qemu/${VERSION}/${SOURCE_VERSION}/${HARCH}/qemu-user-static-${VERSION}-${SOURCE_VERSION}.${HARCH}.rpm"
      echo "$URL"
      curl -fsSL "$URL" | rpm2cpio - | zstdcat | cpio -dimv "*usr/bin*qemu-${GARCH}-static"
      mv ./usr/bin/qemu-"${GARCH}"-static ./
      rm -rf ./usr/bin
    ;;
    debian)
      URL="http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}${SOURCE_VERSION}_${HARCH}.deb"
      echo "$URL"
      curl -fsSL "$URL" \
      | dpkg --fsys-tarfile - \
      | tar xvf - --wildcards ./usr/bin/qemu-"${GARCH}"-static --strip-components=3
    ;;
  esac
}

getAndRegisterSingleQemuUserStatic () {
  gstart "Get single qemu-user-static"
  getSingleQemuUserStatic
  gend

  gstart "Register binfmt interpreter for single qemu-user-static"
  $(command -v sudo) QEMU_BIN_DIR="$(pwd)" ./register.sh -- -r
  $(command -v sudo) QEMU_BIN_DIR="$(pwd)" ./register.sh -s -- -p "$(guest_arch)"
  gend

  gstart "List binfmt interpreters"
  $(command -v sudo) ./register.sh -l -- -t
  gend
}

build_register () {
  case "$BASE_ARCH" in
    amd64|arm64v8|arm32v7|arm32v6|i386|ppc64le|s390x)
      HOST_LIB="${BASE_ARCH}/"
    ;;
    *)
      HOST_LIB="skip"
  esac

  if [ -n "$CI" ]; then
    case "$BASE_ARCH" in
      arm64v8|arm32v7|arm32v6|ppc64le|s390x)
        getAndRegisterSingleQemuUserStatic
    esac
  fi

  [ "$HOST_LIB" = "skip" ] && {
    printf "$ANSI_YELLOW! Skipping creation of $IMG[-register] because HOST_LIB <$HOST_LIB>.$ANSI_NOCOLOR\n"
  } || {
    gstart "Build $IMG-register"
    docker build -t $IMG-register . -f-<<EOF
FROM ${HOST_LIB}busybox
#RUN mkdir /qus
ENV QEMU_BIN_DIR=/qus/bin
COPY ./register.sh /qus/register
ADD https://raw.githubusercontent.com/umarcor/qemu/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh /qus/qemu-binfmt-conf.sh
RUN chmod +x /qus/qemu-binfmt-conf.sh
ENTRYPOINT ["/qus/register"]
EOF
    gend

    gstart "Build $IMG"
    docker build -t $IMG . -f-<<EOF
FROM $IMG-register
COPY --from="$IMG"-pkg /usr/bin/qemu-* /qus/bin/
VOLUME /qus
EOF
    gend
  }
}

#--

build () {
  [ -d releases ] && rm -rf releases
  mkdir -p releases

  [ -d bin-static ] && rm -rf bin-static
  mkdir -p bin-static

  cd bin-static

  BARCH="$(pkg_arch ${BASE_ARCH})"

  case "$PKG_SOURCE" in
    fedora)
      PACKAGE_URI=${PACKAGE_URI:-https://kojipkgs.fedoraproject.org/packages/qemu/${VERSION}/${SOURCE_VERSION}/${BARCH}/qemu-user-static-${VERSION}-${SOURCE_VERSION}.${BARCH}.rpm}
      gstart "Extract $PACKAGE_URI"

      # https://bugzilla.redhat.com/show_bug.cgi?id=837945
      curl -fsSL "$PACKAGE_URI" | rpm2cpio - | zstdcat | cpio -dimv "*usr/bin*qemu-*-static"

      mv ./usr/bin/* ./
      rm -rf ./usr/bin
      gend
    ;;
    debian)
      PACKAGE_URI=${PACKAGE_URI:-http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}${SOURCE_VERSION}_${BARCH}.deb}
      gstart "Extract $PACKAGE_URI"
      curl -fsSL "$PACKAGE_URI" | dpkg --fsys-tarfile - | tar xvf - --wildcards ./usr/bin/qemu-*-static --strip-components=3
      gend
    ;;
  esac

  for F in $(ls); do
    tar -czf "../releases/${F}_${BASE_ARCH}.tgz" "$F"
  done

  case "$PKG_SOURCE" in
    fedora)
      IMG="${REPO}:${BASE_ARCH}-f${VERSION}"
    ;;
    debian)
      IMG="${REPO}:${BASE_ARCH}-d${VERSION}"
    ;;
  esac

  cd ..

  if [ -z "$QUS_RELEASE" ]; then
    gstart "Build $IMG-pkg"
    docker build -t "$IMG"-pkg ./bin-static -f-<<EOF
FROM scratch
COPY ./* /usr/bin/
EOF
    build_register
    gend
  fi
}

#--

assets() {
  ARCH_LIST="x86_64 i686 aarch64 ppc64le s390x"
  case "$BUILD" in
    fedora)
      ARCH_LIST="$ARCH_LIST armv7hl"
    ;;
    debian)
      ARCH_LIST="$ARCH_LIST armhf armel mipsel mips64el"
    ;;
  esac
  mkdir -p ../releases
  for BASE_ARCH in $ARCH_LIST; do
    gstart "Build $BASE_ARCH" "$ANSI_MAGENTA"
    unset PACKAGE_URI
    build_cfg
    build
    gend
    gstart "Copy $BASE_ARCH" "$ANSI_MAGENTA"
    cp -vr releases/* ../releases/
    gend
  done
  rm -rf releases
  mv ../releases ./
}

#--

build_cfg () {
  PKG_SOURCE=${BUILD:-debian}

  cliVersion="$("$QUSCLI" version -u "$PKG_SOURCE")"

  VERSION="${VERSION:-$(echo $cliVersion | cut -d " " -f1)}"
  SOURCE_VERSION=$(echo $cliVersion | cut -d " " -f2)

  BASE_ARCH="$("$QUSCLI" arch -a ${BASE_ARCH:-x86_64})"
}

#--

"""
        + f"""
case '{sys_argv[1]}' in
  -b)
    build_cfg
    build
  ;;
  -a)
    assets;
  ;;
  *)
    printf "${{ANSI_RED}}Unknown option '{sys_argv[1]}'!${{ANSI_NOCOLOR}}\n"
    exit 1
esac
""",
        env=env,
        shell=True,
        executable="/bin/bash",
        cwd=ROOT,
    )
