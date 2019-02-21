#!/bin/sh

cd $(dirname $0)

QEMU_BIN_DIR=${QEMU_BIN_DIR:-/usr/bin}

#--

binfmt="$(findmnt -f -n -o TARGET binfmt_misc)"

[ ! -d "$binfmt" ] && {
  echo "No binfmt support in the kernel."
  echo "  Try: '/sbin/modprobe binfmt_misc' from the host"
  exit 1
}

set -e

#--

if [ $# = 1 ] && [ "$1" = "-l" ]; then
  ls -la "$binfmt"
  exit
fi

#--

args="--qemu-path=${QEMU_BIN_DIR}"
rargs="$@"

if [ "$rargs" != "--" ] && [ "$(echo "$@" | grep -- '--')" ]; then
  args="$args $(echo "$@" | sed 's/.* -- \(.*\)/\1/')"
  rargs="$(echo "$@" | sed 's/\(.*\) -- .*/\1/')"
fi

shift $#

# Transform long options to short ones
for a in $rargs; do
  case "$a" in
      "--reset"|"-reset")     set -- "$@" "-r";;
      "--targets"|"-targets") set -- "$@" "-t";;
      "--static"|"-static")   set -- "$@" "-s";;
    *) set -- "$@" "$a"
  esac
done

while getopts ":t:rs" opt; do
  case $opt in
    r)  find "$binfmt" -type f -name 'qemu-*' -exec sh -c 'echo -1 > {}';;
    s)  args="$args --qemu-suffix -static";;
    t)  TARGETS=$OPTARG;;
    \?) printf "${ANSI_RED}Invalid option: -${OPTARG}${ANSI_NOCOLOR}\n" >&2
	    exit 1 ;;
    :)  printf "${ANSI_RED}Option -$OPTARG requires an argument.${ANSI_NOCOLOR}\n" >&2
	    exit 1
  esac
done

#--

[ ! -f "${binfmt}/register" ] && mount binfmt_misc -t binfmt_misc "${binfmt}"

cmd='./qemu-binfmt-conf.sh'
[ ! -f "$cmd" ] && cmd='/qemu-binfmt-conf.sh'
[ -f "$cmd" ] && cmd="cat $cmd" || cmd='curl -fsSL https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh'

if [ -n "$TARGETS" ]; then
  $cmd \
  | sed 's/\(i386_magic=''.*\)/qemu_target_list="'"$(echo "$TARGETS" | tr ',' ' ')"'"\n\n\1/g' \
  | sh -s -- $args
else
  $cmd | sh -s -- $args
fi
