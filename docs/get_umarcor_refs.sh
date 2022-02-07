#!/usr/bin/env sh

cd $(dirname "$0")

mkdir -p refs
curl -fsSL https://github.com/umarcor/umarcor/archive/refs/heads/main.tar.gz | \
  tar -xzC ./refs --strip-components=2 umarcor-main/references/
