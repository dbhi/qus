#!/bin/bash -e

cd "$(dirname $0)"

enable_color() {
  ENABLECOLOR='-c '
  ANSI_RED="\033[31m"
  ANSI_GREEN="\033[32m"
  ANSI_YELLOW="\033[33m"
  ANSI_BLUE="\033[34m"
  ANSI_MAGENTA="\033[35m"
  ANSI_CYAN="\033[36;1m"
  ANSI_DARKCYAN="\033[36m"
  ANSI_NOCOLOR="\033[0m"
}

disable_color() { unset ENABLECOLOR ANSI_RED ANSI_GREEN ANSI_YELLOW ANSI_BLUE ANSI_MAGENTA ANSI_CYAN ANSI_DARKCYAN ANSI_NOCOLOR; }

enable_color

#--

travis_start () {
  :
}
travis_finish () {
  :
}

[ -n "$TRAVIS" ] && {
  # This is a trimmed down copy of
  # https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/templates/header.sh
  travis_time_start() {
    # `date +%N` returns the date in nanoseconds. It is used as a replacement for $RANDOM, which is only available in bash.
    travis_timer_id=`date +%N`
    travis_start_time=$(travis_nanoseconds)
    echo "travis_time:start:$travis_timer_id"
  }
  travis_time_finish() {
    travis_end_time=$(travis_nanoseconds)
    local duration=$(($travis_end_time-$travis_start_time))
    echo "travis_time:end:$travis_timer_id:start=$travis_start_time,finish=$travis_end_time,duration=$duration"
  }

  if [ "$TRAVIS_OS_NAME" = "osx" ]; then
    travis_nanoseconds() {
      date -u '+%s000000000'
    }
  else
    travis_nanoseconds() {
      date -u '+%s%N'
    }
  fi

  travis_start () {
    echo "travis_fold:start:$1"
    travis_time_start
    printf "$ANSI_BLUE> $2$ANSI_NOCOLOR\n"
  }

  travis_finish () {
    travis_time_finish
    echo "travis_fold:end:$1"
  }

} || echo "INFO: not in Travis CI"

#--

getDockerCredentialPass () {
:
#  travis_start "get_docker_credential_pass" "Get docker-credential-pass"
#  PASS_URL="$(curl -s https://api.github.com/repos/docker/docker-credential-helpers/releases/latest \
#    | grep "browser_download_url.*pass-.*-amd64" \
#    | cut -d : -f 2,3 \
#    | tr -d \" \
#    | cut -c2- )"
#
#  [ "$(echo "$PASS_URL" | cut -c1-5)" != "https" ] && PASS_URL="https://github.com/docker/docker-credential-helpers/releases/download/v0.6.0/docker-credential-pass-v0.6.0-amd64.tar.gz"
#
#  echo "PASS_URL: $PASS_URL"
#  curl -fsSL "$PASS_URL" | tar xv
#  chmod + $(pwd)/docker-credential-pass
#  travis_finish "get_docker_credential_pass"
}

#--

dockerLogin () {
  travis_start "docker_login" "Docker login"
#  if [ "$CI" = "true" ]; then
#    gpg --batch --gen-key <<-EOF ; pass init $(gpg --no-auto-check-trustdb --list-secret-keys | grep ^sec | cut -d/ -f2 | cut -d" " -f1)
#%echo Generating a standard key
#Key-Type: DSA
#Key-Length: 1024
#Subkey-Type: ELG-E
#Subkey-Length: 1024
#Name-Real: Meshuggah Rocks
#Name-Email: meshuggah@example.com
#Expire-Date: 0
## Do a commit here, so that we can later print "done" :-)
#%commit
#%echo done
#EOF
#  fi
  echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
  travis_finish "docker_login"
}

#--

pkg_arch () {
  case "$1" in
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
}

guest_arch() {
  case "$1" in
   amd64)
     echo x86_64 ;;
   arm64)
     echo aarch64 ;;
   armhf|armel)
     echo arm ;;
   ppc64*)
     echo ppc64le ;;
   *)
     echo "$1"
  esac
}

#--

getSingleQemuUserStatic () {
  V=${1:-$VERSION}
  G=${2:-$BASE_ARCH}
  H=${3:-amd64}

  curl -fsSL "http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${V}_$(pkg_arch ${H}).deb" \
  | dpkg --fsys-tarfile - \
  | tar xvf - --wildcards ./usr/bin/qemu-$(guest_arch $(pkg_arch ${G}))-static --strip-components=3
}

