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

build () {
  [ -z "$PACKAGE_URI" ] && PACKAGE_URI="http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}_amd64.deb"

  echo "PACKAGE_URI: $PACKAGE_URI"

  IMG="${REPO}:register"
  travis_start "register" "Build $IMG"
  docker build -t "$IMG" . -f-<<EOF
FROM busybox
ENV QEMU_BIN_DIR=/usr/bin
COPY ./register.sh /register
ADD https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh /qemu-binfmt-conf.sh
RUN chmod +x /qemu-binfmt-conf.sh
ENTRYPOINT ["/register"]
EOF
  travis_finish "register"

  [ -d bin-static ] && rm -rf bin-static
  mkdir -p bin-static

  [ -d releases ] && rm -rf releases
  mkdir -p releases

  cd bin-static

  travis_start "extract" "Extract $PACKAGE_URI"
  curl -fsSL "$PACKAGE_URI" | dpkg --fsys-tarfile - | tar xvf - --wildcards ./usr/bin/qemu-*-static --strip-components=3
  travis_finish "extract"

  HOST_ARCH="x86_64"

  for F in $(ls); do
      tar -czf "../releases/${HOST_ARCH}_${F}.tar.gz" "$F"

      IMG="${REPO}:${HOST_ARCH}-$(echo $F | cut -d- -f2)"
      travis_start "$IMG" "Build $IMG"
      docker build -t "$IMG" . -f-<<EOF
FROM scratch
COPY ./$F /usr/bin/${HOST_ARCH}_${F}
EOF
      travis_finish "$IMG"
  done

  cd ..
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

[ -z "$VERSION" ] && VERSION="3.1+dfsg-4"
[ -z "$REPO" ] && REPO="aptman/qus"

echo "VERSION: $VERSION"
echo "REPO: $REPO"

case "$1" in
  "-d") deploy  ;;
  *)
    build
esac
