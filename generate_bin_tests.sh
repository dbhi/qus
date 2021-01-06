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

export DOCKER_BUILDKIT=1

. ./utils.sh

echo "· Cross-compile main.c for 'aarch64' and 'riscv64' in an 'amd64' docker container"

cat > main.c <<-EOF
#include <stdio.h>

int main(void) {
  printf("Hello world!\n");
  return 0;
}
EOF

docker run --rm -tv $(pwd):/src -w /src ubuntu:bionic bash -c "
apt update -y
apt install -y gcc-aarch64-linux-gnu ca-certificates curl
update-ca-certificates
aarch64-linux-gnu-gcc -static -o test-aarch64 main.c
chmod +x test-aarch64

mkdir /riscv
curl -fsSL https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-20170612-x86_64-linux-centos6.tar.gz | tar -xzf - -C /riscv --strip-components=1
/riscv/bin/riscv64-unknown-elf-gcc -static -o test-riscv64 main.c
chmod +x test-riscv64
"
