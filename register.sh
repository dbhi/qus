#!/bin/sh

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

# register binfmt interpreters to enable automatic program execution of foreign architectures by the kernel
#
# loosely based on https://github.com/multiarch/qemu-user-static/blob/master/containers/latest/register.sh
# added features:
#  - find binfmt_misc with findmnt; if not found, default to `/proc/sys/fs/binfmt_misc/`
#  - look for `qemu-binfmt-conf.sh` at `./`, then at `/`, otherwise get it with `curl`
#  - make '-static' optional
#  - options `-i`, `-l` and `-- ARGS`
#  - use getopts

usage() {
    cat <<-EOF
Usage: register.sh [--help][--interactive][--list][--static][-- ARGS]

  Wrapper around qemu-binfmt-conf.sh, to configure binfmt_misc to use qemu interpreter

  -h|--help|-help:
      display this usage

  -i|--interactive|-interactive:
      execute all the remaining args with 'sh -c', then exit

  -l|--list|-list:
      list currently registered interpreters

  -s|--static|-static:
      add '--qemu-suffix -static' to ARGS

  -- ARGS:
     arguments for qemu-binfmt-conf.sh

  To register a single static target persistently, use e.g.:

      register.sh -s -- -p aarch64

  To remove all register interpreters and exit, use:

      register.sh -- -r

EOF
}

set -e

cd $(dirname $0)

QEMU_BIN_DIR=${QEMU_BIN_DIR:-/usr/bin}
LIST_BINFMT=

# Split args for qemu-binfmt-conf.sh (args) from args for register.sh (rargs)
args="--path=${QEMU_BIN_DIR}"
rargs="$@"

if [ "$rargs" != "--" ] && [ "$(echo "$@" | grep -- '--')" ]; then
  args="$args $(echo "$@" | sed 's/.*-- \(.*\)/\1/')"
  rargs="$(echo "$@" | sed 's/\(.*\) -- .*/\1/')"
fi

# Clean $@
shift $#

# Process register.sh options (rargs)
# Transform long options to short ones; save all of them back to $@
for a in $rargs; do
  case "$a" in
      "--help"|"-help")               set -- "$@" "-h";;
      "--list"|"-list")               set -- "$@" "-l";;
      "--interactive"|"-interactive") set -- "$@" "-i";;
      "--static"|"-static")           set -- "$@" "-s";;
    *) set -- "$@" "$a"
  esac
done
# Use getopts to process $@
while getopts ":hils" opt; do
  case $opt in
    h)
      usage
      exit
    ;;
    i)
      sh -ic "$@"
      exit
    ;;
    l)
      LIST_BINFMT="true"
    ;;
    s) args="$args --suffix -static" ;;
    \?)
      printf "${ANSI_RED}Invalid option: -${OPTARG}${ANSI_NOCOLOR}\n" >&2
	    exit 1
    ;;
    :)
      printf "${ANSI_RED}Option -$OPTARG requires an argument.${ANSI_NOCOLOR}\n" >&2
	    exit 1
  esac
done

# Look for qemu-binfmt-conf.sh at ./ and /, otherwise get it with curl
cmd='./qemu-binfmt-conf.sh'
[ ! -f "$cmd" ] && cmd='/qemu-binfmt-conf.sh'
[ -f "$cmd" ] && cmd="cat $cmd" || cmd='curl -fsSL https://raw.githubusercontent.com/umarcor/qemu/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh'

echo "$cmd | sh -s -- $args"

sh -c "$cmd | sh -s -- $args"

if [ "$LIST_BINFMT" = "true" ]; then
  ls -la /proc/sys/fs/binfmt_misc/
fi
