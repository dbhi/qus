#!/bin/sh
# register binfmt interpreters to enable automatic program execution of foreign architectures by the kernel
# based on https://raw.githubusercontent.com/multiarch/qemu-user-static/master/register/register.sh
# added features:
#  - find binfmt_misc with findmnt; if not found, default to `/proc/sys/fs/binfmt_misc/`
#  - look for `qemu-binfmt-conf.sh` at `./`, then at `/`, otherwise get it with `curl`
#  - options `-i`, `-l` and `-- ARGS`

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

sh -c "$cmd | sh -s -- $args"

if [ "$LIST_BINFMT" = "true" ]; then
  ls -la /proc/sys/fs/binfmt_misc/
fi
