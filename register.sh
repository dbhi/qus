#!/bin/sh
# register binfmt interpreters to enable automatic program execution of foreign architectures by the kernel
# based on https://raw.githubusercontent.com/multiarch/qemu-user-static/master/register/register.sh
# added features:
#  - find binfmt_misc with findmnt; if not found, default to `/proc/sys/fs/binfmt_misc/`
#  - look for `qemu-binfmt-conf.sh` at `./`, then at `/`, otherwise get it with `curl`
#  - separate arguments for `register.sh` from arguments for `qemu-binfmt-conf.sh` with `--`; options for register:
#    - if the first and single arg is `-l`, list currently registered interpreters; then exit
#    - if the first arg is `-i`, execute all the remaining args with `sh -c`; then exit
#    - --reset|-reset: clean any registered `qemu-*` interpreter before executing `qemu-binfmt-conf.sh`
#    - --static|-static: add `--qemu-suffix -static` to `qemu-binfmt-conf.sh`
#    - --targets|-targets: comma separated list or guest archs to be registered; default is to register all of them (even if binaries are not found, which produces errors)

cd $(dirname $0)

QEMU_BIN_DIR=${QEMU_BIN_DIR:-/usr/bin}

#--

if [ "$1" = "-i" ]; then
  shift
  sh -c $@
  exit
fi

#--

binfmt="$(findmnt -f -n -o TARGET binfmt_misc)" || binfmt="/proc/sys/fs/binfmt_misc/"

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
      "--reset"|"-reset")     set -- "$@" "-r";;
      "--targets"|"-targets") set -- "$@" "-t";;
      "--static"|"-static")   set -- "$@" "-s";;
    *) set -- "$@" "$a"
  esac
done
# Use getopts to process $@
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

#--

# Look for qemu-binfmt-conf.sh at ./ and /, otherwise get it with curl
cmd='./qemu-binfmt-conf.sh'
[ ! -f "$cmd" ] && cmd='/qemu-binfmt-conf.sh'
[ -f "$cmd" ] && cmd="cat $cmd" || cmd='curl -fsSL https://raw.githubusercontent.com/qemu/qemu/master/scripts/qemu-binfmt-conf.sh'

#--

if [ -n "$TARGETS" ]; then
  # Hackish solution to redefine qemu_target_list in qemu-binfmt-conf.sh, so that only the desired guest archs are registered
  $cmd \
  | sed 's/\(i386_magic=''.*\)/qemu_target_list="'"$(echo "$TARGETS" | tr ',' ' ')"'"\n\n\1/g' \
  | sh -s -- $args
else
  $cmd | sh -s -- $args
fi
