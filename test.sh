#!/bin/sh

set -e

cd $(dirname $0)

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

compile () {
  travis_start "compile" "Cross-compile main.c in a x86-64 docker container"
  docker run --rm -itv $(pwd):/src -w /src ubuntu:18.04 bash -c "\
    apt update -y && \
    apt install -y gcc-aarch64-linux-gnu && \
    aarch64-linux-gnu-gcc -static main.c -o main && \
    chmod +x main"
  travis_finish "compile"
}

#--

register () {
  travis_start "register" "Register qemu-user binfmt interpreters"
  sudo ./register.sh $@
  travis_finish "register"

  list
}

register_multilib () {
  travis_start "register" "Register qemu-user-static binfmt interpreters"
  [ -n "$QEMU_BIN_DIR" ] && vol="-v=$QEMU_BIN_DIR:$QEMU_BIN_DIR" || vol=""
  docker run --rm --privileged $vol multiarch/qemu-user-static:register $@
  travis_finish "register"

  list
}

list () {
  travis_start "list" "List binfmt interpreters"
  findmnt binfmt_misc
  ls -la /proc/sys/fs/binfmt_misc
  travis_finish "list"
}

#--

build () {
  travis_start "build" "Build docker image containing qemu-user"
  docker build -t tmp/tmp -<<EOF
FROM ubuntu:18.04
RUN apt update && apt install -y qemu-user
EOF
  travis_finish "build"
}

build_static () {
  travis_start "build" "Build docker image containing qemu-aarch64-static"
  docker build -t tmp/tmp . -f-<<EOF
FROM arm64v8/ubuntu:bionic
COPY ./qemu-aarch64-static /usr/bin
EOF
  travis_finish "build"
}

get_static () {
  travis_start "build" "Get qemu-aarch64-static from multiarch/qemu-user-static:x86_64-aarch64"
  docker build -t tmp/tmp -<<EOF
FROM busybox
COPY --from=multiarch/qemu-user-static:x86_64-aarch64 /usr/bin qemu_user_static.tgz
RUN tar -xzvf qemu_user_static.tgz
EOF
  docker run --rm -itv $(pwd):/src tmp/tmp cp /qemu-aarch64-static /src
  docker rmi -f tmp/tmp
  travis_finish "build"
}

pull_tmp () {
  travis_start "pull" "Pull docker image $1 and tag it as tmp/tmp"
  docker pull $1
  docker tag $1 tmp/tmp
  travis_finish "build"
}

#--

test_docker_direct() {
  docker run --rm -itv $(pwd):/src $1 tmp/tmp bash -c "/src/main"
}

test_docker_explicit() {
  docker run --rm -itv $(pwd):/src $2 tmp/tmp bash -c "$(cat <<-EOF
#!/bin/sh
which -v $1 && $1 /src/main || echo "$1 not available"
EOF
)"
}

test_docker () {
  travis_start "test" "Test direct and explicit execution in a docker container"
  printf 'DIRECT: '
  test_docker_direct $2
  printf 'EXPLICIT: '
  test_docker_explicit $@
  travis_finish "test"
}

test_native () {
  travis_start "native" "Test direct and explicit native execution"
  printf 'DIRECT: '
  ./main
  printf 'EXPLICIT: '
  qemu-aarch64 ./main
  travis_finish "native"
}

#--

compile

case "$1" in
  "-n")
    register
    test_native
  ;;
  "-d")
    register
    build
    test_docker qemu-aarch64
  ;;
  "-f")
    get_static
    sudo mv qemu-aarch64-static /usr/bin
    register -s -- -p yes

    pull_tmp "arm64v8/ubuntu:bionic"
    test_docker qemu-aarch64-static
  ;;
  "-m")
    register_multilib
    get_static
    build_static
    test_docker qemu-aarch64-static
  ;;
  "-v")
    register_multilib
    get_static

    pull_tmp "arm64v8/ubuntu:bionic"
    q="qemu-aarch64-static"
    test_docker $q -v=$(pwd)/$q:/usr/bin/$q
  ;;
  "-p")
    get_static
    q="qemu-aarch64-static"
    sudo mv $q /usr/bin
    export QEMU_BIN_DIR="/usr/bin/$q"
    register_multilib -p yes

    pull_tmp "arm64v8/ubuntu:bionic"
    test_docker $q
  ;;
  "-h")
    register -- -p yes

    pull_tmp "ubuntu:18.04"
    q="qemu-aarch64"
    #test_docker $q -v=/usr/bin/$q:/usr/bin/$q
    test_docker $q
  ;;
  "-s")
    register -s -- -p yes

    pull_tmp "ubuntu:18.04"

    pwd
    ls -la
    test_docker qemu-aarch64-static
  ;;
  *)
    echo "Unknown arg <$1>"
  ;;
esac