getAndRegisterSingleQemuUserStatic () {
  travis_start "get" "Get single qemu-user-static"
  getSingleQemuUserStatic
  travis_finish "get"

  travis_start "guest" "Register binfmt interpreter for single qemu-user-static"
  QEMU_BIN_DIR="$(pwd)" $(command -v sudo) ./register.sh -s -- -p "$(guest_arch $(pkg_arch $BASE_ARCH))"
  travis_finish "guest"

  travis_start "list" "List binfmt interpreters"
  $(command -v sudo) ./register.sh -l -- -t
  travis_finish "list"
}

build_register () {
  case "$BASE_ARCH" in
    amd64|arm64v8|arm32v7|arm32v6|i386|ppc64le|s390x)
      HOST_LIB="${BASE_ARCH}/"
    ;;
    *)
      HOST_LIB="skip"
  esac

  if [ -n "$TRAVIS" ]; then
    case "$BASE_ARCH" in
      arm64v8|arm32v7|arm32v6|ppc64le|s390x)
        getAndRegisterSingleQemuUserStatic
    esac
  fi

  PKG_IMG="$IMG"
  IMG="${REPO}:${BASE_ARCH}"

  [ "$HOST_LIB" = "skip" ] && {
    printf "$ANSI_YELLOW! Skipping creation of $IMG[-register] because HOST_LIB <$HOST_LIB>.$ANSI_NOCOLOR\n"
  } || {
    travis_start "register" "Build $IMG-register"
    docker build -t $IMG-register . -f-<<EOF
FROM ${HOST_LIB}busybox
RUN mkdir /qus
ENV QEMU_BIN_DIR=/qus/bin
COPY ./register.sh /qus/register
ADD https://raw.githubusercontent.com/umarcor/qemu/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh /qus/qemu-binfmt-conf.sh
RUN chmod +x /qus/qemu-binfmt-conf.sh
ENTRYPOINT ["/qus/register"]
EOF
    travis_finish "register"
    travis_start "$BASE_ARCH" "Build $IMG"

    docker build -t $IMG . -f-<<EOF
FROM $IMG-register
COPY --from="$PKG_IMG" /usr/bin/qemu-* /qus/bin/
VOLUME /qus
EOF
    travis_finish "$BASE_ARCH"
  }
}

#--

build () {
  [ -d bin-static ] && rm -rf bin-static
  mkdir -p bin-static

  [ -d releases ] && rm -rf releases
  mkdir -p releases

  cd bin-static

  PACKAGE_URI=${PACKAGE_URI:-http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}_$(pkg_arch $BASE_ARCH).deb}
  travis_start "extract" "Extract $PACKAGE_URI"
  curl -fsSL "$PACKAGE_URI" | dpkg --fsys-tarfile - | tar xvf - --wildcards ./usr/bin/qemu-*-static --strip-components=3
  travis_finish "extract"

  for F in $(ls); do
    tar -czf "../releases/${F}_${BASE_ARCH}.tgz" "$F"
  done

  IMG="${REPO}:${BASE_ARCH}-pkg"
  travis_start "$F" "Build $IMG"
  docker build -t "$IMG" . -f-<<EOF
