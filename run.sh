#!/usr/bin/env bash

# Copyright 2019-2021 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
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

set -e

cd $(dirname $0)

QUSCLI="$(pwd)/cli/cli.py"

. ./utils.sh

#--

pkg_arch () {
  "$QUSCLI" arch -u "$PKG_SOURCE" -a "$1"
}

guest_arch() {
  "$QUSCLI" arch -u qemu -a "$(pkg_arch ${BASE_ARCH})"
}

#--

getDEB () {
  URL="http://ftp.debian.org/debian/pool/main/q/qemu/${1}_${VERSION}${SOURCE_VERSION}_${2}.deb"
  echo "$URL"
  curl -fsSL "$URL" \
  | dpkg --fsys-tarfile - \
  | tar xf - --wildcards "${3}" --strip-components=3
}

getSingleQemuUserStatic () {
  HARCH="$(pkg_arch ${HOST_ARCH})"
  GARCH="$(guest_arch)"
  case "$PKG_SOURCE" in
    fedora)
      URL="https://kojipkgs.fedoraproject.org/packages/qemu/${VERSION}/${SOURCE_VERSION}/${HARCH}/qemu-user-static-${GARCH}-${VERSION}-${SOURCE_VERSION}.${HARCH}.rpm"
      echo "$GARCH on $HARCH [$URL]"
      curl -fsSL "$URL" | rpm2cpio - | zstdcat | cpio -dimv "*usr/bin*qemu-${GARCH}-static"
      mv ./usr/bin/qemu-"${GARCH}"-static ./
      rm -rf ./usr/bin
    ;;
    debian)
      getDEB qemu-user        "$HARCH" "./usr/bin/qemu-${GARCH}"
      getDEB qemu-user-static "$HARCH" "./usr/bin/qemu-${GARCH}-static"
      [ -e "qemu-${GARCH}-static" ] || mv "qemu-${GARCH}" "qemu-${GARCH}-static"
      rm -rf ./usr/bin
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

