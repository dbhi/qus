#!/usr/bin/env bash

set -e

cd $(dirname $0)

export DOCKER_BUILDKIT=1

#--

enable_color() {
  ENABLECOLOR='-c '
  ANSI_RED="\033[31m"
  ANSI_GREEN="\033[32m"
  ANSI_YELLOW="\033[33m"
  ANSI_BLUE="\033[34m"
  ANSI_MAGENTA="\033[35m"
  ANSI_GRAY="\033[90m"
  ANSI_CYAN="\033[36;1m"
  ANSI_DARKCYAN="\033[36m"
  ANSI_NOCOLOR="\033[0m"
}

disable_color() { unset ENABLECOLOR ANSI_RED ANSI_GREEN ANSI_YELLOW ANSI_BLUE ANSI_MAGENTA ANSI_CYAN ANSI_DARKCYAN ANSI_NOCOLOR; }

enable_color

print_start() {
  if [ "x$2" != "x" ]; then
    COL="$2"
  elif [ "x$BASE_COL" != "x" ]; then
    COL="$BASE_COL"
  else
    COL="$ANSI_MAGENTA"
  fi
  printf "${COL}${1}$ANSI_NOCOLOR\n"
}

gstart () {
  print_start "$@"
}
gend () {
  :
}

if [ -n "$GITHUB_EVENT_PATH" ]; then
  export CI=true
fi

[ -n "$CI" ] && {
  gstart () {
    printf '::[group]'
    print_start "$@"
    SECONDS=0
  }

  gend () {
    duration=$SECONDS
    echo '::[endgroup]'
    printf "${ANSI_GRAY}took $(($duration / 60)) min $(($duration % 60)) sec.${ANSI_NOCOLOR}\n"
  }
} || echo "INFO: not in CI"

#--

pkg_arch () {
  case "$BUILD_ARCH" in
    fedora)
      case "$1" in
        amd64)
          echo x86_64 ;;
        i386)
          echo i686 ;;
        arm64v8)
          echo aarch64 ;;
        arm32v7)
          echo armv7hl ;;
        ppc64*)
          echo ppc64le ;;
        *)
          echo "$1"
      esac
    ;;
    debian)
      case "$1" in
        x86_64)
          echo amd64 ;;
        arm64v8)
          echo arm64 ;;
        arm32v7)
          echo armhf ;;
        arm32v6|arm32v5)
          echo armel ;;
        ppc64*)
          echo ppc64el ;;
        *)
          echo "$1"
      esac
    ;;
  esac
}

guest_arch() {
  case "$1" in
   amd64)
     echo x86_64 ;;
   arm64)
     echo aarch64 ;;
   armhf|armel|armv7hl)
     echo arm ;;
   ppc64*)
     echo ppc64le ;;
   *)
     echo "$1"
  esac
}

#--

getSingleQemuUserStatic () {
  case "$BUILD_ARCH" in
    fedora)
      URL="https://kojipkgs.fedoraproject.org/packages/qemu/${VERSION}/${FEDORA_VERSION}/$(pkg_arch ${HOST_ARCH})/qemu-user-static-${VERSION}-${FEDORA_VERSION}.$(pkg_arch ${HOST_ARCH}).rpm"
      echo "$URL"
      curl -fsSL "$URL" | rpm2cpio - | zstdcat | cpio -dimv "*usr/bin*qemu-$(guest_arch $(pkg_arch ${BASE_ARCH}))-static"
      mv ./usr/bin/qemu-$(guest_arch $(pkg_arch ${BASE_ARCH}))-static ./
      rm -rf ./usr/bin
    ;;
    debian)
      URL="http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}${DEBIAN_VERSION}_$(pkg_arch ${HOST_ARCH}).deb"
      echo "$URL"
      curl -fsSL "$URL" \
      | dpkg --fsys-tarfile - \
      | tar xvf - --wildcards ./usr/bin/qemu-$(guest_arch $(pkg_arch ${BASE_ARCH}))-static --strip-components=3
    ;;
  esac
}