FROM scratch
COPY ./* /usr/bin/
EOF
  travis_finish "$F"

  cd ..

  build_register
}

#--

deploy () {
  getDockerCredentialPass
  dockerLogin
  docker push $REPO
  docker logout
}

#--

manifests () {
  mkdir -p ~/.docker
  echo '{"experimental": "enabled"}' > ~/.docker/config.json

  getDockerCredentialPass
  dockerLogin

  for i in latest pkg register; do
    travis_start "man_create_$i" "Docker manifest create $i"
    cmd="docker manifest create -a ${REPO}:$i"
    [ "$i" == "latest" ] && p="" || p="-$i"
    for a in amd64 arm64v8 arm32v7 arm32v6 i386 s390x ppc64le; do
      cmd="$cmd ${REPO}:${a}${p}"
    done
    $cmd
    travis_finish "man_create_$i"

    travis_start "man_push_$i" "Docker manifest push ${REPO}:$i"
    docker manifest push --purge "${REPO}:$i"
    travis_finish "man_push_$i"
  done

  docker logout
}

#--

publish () {
  travis_start "compile" "Cross-compile main.c for 'aarch64' and 'riscv64' in an 'amd64' docker container"

  cat > main.c <<-EOF
#include <stdio.h>

int main(void) {
  printf("Hello world!\n");
  return 0;
}
EOF

  docker run --rm -itv $(pwd):/src -w /src ubuntu:bionic bash -c "$(cat <<-EOF
apt update -y
apt install -y gcc-aarch64-linux-gnu ca-certificates curl
update-ca-certificates
aarch64-linux-gnu-gcc -static -o test-aarch64 main.c
chmod +x test-aarch64

mkdir /riscv
curl -fsSL https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-20170612-x86_64-linux-centos6.tar.gz | tar -xzvf - -C /riscv --strip-components=1
/riscv/bin/riscv64-unknown-elf-gcc -static -o test-riscv64 main.c
chmod +x test-riscv64
EOF
)"
  travis_finish "compile"
}

#--

build_cfg () {
  VERSION=${VERSION:-3.1+dfsg-5}
  REPO=${REPO:-aptman/qus}
  BASE_ARCH=${BASE_ARCH:-x86_64}

  PRINT_BASE_ARCH="$BASE_ARCH"
  case "$BASE_ARCH" in
    x86_64|x86-64|amd64|AMD64)
      BASE_ARCH=amd64 ;;
    aarch64|armv8|ARMv8|arm64v8)
      BASE_ARCH=arm64v8 ;;
    aarch32|armv8l|armv7|armv7l|ARMv7|arm32v7|armhf)
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
    mips)
      BASE_ARCH=mips ;;
    mips64*)
      BASE_ARCH=mips64el ;;
    *)
      echo "Invalid BASE_ARCH <${BASE_ARCH}>."
      exit 1
  esac

  [ -n "$PRINT_BASE_ARCH" ] && PRINT_BASE_ARCH="$BASE_ARCH [$PRINT_BASE_ARCH]" || PRINT_BASE_ARCH="$BASE_ARCH"

  echo "VERSION: $VERSION"
  echo "REPO: $REPO"
  echo "BASE_ARCH: $PRINT_BASE_ARCH"; unset PRINT_BASE_ARCH
}

#
#--
#

do_register () {
  case "$QUS_JOB" in
   [a-z]*)
     travis_start "register" "Register qemu-user binfmt interpreters with register.sh"
     sudo QEMU_BIN_DIR=$QEMU_BIN_DIR ./register.sh $@
     travis_finish "register"
   ;;
   *)
     travis_start "register" "Register qemu-user binfmt interpreters with aptman/qus:register"
     QEMU_BIN_DIR=${QEMU_BIN_DIR:-/usr/bin}
     docker run --rm --privileged \
       -e "QEMU_BIN_DIR=$QEMU_BIN_DIR" \
       -v "$QEMU_BIN_DIR:$QEMU_BIN_DIR" \
       aptman/qus:register $@
  esac
  travis_finish "register"

  list
}

list () {
  travis_start "list" "List binfmt interpreters"
  sudo ./register.sh -l -- -t
  travis_finish "list"
}

#--

get_static () {
  travis_start "build" "Get qemu-aarch64-static"
  if [ "$#" != "0" ]; then
    dir="-C $1"
    subin="$(command -v sudo)"
  fi
  curl -fsSL https://github.com/umarcor/qus/releases/download/v0.0-v3.1/qemu-aarch64-static_amd64.tgz | $subin tar xvzf - $dir
  travis_finish "build"
}

apt_install () {
  travis_start "apt" "sudo apt install $@"
  sudo apt-get install $@
  travis_finish "apt"
}

#--

do_test () {
  cmd="docker run --rm -itv $(pwd):/src $2 qus/test bash -c"
  printf "$ANSI_BLUE> Test direct and explicit execution in a docker container$ANSI_NOCOLOR\n"
  printf 'DIRECT: ';   $cmd "/src/main"
  printf 'EXPLICIT: '; $cmd "command -v $1 >/dev/null 2>&1 && $1 /src/main || echo '$1 not available'"
}

qus_test () {
  if [ "$(docker images -q qus/test 2> /dev/null)" == "" ]; then
    img="arm64v8/ubuntu:bionic"
    travis_start "pull" "Pull docker image $img and tag it as qus/test"
    docker pull "$img"
    docker tag "$img" qus/test
    travis_finish "pull"
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
  curl -fsSL https://github.com/umarcor/qus/releases/download/v0.0-v3.1/test-aarch64 -o main
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

      travis_start "build" "Build arm64v8 docker image containing qemu-aarch64-static"
      get_static
      docker build -t qus/test . -f-<<EOF
FROM arm64v8/ubuntu:bionic
COPY ./qemu-aarch64-static /usr/bin
EOF
      rm -rf qemu-aarch64-static
      travis_finish "build"

      qus_test
    ;;
    [dD])
      do_register -- aarch64

      travis_start "build" "Build amd64 docker image containing qemu-user"
      docker build -t qus/test -<<EOF
FROM amd64/ubuntu:bionic
RUN apt update && apt install -y qemu-user
EOF
      travis_finish "build"

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

      travis_start "native" "Test direct and explicit native execution"
      printf 'DIRECT: ';   ./main
      printf 'EXPLICIT: '; qemu-aarch64 ./main
      travis_finish "native"
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
      travis_start "register" "Register and load qemu-aarch64-static with/from aptman/qus"
      docker run --rm --privileged aptman/qus -s -- -p aarch64
      travis_finish "register"

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
  *) test_case
esac
