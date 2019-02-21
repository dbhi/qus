#!/bin/sh
# register binfmt interpreters to enable automatic program execution of foreign architectures by the kernel
# based on https://raw.githubusercontent.com/multiarch/qemu-user-static/master/register/register.sh
# added features:
#  - find binfmt_misc with findmnt; if not found, default to `/proc/sys/fs/binfmt_misc/`
#  - look for `qemu-binfmt-conf.sh` at `./`, then at `/`, otherwise get it with `curl`
#  - options `-i`, `-l`, `-e`, `-t` and `-- ARGS`

usage() {
    cat <<-EOF
Usage: register.sh [--help][--interactive][--list][--exit][--reset]
                   [--static][--targets TARGETS][-- ARGS]

  Wrapper around qemu-binfmt-conf.sh, to configure binfmt_misc to use qemu interpreter

  -h|--help|-help:
      display this usage

  -i|--interactive|-interactive:
      execute all the remaining args with 'sh -c', then exit

  -l|--list|-list:
      list currently registered interpreters

  -e|--exit|-exit:
      exit without neither executing further options nor calling qemu-binfmt-conf.sh

  -r|--reset|-reset:
      clean any registered 'qemu-*' interpreter

  -s|--static|-static:
      add '--qemu-suffix -static' to ARGS

  -t|--targets|-targets:
      comma separated list or guest archs to be registered
      by default, all of them are registered (even if binaries are not found, which produces errors)

  -- ARGS:
     arguments for qemu-binfmt-conf.sh

  To register a single static target persistently, use e.g.:

      register.sh -s -t aarch64 -- -p yes

  To remove all register interpreters and exit, use:

      register.sh -r -e

EOF
}

#--

check_binfmt () {
  binfmt="/proc/sys/fs/binfmt_misc/"
  if [ "$(command -v findmnt)" != "" ]; then
    binfmt="$(findmnt -f -n -o TARGET binfmt_misc)"
  fi

  if [ ! -d "$binfmt" ]; then
    echo "No binfmt support in the kernel."
    echo "  Try: '/sbin/modprobe binfmt_misc' from the host"
    exit 1
  fi

  if [ ! -f "${binfmt}/register" ]; then
    mount binfmt_misc -t binfmt_misc "${binfmt}"
  fi
}

#--

set -e

cd $(dirname $0)

QEMU_BIN_DIR=${QEMU_BIN_DIR:-/usr/bin}

#--

# Split args for qemu-binfmt-conf.sh (args) from args for register.sh (rargs)
args="--qemu-path=${QEMU_BIN_DIR}"
rargs="$@"

if [ "$rargs" != "--" ] && [ "$(echo "$@" | grep -- '--')" ]; then
  args="$args $(echo "$@" | sed 's/.* -- \(.*\)/\1/')"
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
      "--exit"|"-exit")               set -- "$@" "-e";;
      "--reset"|"-reset")             set -- "$@" "-r";;
      "--targets"|"-targets")         set -- "$@" "-t";;
      "--static"|"-static")           set -- "$@" "-s";;
    *) set -- "$@" "$a"
  esac
done
# Use getopts to process $@
while getopts ":hilerst:" opt; do
  case $opt in
    h)
      usage
      exit
    ;;
    i)
      sh -c $@
      exit
    ;;
    l)
      check_binfmt
      ls -la "$binfmt"
    ;;
    e) exit 0 ;;
    r)
      check_binfmt
      find "$binfmt" -type f -name 'qemu-*' -exec sh -c 'echo -1 > {}' \;
    ;;
    s) args="$args --qemu-suffix -static" ;;
    t) TARGETS=$OPTARG ;;
    \?)
      printf "${ANSI_RED}Invalid option: -${OPTARG}${ANSI_NOCOLOR}\n" >&2
	    exit 1
    ;;
    :)
      printf "${ANSI_RED}Option -$OPTARG requires an argument.${ANSI_NOCOLOR}\n" >&2
	    exit 1
  esac
done

#--

# Look for qemu-binfmt-conf.sh at ./ and /, otherwise get it with curl
cmd='./qemu-binfmt-conf.sh'
[ ! -f "$cmd" ] && cmd='/qemu-binfmt-conf.sh'
[ -f "$cmd" ] && cmd="cat $cmd" || cmd='curl -fsSL https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh'

#--

check_binfmt

if [ -n "$TARGETS" ]; then
  # Hackish solution to redefine qemu_target_list in qemu-binfmt-conf.sh, so that only the desired guest archs are registered
  $cmd \
  | sed 's/\(i386_magic=''.*\)/qemu_target_list="'"$(echo "$TARGETS" | tr ',' ' ')"'"\n\n\1/g' \
  | sh -s -- $args
else
  $cmd | sh -s -- $args
fi
