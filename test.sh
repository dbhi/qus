#!/usr/bin/env bash

# Copyright 2019-2020 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
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

export DOCKER_BUILDKIT=1

. ./utils.sh

TEST_RELEASE="v0.0.11-v7.1+dfsg-2--bpo11+3"
if [ -n "$1" ]; then
  TEST_RELEASE="$1"
fi
echo "TEST_RELEASE: $TEST_RELEASE"


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