getAndRegisterSingleQemuUserStatic () {
  print_start "Get single qemu-user-static"
  getSingleQemuUserStatic

  print_start "Register binfmt interpreter for single qemu-user-static"
  $(command -v sudo) QEMU_BIN_DIR="$(pwd)" ./register.sh -- -r
  $(command -v sudo) QEMU_BIN_DIR="$(pwd)" ./register.sh -s -- -p "$(guest_arch $(pkg_arch $BASE_ARCH))"

  print_start "List binfmt interpreters"
  $(command -v sudo) ./register.sh -l -- -t
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
    print_start "Build $IMG-register"
    docker build -t $IMG-register . -f-<<EOF
FROM ${HOST_LIB}busybox
#RUN mkdir /qus
ENV QEMU_BIN_DIR=/qus/bin
COPY ./register.sh /qus/register
ADD https://raw.githubusercontent.com/umarcor/qemu/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh /qus/qemu-binfmt-conf.sh
RUN chmod +x /qus/qemu-binfmt-conf.sh
ENTRYPOINT ["/qus/register"]
EOF

    print_start "Build $IMG"
    docker build -t $IMG . -f-<<EOF
FROM $IMG-register
COPY --from="$IMG"-pkg /usr/bin/qemu-* /qus/bin/
VOLUME /qus
EOF
  }
}

#--

