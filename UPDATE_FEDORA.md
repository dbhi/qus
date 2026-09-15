# UPDATE_FEDORA.md

## Objective
Bump the Fedora qemu pin in `cli/config.yml` to rawhide `11.1.1/1.fc46` (matches the koji checker → Canary's Fedora half goes green), and patch `run.sh`/`Test.yml` for the targets and hosts Fedora dropped. Run **after** UPDATE_DEBIAN.md. Commit: `update fedora to 11.1.1-1.fc46`, on top of the current `main`. Do **not** push.

## Verified facts (research already done)
- Config today: `cli/config.yml:24-26` → `base: "7.2.0"`, `rev: "7.fc39"`.
- koji `packages/qemu/11.1.1/1.fc46` exists; static-user target rpms on `x86_64`: `aarch64 alpha arm hexagon hppa loongarch64 m68k microblaze mips or1k ppc riscv s390x sh4 sparc x86 xtensa` = **16** targets + `aarch64 …` all `200`; **`cris` and `nios2` are `404`** (dropped by modern Fedora).
- Host arch dirs present: `aarch64 ppc64le s390x x86_64` (+noarch/data/src); **`i686` and `armv7hl` are `404`**.
- Same target/host situation for F43/F44 — there is no "old" modern Fedora with cris/nios2/i686.
- `run.sh` Fedora touchpoints:
  - `getSingleQemuUserStatic()` fedora case `run.sh:44-50` — no change needed (URL template is version-parametric; GARCH rpms verified).
  - `build()` fedora `for TARCH` loop `run.sh:132-151` — contains `cris` and `nios2` → hard fail under `set -e`.
  - `manifests()` `MAN_ARCH_LIST="amd64 arm64v8 i386 s390x"` `run.sh:209` — includes `i386` (needs the gone `i686` host).
  - `assets()` `ARCH_LIST="x86_64 i686 aarch64 ppc64le s390x"` + `fedora … armv7hl` `run.sh:259-266`.
  - `Test.yml` `Images` matrix `Test.yml:83-103` — `arch: i686` is currently built for fedora.

## Edits
1. `cli/config.yml:20-26` — Fedora defaults only:
   - `base: "7.2.0"` → `base: "11.1.1"`
   - `rev: "7.fc39"` → `rev: "1.fc46"`
   (yields koji path `packages/qemu/11.1.1/1.fc46/...` and image tags `f11.1.1`.)

2. `run.sh build()` fedora TARCH list (`run.sh:132-151`) — remove `cris` and `nios2`; keep exactly:
   `aarch64 alpha arm hexagon hppa loongarch64 m68k microblaze mips or1k ppc riscv s390x sh4 sparc x86 xtensa`.

3. `run.sh manifests()` (`run.sh:209-216`) — final shape (also removes `i386` from fedora):
   ```sh
   MAN_ARCH_LIST="amd64 arm64v8 s390x"
   case "$BUILD" in
     fedora)
       MAN_VERSION="f${DEF_VERSION}"
     ;;
     debian|latest)
       MAN_VERSION="d${DEF_VERSION}"
       MAN_ARCH_LIST="$MAN_ARCH_LIST i386 arm32v6 arm32v7 ppc64le"
     ;;
   esac
   ```

4. `run.sh assets()` (`run.sh:259-266`) — converge to the final shared shape that UPDATE_DEBIAN.md established (edit the `fedora` branch to be a no-op):
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
   If the Debian plan already produced this exact shape, only verify; do not duplicate.

5. `.github/workflows/Test.yml` `Images` excludes (`Test.yml:93-103`) — add:
   ```yaml
           - src: fedora
             arch: i686
   ```
   (Keep all existing fedora excludes; keep the debian mips excludes added by UPDATE_DEBIAN.md.)

## Verification
- `bash -n run.sh`.
- `GITHUB_STEP_SUMMARY=$(mktemp) ./cli/cli.py check` → exit 1 **only** from the Debian side (expected, per Debian plan); `[Fedora] Up to date: 11.1.1/1.fc46` in the summary — Fedora check green.
- `./cli/cli.py version -u fedora` → `11.1.1 1.fc46`.
- Re-`curl` spot-checks (already done in research): `qemu-user-static-{riscv,arm,mips,x86}` `200` on `11.1.1/1.fc46/x86_64/`; `qemu-user-static-aarch64` `200` for hosts `aarch64`/`s390x`; `cris`/`nios2`/`i686` now absent from the loop/globs.
- Full runtime validation in CI.

## Risks / accepted tradeoffs
- **Rawhide sourcing**: released images will carry Fedora rawhide QEMU 11.1.1 (this is what makes the checker green; without it the daily Canary keeps failing).
- **`i386` Fedora image removed**: `i686` host no longer exists in Fedora; the fedora manifest set shrinks to `amd64 arm64v8 s390x`. 32-bit x86 guests remain covered by the debian images.
- Cris/nios2 user-mode interpreters disappear (upstream Fedora packaging dropped them); debian images still provide them via trixie's `qemu-user`.
- `armv7hl` fedora asset host dropped (gone upstream) — matches the existing Excludes in `Test.yml`.