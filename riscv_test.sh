#!/bin/sh

set -e

docker run --rm --privileged aptman/qus --targets riscv32,riscv64 -s -- -p yes

docker build -t riscv/test . -f-<<EOF
FROM ubuntu:bionic

RUN apt update -qq && apt upgrade -y && apt install -y --no-install-recommends \
      ca-certificates curl\
  && apt update -qq && apt autoclean && apt clean && apt -y autoremove \
  && update-ca-certificates

ENV PATH /opt/riscv/bin:$PATH
RUN echo 'export PATH=/opt/riscv/bin:\$PATH' >> $WORKDIR/.bashrc

ENV RISCV_GCC_VER=riscv64-unknown-elf-gcc-20170612-x86_64-linux-centos6

RUN cd /opt && curl -fsSL https://static.dev.sifive.com/dev-tools/\$RISCV_GCC_VER.tar.gz | tar -xzv && \
    mv \$RISCV_GCC_VER /opt/riscv
EOF

cat > hello.c <<-EOF
#include <stdio.h>

int main(void) {
    printf("Hello world!\n");
    return 0;
}
EOF

docker run --rm -tv $(pwd):/src -w /src riscv/test bash -c "$(cat <<EOF
riscv64-unknown-elf-gcc -o hello hello.c
./hello
EOF
)"