build () {
  [ -d releases ] && rm -rf releases
  mkdir -p releases

  [ -d bin-static ] && rm -rf bin-static
  mkdir -p bin-static

  cd bin-static

  case "$BUILD_ARCH" in
    fedora)
      PACKAGE_URI=${PACKAGE_URI:-https://kojipkgs.fedoraproject.org/packages/qemu/${VERSION}/${FEDORA_VERSION}/$(pkg_arch $BASE_ARCH)/qemu-user-static-${VERSION}-${FEDORA_VERSION}.$(pkg_arch $BASE_ARCH).rpm}
      print_start "Extract $PACKAGE_URI"

      # https://bugzilla.redhat.com/show_bug.cgi?id=837945
      curl -fsSL "$PACKAGE_URI" | rpm2cpio - | zstdcat | cpio -dimv "*usr/bin*qemu-*-static"

      mv ./usr/bin/* ./
      rm -rf ./usr/bin
    ;;
    debian)
      PACKAGE_URI=${PACKAGE_URI:-http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}${DEBIAN_VERSION}_$(pkg_arch $BASE_ARCH).deb}
      print_start "Extract $PACKAGE_URI"
      curl -fsSL "$PACKAGE_URI" | dpkg --fsys-tarfile - | tar xvf - --wildcards ./usr/bin/qemu-*-static --strip-components=3
    ;;
  esac

  for F in $(ls); do
    tar -czf "../releases/${F}_${BASE_ARCH}.tgz" "$F"
  done

  case "$BUILD_ARCH" in
    fedora)
      IMG="${REPO}:${BASE_ARCH}-f${VERSION}"
    ;;
    debian)
      IMG="${REPO}:${BASE_ARCH}-d${VERSION}"
    ;;
  esac

  cd ..

  if [ -z "$TRAVIS" ]; then
    print_start "Build $IMG-pkg"
    docker build -t "$IMG"-pkg ./bin-static -f-<<EOF
FROM scratch
COPY ./* /usr/bin/
EOF
    build_register
  fi
}

#--

deploy () {
  echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
  print_start "Push $REPO"
  docker push $REPO
  docker logout
}

#--

manifests () {
  mkdir -p ~/.docker
  echo '{"experimental": "enabled"}' > ~/.docker/config.json

  echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

  for BUILD in latest debian fedora; do

    MAN_ARCH_LIST="amd64 arm64v8 arm32v7 i386 s390x ppc64le"
    case "$BUILD" in
      fedora)
        MAN_VERSION="f${DEF_FEDORA_VERSION}"
      ;;
      debian|latest)
        MAN_VERSION="d${DEF_DEBIAN_VERSION}"
        MAN_ARCH_LIST="$MAN_ARCH_LIST arm32v6"
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

      print_start "Docker manifest create $MAN_IMG"
      docker manifest create -a $MAN_IMG $cmd

      print_start "Docker manifest push $MAN_IMG"
      docker manifest push --purge "$MAN_IMG"
    done

  done

  docker logout
}

#--

publish () {
  print_start "Cross-compile main.c for 'aarch64' and 'riscv64' in an 'amd64' docker container"

  cat > main.c <<-EOF
#include <stdio.h>

int main(void) {
  printf("Hello world!\n");
  return 0;
}
EOF

  docker run --rm -tv $(pwd):/src -w /src ubuntu:bionic bash -c "$(cat <<-EOF
apt update -y
apt install -y gcc-aarch64-linux-gnu ca-certificates curl
update-ca-certificates
aarch64-linux-gnu-gcc -static -o test-aarch64 main.c
chmod +x test-aarch64

mkdir /riscv
curl -fsSL https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-20170612-x86_64-linux-centos6.tar.gz | tar -xzf - -C /riscv --strip-components=1
/riscv/bin/riscv64-unknown-elf-gcc -static -o test-riscv64 main.c
chmod +x test-riscv64
EOF
)"
}

#--

build_cfg () {
  BUILD_ARCH=${BUILD:-debian}

  FEDORA_VERSION="2.fc34"
  DEF_FEDORA_VERSION="5.1.0"

  DEBIAN_VERSION="+dfsg-4"
  DEF_DEBIAN_VERSION="5.1"

  case "$BUILD_ARCH" in
    fedora)
      DEF_VERSION="$DEF_FEDORA_VERSION"
    ;;
    debian)
      DEF_VERSION="$DEF_DEBIAN_VERSION"
    ;;
  esac
  VERSION=${VERSION:-$DEF_VERSION}

  REPO=${REPO:-aptman/qus}
  HOST_ARCH=${HOST_ARCH:-x86_64}
  BASE_ARCH=${BASE_ARCH:-x86_64}

  PRINT_BASE_ARCH="$BASE_ARCH"
  case "$BASE_ARCH" in
    x86_64|x86-64|amd64|AMD64)
      BASE_ARCH=amd64 ;;
    aarch64|armv8|ARMv8|arm64v8)
      BASE_ARCH=arm64v8 ;;
    aarch32|armv8l|armv7|armv7l|ARMv7|arm32v7|armhf|armv7hl)
      BASE_ARCH=arm32v7 ;;
    arm32v6|ARMv6|armel)
      BASE_ARCH=arm32v6 ;;
    arm32v5|ARMv5)
      BASE_ARCH=arm32v5 ;;
    i686|i386|x86)
      BASE_ARCH=i386 ;;
    ppc64*|POWER8)
      BASE_ARCH=ppc64le ;;
    s390x)
      BASE_ARCH=s390x ;;
    mips|mipsel)
      BASE_ARCH=mipsel ;;
    mips64*)
      BASE_ARCH=mips64el ;;
    *)
      echo "Invalid BASE_ARCH <${BASE_ARCH}>."
      exit 1
  esac

  [ -n "$PRINT_BASE_ARCH" ] && PRINT_BASE_ARCH="$BASE_ARCH [$PRINT_BASE_ARCH]" || PRINT_BASE_ARCH="$BASE_ARCH"

  echo "VERSION: $VERSION $DEF_VERSION"
  echo "REPO: $REPO"
  echo "BASE_ARCH: $PRINT_BASE_ARCH"; unset PRINT_BASE_ARCH
  echo "HOST_ARCH: $HOST_ARCH";
  echo "BUILD_ARCH: $BUILD_ARCH";
}

#
#--
#

do_register () {
  case "$QUS_JOB" in
   [a-z]*)
     print_start "Register qemu-user binfmt interpreters with register.sh"
     sudo QEMU_BIN_DIR=$QEMU_BIN_DIR ./register.sh $@
   ;;
   *)
     print_start "Register qemu-user binfmt interpreters with aptman/qus:register"
     QEMU_BIN_DIR=${QEMU_BIN_DIR:-/usr/bin}
     docker run --rm --privileged \
       -e "QEMU_BIN_DIR=$QEMU_BIN_DIR" \
       -v "$QEMU_BIN_DIR:$QEMU_BIN_DIR" \
       aptman/qus:register $@
  esac
  list
}

list () {
  print_start "List binfmt interpreters"
  sudo ./register.sh -l -- -t
}

#--

get_static () {
  print_start "Get qemu-aarch64-static"
  if [ "$#" != "0" ]; then
    dir="-C $1"
    subin="$(command -v sudo)"
  fi
  curl -fsSL https://github.com/dbhi/qus/releases/download/$TEST_RELEASE/qemu-aarch64-static_amd64.tgz | $subin tar xvzf - $dir
}

apt_install () {
  print_start "sudo apt-get install $@"
  sudo apt update -y
  sudo apt install -y $@
}

#--

do_test () {
  cmd="docker run --rm -tv $(pwd):/src $2 qus/test bash -c"
  printf "$ANSI_BLUE> Test direct and explicit execution in a docker container$ANSI_NOCOLOR\n"
  printf 'DIRECT: ';   $cmd "/src/main"
  printf 'EXPLICIT: '; $cmd "command -v $1 >/dev/null 2>&1 && $1 /src/main || echo '$1 not available'"
}

qus_test () {
  if [ "$(docker images -q qus/test 2> /dev/null)" == "" ]; then
    img="arm64v8/ubuntu:bionic"
    print_start "Pull docker image $img and tag it as qus/test"
    docker pull "$img"
    docker tag "$img" qus/test
  fi

  if [ "$#" != "0" ]; then
    q="$(basename $1)"
    v="$(dirname $1)"
    if [ "$v" = "." ]; then v="$(pwd)"; fi
    do_test $q "-v=$v/$q:/usr/bin/$q"
  else
    do_test "qemu-aarch64-static"
  fi
}

#--

test_case () {
  curl -fsSL https://github.com/dbhi/qus/releases/download/$TEST_RELEASE/test-aarch64 -o main
  chmod +x main

  case "$QUS_JOB" in
    [fF])
      get_static /usr/bin
      do_register -s -- -p aarch64
      qus_test
    ;;
    [cC])
      get_static
      QEMU_BIN_DIR=$(pwd) do_register -s -- -p aarch64
      qus_test
    ;;
    [vV])
      do_register -s -- aarch64
      get_static
      qus_test qemu-aarch64-static
    ;;
    [iI])
      do_register -s -- aarch64

      print_start "Build arm64v8 docker image containing qemu-aarch64-static"
      get_static
      docker build -t qus/test . -f-<<EOF
FROM arm64v8/ubuntu:bionic
COPY ./qemu-aarch64-static /usr/bin
EOF
      rm -rf qemu-aarch64-static

      qus_test
    ;;
    [dD])
      do_register -- aarch64

      print_start "Build amd64 docker image containing qemu-user"
      docker build -t qus/test -<<EOF
FROM amd64/ubuntu:bionic
RUN apt update && apt install -y qemu-user
EOF

      do_test qemu-aarch64
    ;;
    s)
      apt_install qemu-user-static
      list
      qus_test /usr/bin/qemu-aarch64-static
    ;;
    [rR])
      apt_install qemu-user-static
      list
      do_register -- -r
      do_register -s -- -p aarch64
      qus_test
    ;;
    n)
      apt_install qemu-user-binfmt
      list

      print_start "Test direct and explicit native execution"
      printf 'DIRECT: ';   ./main
      printf 'EXPLICIT: '; qemu-aarch64 ./main
    ;;
    [hH])
      exit 1
#     register -- -p
#
#     pull_tmp "ubuntu:18.04"
#     q="qemu-aarch64"
#     #test $q -v=/usr/bin/$q:/usr/bin/$q
#     do_test $q
    ;;
    *)
      print_start "Register and load qemu-aarch64-static with/from aptman/qus"
      docker run --rm --privileged aptman/qus -s -- -p aarch64

      qus_test
    ;;
  esac
}

#--

case "$1" in
  -b|-d|-m|-p)
    build_cfg
    case "$1" in
      -d) deploy    ;;
      -m) manifests ;;
      -p) publish   ;;
      *)  build
    esac
  ;;
  -a)
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
      print_start "Build $BASE_ARCH" "$ANSI_MAGENTA"
      unset PACKAGE_URI
      build_cfg
      build
      print_start "Copy $BASE_ARCH" "$ANSI_MAGENTA"
      cp -vr releases/* ../releases/
    done
    rm -rf releases
    mv ../releases ./
  ;;
  *)
    TEST_RELEASE="v0.0.5-v5.0-14"
    test_case
esac
