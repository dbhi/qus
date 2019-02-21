#!/bin/sh

set -e

cd $(dirname $0)

. ./utils.sh

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
  travis_start "register" "Register qemu-user binfmt interpreters with register.sh"
  sudo ./register.sh $@
  travis_finish "register"

  list
}

register_docker () {
  travis_start "register" "Register qemu-user binfmt interpreters with aptman/qus:register"
  [ -n "$QEMU_BIN_DIR" ] && vol="-e QEMU_BIN_DIR=$QEMU_BIN_DIR -v=$QEMU_BIN_DIR:$QEMU_BIN_DIR" || vol=""
  docker run --rm --privileged $vol aptman/qus:register $@
  travis_finish "register"

  list
}

list () {
  travis_start "list" "List binfmt interpreters"
  sudo ./register.sh -l -e
  travis_finish "list"
}

#--

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
  travis_finish "pull"
}

#--

test_docker_direct() {
  docker run --rm -itv $(pwd):/src $1 tmp/tmp bash -c "/src/main"
}

test_docker_explicit() {
  docker run --rm -itv $(pwd):/src $2 tmp/tmp bash -c "$(cat <<-EOF
#!/bin/sh
command -v $1 >/dev/null 2>&1 && $1 /src/main || echo "$1 not available"
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

tmp_test () {
  pull_tmp "arm64v8/ubuntu:bionic"

  if [ "$#" != "0" ]; then
    q="$(basename $1)"
    v="$(dirname $1)"
    if [ "$v" = "." ]; then v="$(pwd)"; fi
    test_docker $q "-v=$v/$q:/usr/bin/$q"
  else
    test_docker "qemu-aarch64-static"
  fi
}

#--

compile

case "$QUS_JOB" in
  [fF])
    get_static
    sudo mv qemu-aarch64-static /usr/bin

    [ "$QUS_JOB" = "f" ] && cmd="register" || QEMU_BIN_DIR=/usr/bin cmd="register_docker"

    $cmd -s -t aarch64 -- -p yes

    tmp_test
  ;;
  [cC])
    get_static
    export QEMU_BIN_DIR=$(pwd)

    [ "$QUS_JOB" = "c" ] && cmd="register" || cmd="register_docker"

    $cmd -s -t aarch64 -- -p yes

    tmp_test
  ;;
  [vV])
    args="-s -t aarch64"
    [ "$QUS_JOB" = "v" ] && register $args || QEMU_BIN_DIR=/usr/bin register_docker $args

    get_static

    tmp_test qemu-aarch64-static
  ;;
  [iI])
    args="-s -t aarch64"
    [ "$QUS_JOB" = "i" ] && register $args || QEMU_BIN_DIR=/usr/bin register_docker $args

    get_static

    build_static
    test_docker qemu-aarch64-static
  ;;
  [hH])
    exit 1
  ;;
  [dD])
    args="-t aarch64"
    [ "$QUS_JOB" = "d" ] && register $args || QEMU_BIN_DIR=/usr/bin register_docker $args

    travis_start "build" "Build docker image containing qemu-user"
    docker build -t tmp/tmp -<<EOF
FROM ubuntu:18.04
RUN apt update && apt install -y qemu-user
EOF
    travis_finish "build"

    test_docker qemu-aarch64
  ;;
  s)
    travis_start "apt" "sudo apt install qemu-user-static"
    sudo apt-get install qemu-user-static
    travis_finish "apt"

    list

    tmp_test /usr/bin/qemu-aarch64-static
  ;;
  [rR])
    travis_start "apt" "sudo apt install qemu-user-static"
    sudo apt-get install qemu-user-static
    travis_finish "apt"

    list

    args="-r -s -t aarch64 -- -p yes"
    [ "$QUS_JOB" = "r" ] && register $args || QEMU_BIN_DIR=/usr/bin register_docker $args

    tmp_test
  ;;
  n)
    travis_start "apt" "sudo apt install qemu-user-binfmt"
    sudo apt-get install qemu-user-binfmt
    travis_finish "apt"

    list

    travis_start "native" "Test direct and explicit native execution"
    printf 'DIRECT: '
    ./main
    printf 'EXPLICIT: '
    qemu-aarch64 ./main
    travis_finish "native"
  ;;

#  "-h")
#    register -- -p yes
#
#    pull_tmp "ubuntu:18.04"
#    q="qemu-aarch64"
#    #test_docker $q -v=/usr/bin/$q:/usr/bin/$q
#    test_docker $q
  *)
    travis_start "register" "Register and load qemu-aarch64-static with/from aptman/qus"
    docker run --rm --privileged aptman/qus -s -t aarch64 -- -p yes
    travis_finish "register"

    tmp_test
  ;;
esac
