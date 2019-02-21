#!/bin/bash -e

cd "$(dirname $0)"

#--

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

}

#--

getDockerCredentialPass () {
  PASS_URL="$(curl -s https://api.github.com/repos/docker/docker-credential-helpers/releases/latest \
    | grep "browser_download_url.*pass-.*-amd64" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | cut -c2- )"

  [ "$(echo "$PASS_URL" | cut -c1-5)" != "https" ] && PASS_URL="https://github.com/docker/docker-credential-helpers/releases/download/v0.6.0/docker-credential-pass-v0.6.0-amd64.tar.gz"

  echo "PASS_URL: $PASS_URL"
  curl -fsSL "$PASS_URL" | tar xv
  chmod + $(pwd)/docker-credential-pass
}

#--

dockerLogin () {
  [ "$CI" = "true" ] && gpg --batch --gen-key <<-EOF ; pass init $(gpg --no-auto-check-trustdb --list-secret-keys | grep ^sec | cut -d/ -f2 | cut -d" " -f1)
%echo Generating a standard key
Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: Meshuggah Rocks
Name-Email: meshuggah@example.com
Expire-Date: 0
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOF
  echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
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
    ppc64le)
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
   ppc64el)
     echo ppc64le ;;
   *)
     echo "$1"
  esac
}

#--

build_register () {
  case "$HOST_ARCH" in
    amd64|arm64v8|arm32v7|arm32v6|i386|ppc64le|s390x)
      HOST_LIB="${HOST_ARCH}/"
    ;;
    arm32v5|ARMv5|mips|mips64el)
      HOST_LIB="skip"
    ;;
    *)
      echo "Invalid HOST_ARCH <${HOST_ARCH}>."
      exit 1
  esac

  IMG="${REPO}:${HOST_ARCH}-register"

  if [ -n "$TRAVIS" ]; then
    case "$HOST_ARCH" in
      arm64v8|arm32v7|arm32v6|ppc64le|s390x)
        printf "$ANSI_RED! Skipping creation of $IMG. HOST_ARCH <$HOST_ARCH> not supported in Travis, yet.$ANSI_NOCOLOR\n"
        HOST_LIB="skip"
      ;;
    esac
  fi

  [ "$HOST_LIB" = "skip" ] && {
    printf "$ANSI_YELLOW! Skipping creation of $IMG because HOST_LIB <$HOST_LIB>.$ANSI_NOCOLOR\n"
  } || {

    docker build -t $IMG . -f-<<EOF
FROM ${HOST_LIB}busybox
ENV QEMU_BIN_DIR=/usr/bin
COPY ./register.sh /register
ADD https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh /qemu-binfmt-conf.sh
RUN chmod +x /qemu-binfmt-conf.sh
ENTRYPOINT ["/register"]
EOF
  }
}

#--

build () {
  PACKAGE_URI=${PACKAGE_URI:-http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}_$(pkg_arch $HOST_ARCH).deb}

  echo "PACKAGE_URI: $PACKAGE_URI"

  [ -d bin-static ] && rm -rf bin-static
  mkdir -p bin-static

  [ -d releases ] && rm -rf releases
  mkdir -p releases

  cd bin-static

  travis_start "extract" "Extract $PACKAGE_URI"
  curl -fsSL "$PACKAGE_URI" | dpkg --fsys-tarfile - | tar xvf - --wildcards ./usr/bin/qemu-*-static --strip-components=3
  travis_finish "extract"

  for F in $(ls); do
    tar -czf "../releases/${HOST_ARCH}_${F}.tgz" "$F"

    IMG="${REPO}:${HOST_ARCH}-$(echo $F | cut -d- -f2)"
    travis_start "$IMG" "Build $IMG"
    docker build -t "$IMG" . -f-<<EOF
FROM scratch
COPY ./$F /usr/bin/${HOST_ARCH}_${F}
EOF
    travis_finish "$IMG"
  done

  cd ..

  travis_start "register" "Build $IMG"
  build_register
  travis_finish "register"
}

#--

deploy () {
  travis_start "tag" "Tag ${REPO}:${HOST_ARCH}-*"
  for T in $(ls releases); do
    T="$(echo $T | cut -d- -f2)"
    docker tag "${REPO}:${HOST_ARCH}-$T" "${REPO}:$T"
  done
  travis_finish "tag"
  getDockerCredentialPass
  dockerLogin
  docker push $REPO
  docker logout
}

#--

VERSION=${VERSION:-3.1+dfsg-4}
REPO=${REPO:-aptman/qus}
HOST_ARCH=${HOST_ARCH:-x86_64}

PRINT_HOST_ARCH="$HOST_ARCH"
case "$HOST_ARCH" in
  x86_64|x86-64|amd64|AMD64)
    HOST_ARCH=amd64 ;;
  aarch64|armv8|ARMv8|arm64v8)
    HOST_ARCH=arm64v8 ;;
  aarch32|armv8l|armv7|armv7l|ARMv7|arm32v7|armhf)
    HOST_ARCH=arm32v7 ;;
  arm32v6|ARMv6|armel)
    HOST_ARCH=arm32v6 ;;
  arm32v5|ARMv5)
    HOST_ARCH=arm32v5 ;;
  i686|i386|x86)
    HOST_ARCH=i386 ;;
  ppc64le|ppc64el|POWER8)
    HOST_ARCH=ppc64le ;;
  s390x)
    HOST_ARCH=s390x ;;
  mips)
    HOST_ARCH=mips ;;
  mips64el)
    HOST_ARCH=mips64el ;;
  *)
    echo "Invalid HOST_ARCH <${HOST_ARCH}>."
    exit 1
esac

[ -n "$PRINT_HOST_ARCH" ] && PRINT_HOST_ARCH="$HOST_ARCH [$PRINT_HOST_ARCH]" || PRINT_HOST_ARCH="$HOST_ARCH"

echo "VERSION: $VERSION"
echo "REPO: $REPO"
echo "HOST_ARCH: $PRINT_HOST_ARCH"; unset PRINT_HOST_ARCH

case "$1" in
  "-d") deploy  ;;
  *)
    build
esac
