# UPDATE_DEBIAN.md

## Objective
Bump the Debian qemu pin in `cli/config.yml` to trixie `10.0.13+ds-0+deb13u1`, and rework `run.sh`'s Debian extraction so the new packaging (binaries split out of `qemu-user-static`) still yields real `qemu-*-static` interpreters. Commit per repo style: `update debian to 10.0.13+ds-0+deb13u1`, on top of current `main` (`47b1074`). Do **not** push.

## Verified facts (research already done)
- Config today: `cli/config.yml:22-23` → `base: "7.2"`, `rev: "+dfsg-5"`.
- Trixie (`10.0.13+ds-0+deb13u1`) ships `qemu-user-static_…_<host>.deb` (76 KB: only `/usr/bin/qemu-*-static` **symlinks** → `qemu-*`) and `qemu-user_…_<host>.deb` (real **static-pie** ELF `qemu-*` binaries) for hosts: `amd64 arm64 armel armhf i386 ppc64el riscv64 s390x`. **No** `mipsel`/`mips64el` (404).
- `run.sh` Debian call sites that must change:
  - `getSingleQemuUserStatic()` debian case — `run.sh:51-57` (extracts only `qemu-${GARCH}-static`).
  - `build()` debian case — `run.sh:161-166` (extracts `./usr/bin/qemu-*-static`).
- Both currently assume one deb contains the binaries; with trixie they'd produce dangling symlinks.

## Edits
1. `cli/config.yml:20-26` — Debian defaults only:
   - `base: "7.2"` → `base: "10.0.13"`
   - `rev: "+dfsg-5"` → `rev: "+ds-0+deb13u1"`
   (altogether `10.0.13+ds-0+deb13u1`, matching the pool filenames.)

2. `run.sh` — add a shared Debian fetcher near `getSingleQemuUserStatic` and use it in both call sites:

   ```sh
   getDEB () {
     # $1 = package name (qemu-user|qemu-user-static), $2 = host deb-arch, $3 = tar wildcard
     curl -fsSL "http://ftp.debian.org/debian/pool/main/q/qemu/${1}_${VERSION}${SOURCE_VERSION}_${2}.deb" \
       | dpkg --fsys-tarfile - \
       | tar xf - --wildcards "${3}" --strip-components=3
   }
   ```

   - `getSingleQemuUserStatic()` debian case (`run.sh:51-57`) becomes:
     ```sh
     debian)
       getDEB qemu-user        "$HARCH" "./usr/bin/qemu-${GARCH}"
       getDEB qemu-user-static "$HARCH" "./usr/bin/qemu-${GARCH}-static"
       mv "./usr/bin/qemu-${GARCH}" ./
       [ -e "./usr/bin/qemu-${GARCH}-static" ] && mv "./usr/bin/qemu-${GARCH}-static" ./ || mv "qemu-${GARCH}" "qemu-${GARCH}-static"
       rm -rf ./usr/bin
     ;;
     ```
     (keeps the existing mv/rm shape; the existing post-case `mv`/`rm` in `run.sh:47-49` belongs to the fedora branch — keep fedora untouched.)
   - `build()` debian case (`run.sh:161-166`) becomes:
     ```sh
     debian)
       PACKAGE_URI=${PACKAGE_URI:-http://ftp.debian.org/debian/pool/main/q/qemu/qemu-user-static_${VERSION}${SOURCE_VERSION}_${BARCH}.deb}
       getDEB qemu-user        "$BARCH" "./usr/bin/qemu-*"
       getDEB qemu-user-static "$BARCH" "./usr/bin/qemu-*-static"
       for f in qemu-*; do
         [ "$f" = "${f%-static}" ] || continue        # skip -static names
         [ -e "${f}-static" ] || ln -s "$f" "${f}-static"   # defensive aliases
       done
     ```
     (`PACKAGE_URI` line kept for upstream URL override semantics.)

3. `run.sh assets()` — `run.sh:258-267`: drop `mipsel mips64el` from the debian case (trixie has no such host debs). Final intended shared shape (this plan contributes the debian half):
   ```sh
   assets() {
     ARCH_LIST="x86_64 aarch64 ppc64le s390x"
     case "$BUILD" in
       fedora) ;;
       debian) ARCH_LIST="$ARCH_LIST i686 armhf armel" ;;
     esac
     ...
   }
   ```
   (The Fedora subagent, which runs after this one, converges the `fedora` branch to the same final shape — see UPDATE_FEDORA.md.)

4. `.github/workflows/Test.yml` — `Images` matrix excludes (`Test.yml:93-103`): add
   ```yaml
           - src: debian
             arch: mipsel
           - src: debian
             arch: mips64el
   ```
   so trixie (which lacks mips hosts) doesn't fail those two debian jobs.

5. `manifests()` (`run.sh:197-254`) — **no change needed here**: the debian manifest arch list `amd64 arm64v8 i386 s390x arm32v6 arm32v7 ppc64le` maps to `amd64 arm64 armel armhf i386 ppc64el s390x` all present in trixie.

## Verification
- `bash -n run.sh`.
- `GITHUB_STEP_SUMMARY=$(mktemp) ./cli/cli.py check` → exit 1 **expected**; summary line `[Debian] Current: 10.0.13+ds-0+deb13u1 | Latest: 7.2+dfsg-7+deb12u18+b3` documents that the lexicographic pool-max is still the bookworm 7.2 string (known, accepted; see Risks).
- `./cli/cli.py version -u debian` → `10.0.13 +ds-0+deb13u1`; `./cli/cli.py arch -u debian -a x86_64` → `amd64`.
- `curl -fsSI` both new debs for every 8 hosts (200).
- Smoke the extraction locally: `mkdir /tmp/opencode/deb-test && cd $_ && curl …qemu-user_10.0.13+ds-0+deb13u1_amd64.deb | dpkg --fsys-tarfile | tar xvf - --wildcards ./usr/bin/qemu-* --strip-components=3 && curl …qemu-user-static… | dpkg --fsys-tarfile | tar xvf - --wildcards ./usr/bin/qemu-*-static --strip-components=3` → confirm `readlink qemu-aarch64-static` resolves to an existing `qemu-aarch64` file in the same dir. (Do this in /tmp only.)
- Full runtime validation happens in CI (`Test.yml`) — not runnable in a sandbox.

## Risks / accepted tradeoffs
- **Canary Debian check stays red by design** (lexicographic compare picks `7.2+dfsg-7+deb12u18+b3`). A future `cli/debian.py` fix (semantic comparison / stable-suite awareness) is out of scope here.
- Image size grows: `qemu-user` binaries replace the single 62 MB bookworm deb with per-target static binaries across two debs.
- mipsel/mips64el debian **build assets and CI jobs** are dropped (no debs exist in trixie). Published manifest arch set is unaffected.
- New interpreter = QEMU 10.x → `test-aarch64`/`test-riscv64` may need CI green to confirm backward guest compat.