build_images () {
  TARGET_PLATFORM="$(target_platform "$BASE_ARCH")"
  HOST_LIB="$(host_lib "$BASE_ARCH")"

  if [ -n "$CI" ]; then
    case "$BASE_ARCH" in
      arm64v8|arm32v7|arm32v6|ppc64le|s390x)
        getAndRegisterSingleQemuUserStatic
    esac
  fi

  for target in pkg register final; do
    [ "$target" != "pkg" ] && [ -z "$HOST_LIB" ] && {
      printf "$ANSI_YELLOW! Skipping creation of $IMG[-$target]; unsupported HOST_ARCH <$BASE_ARCH>.$ANSI_NOCOLOR\n"
      continue
    }

    if [ "$target" = "final" ]; then
      TAG="$IMG"
    else
      TAG="$IMG-$target"
    fi

    [ -n "$TARGET_PLATFORM" ] && PLATFORM="--platform=$TARGET_PLATFORM" || PLATFORM=""

    gstart "Build $TAG"
    docker build $PLATFORM \
      --build-arg HOST_LIB="$HOST_LIB" \
      --build-arg TARGET_PLATFORM="$TARGET_PLATFORM" \
      -t "$TAG" --target="$target" \
      -f qus.dockerfile \
      .
    gend
  done
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
      for TARCH in \
        aarch64 \
        alpha \
        arm \
        hexagon \
        hppa \
        loongarch64 \
        m68k \
        microblaze \
        mips \
        or1k \
        ppc \
        riscv \
        s390x \
        sh4 \
        sparc \
        x86 \
        xtensa;
      do
        PACKAGE_URI=https://kojipkgs.fedoraproject.org/packages/qemu/${VERSION}/${SOURCE_VERSION}/${BARCH}/qemu-user-static-${TARCH}-${VERSION}-${SOURCE_VERSION}.${BARCH}.rpm
        gstart "Extract $TARCH $PACKAGE_URI"
        curl -fsSL "$PACKAGE_URI" | rpm2cpio - | zstdcat | cpio -dimv "*usr/bin*qemu-*-static"
        mv ./usr/bin/* ./
        rm -rf ./usr/bin/
        gend
      done
    ;;
    debian)
      PACKAGE_URI=${PACKAGE_URI:-http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}${SOURCE_VERSION}_${BARCH}.deb}
      gstart "Extract $PACKAGE_URI"
      getDEB qemu-user        "$BARCH" "./usr/bin/qemu-*"
      getDEB qemu-user-static "$BARCH" "./usr/bin/qemu-*-static"
      for f in qemu-*; do
        [ "$f" = "${f%-static}" ] || continue
        [ -e "${f}-static" ] || ln -s "$f" "${f}-static"
      done
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
    build_images
  fi
}

#--

manifests () {
  for BUILD in latest debian fedora; do
    case "$BUILD" in
      debian|latest)
        usage="debian"
      ;;
      fedora)
        usage="fedora"
      ;;
    esac
    DEF_VERSION=$("$QUSCLI" version -u "$usage" | cut -d " " -f1)

    MAN_ARCH_LIST="amd64 arm64v8 s390x"
    case "$BUILD" in
      fedora)
        MAN_VERSION="f${DEF_VERSION}"
      ;;
      debian|latest)
        MAN_VERSION="d${DEF_VERSION}"
        MAN_ARCH_LIST="$MAN_ARCH_LIST i386 arm32v6 arm32v7 ppc64le"
      ;;
    esac
    case "$BUILD" in
      latest)
        unset MAN_IMG_VERSION
      ;;
      debian|fedora)
        MAN_IMG_VERSION="$MAN_VERSION"
      ;;
    esac

    for i in latest pkg register; do
      #[ "$i" == "latest" ] && p="latest" || p="$i"

      [ "x$MAN_IMG_VERSION" != "x" ] && p="-$i" || p="$i"
      if [ "x$MAN_IMG_VERSION" != "x" ] && [ "x$i" = "xlatest" ]; then
        p=""
      fi

      MAN_IMG="${REPO}:${MAN_IMG_VERSION}${p}"

      [ "$i" == "latest" ] && p="" || p="-$i"
      unset cmd
      for arch in $MAN_ARCH_LIST; do
        cmd="$cmd ${REPO}:${arch}-${MAN_VERSION}${p}"
      done

      gstart "Docker manifest create $MAN_IMG"
      docker manifest create -a $MAN_IMG $cmd
      gend

      gstart "Docker manifest push $MAN_IMG"
      docker manifest push --purge "$MAN_IMG"
      gend
    done

  done
}

#--

assets() {
  ARCH_LIST="x86_64 aarch64 ppc64le s390x"
  case "$BUILD" in
    fedora)
    ;;
    debian)
      ARCH_LIST="$ARCH_LIST i686 armhf armel"
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

target_platform () {
  case "$1" in
    amd64)    echo "linux/amd64" ;;
    i386)     echo "linux/386" ;;
    arm64v8)  echo "linux/arm64" ;;
    arm32v7)  echo "linux/arm/v7" ;;
    arm32v6)  echo "linux/arm/v6" ;;
    ppc64le)  echo "linux/ppc64le" ;;
    s390x)    echo "linux/s390x" ;;
  esac
}

host_lib () {
  case "$1" in
    amd64|arm64v8|arm32v7|arm32v6|i386|ppc64le|s390x)
      echo "$1/"
    ;;
  esac
}

#--

REPO=${REPO:-docker.io/aptman/qus}
HOST_ARCH=${HOST_ARCH:-x86_64}

case "$1" in
  -b)
    build_cfg
    build
  ;;
  -m)
    manifests
  ;;
  -a)
    assets;
  ;;
  *)
    printf "${ANSI_RED}Unknown option '$1'!${ANSI_NOCOLOR}\n"
    exit 1
esac
