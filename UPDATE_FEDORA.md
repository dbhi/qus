# UPDATE_FEDORA.md (revised)

## Objective
Fix the fedora "latest" detection in `cli/fedora.py` (it picks the last ASCII-sorted koji dir, which is *not* the newest) so the checker uses true version ordering, then bump the Fedora pin to rawhide `11.1.1/2.fc46` (highest current 11.1.1 subversion; `1.fc46` verified, `2.fc46` unverified during planning — confirmed by the Edit 7 pre-flight, with fallback `1.fc46`). Combined with the committed Debian change, the daily Canary check goes **green**. Patch `run.sh`/`Test.yml` for the targets/hosts Fedora dropped. The Debian side is already committed (`c242b99`); this plan is the Fedora side (second step). Do **not** push.

## Why the checker is wrong (evidence)
`cli/fedora.py:35-55` does `versions.reverse()` on koji's raw page order, which is **ASCII**: `11.1.1` sorts *before* `9.2.4` (`"1" < "9"`), so today's "latest" is `9.2.4/2.fc42` even though rawhide `11.1.1/2.fc46` is newer. Same flaw in the subversion list (`1.fc42 < 2.fc42` happens to work, but `10.fc46 // 2.fc46` would not).

## Verified facts (research already done; no network during planning — see Edit 7)
- Config today: `cli/config.yml:25-26` → `base: "7.2.0"`, `rev: "7.fc39"`.
- koji `packages/qemu/` highest non-rc reached by the current (buggy) checker: **`9.2.4/2.fc42`** (empirically observed via `cli.py check`, 2026-09-15).
- koji `packages/qemu/11.1.1/` contains `1.fc46` (verified); `2.fc46` is believed to be the current max subversion but **unverified** — confirmed by the Edit 7 pre-flight (fallback `1.fc46`). Static-user target rpms (verified at `1.fc46`, x86_64): `aarch64 alpha arm hexagon hppa loongarch64 m68k microblaze mips or1k ppc riscv s390x sh4 sparc x86 xtensa` = **16** targets, all `200`; **`cris` and `nios2` are `404`** (dropped by modern Fedora). `2.fc46` is a rebase of the same release → expected identical target set.
- Host arch dirs at `11.1.1/1.fc46/`: `aarch64 data noarch ppc64le s390x src x86_64`; **`i686` and `armv7hl` are `404`**. `qemu-user-static-aarch64` rpm `200` for `aarch64`/`ppc64le`/`s390x`/`x86_64`.
- `cli/fedora.py` is only consumed by `check` — `check_fedora_latest` is imported at `cli/cli.py:43` and called only at `cli/cli.py:130` (`HandleCheck`); the `fedora`/report CLI paths don't touch it (confirmed in plan-mode read).
- `run.sh` Fedora touchpoints:
  - `getSingleQemuUserStatic()` fedora case `run.sh:52-57` — no change needed (URL template is version-parametric; GARCH rpms verified).
  - `build()` fedora `for TARCH` loop `run.sh:138-158` — contains `cris` (`run.sh:143`) and `nios2` (`run.sh:150`) → hard fail under `set -e`.
  - `manifests()` `MAN_ARCH_LIST="amd64 arm64v8 i386 s390x"` `run.sh:221` — includes `i386` (needs the gone `i686` host).
  - `assets()` `ARCH_LIST="x86_64 i686 aarch64 ppc64le s390x"` + `fedora … armv7hl` `run.sh:270-279`.
  - `Test.yml` `Images` matrix `Test.yml:83-107` — `arch: i686` is currently built for fedora.

## Edits
1. `cli/fedora.py:35-55` — natural/version sorting instead of page-order reverse. Add a module-level key helper and switch the two iterations to `sorted(..., key=_nat_key, reverse=True)`:

   ```python
   def _nat_key(s):
       return [
           (0, int(t)) if t.isdigit() else (1, t)
           for t in re.split(r"(\d+)", s)
           if t != ""
       ]
   ```
   and in `check_fedora_latest()`:
   ```python
   for version in sorted(versions, key=_nat_key, reverse=True):
       subvers = [...]
       for l in sorted(subvers, key=_nat_key, reverse=True):
           if ".rc" not in l:
               latest = (version, l)
               break
       if latest is not None:
           break
   ```
   (Keep the `.rc` filter and the `latest is None` raise; multi-element version dirs like `2.4.0.1` still compare correctly: int tag `0` < str tag `1`, so `(0,11) > (0,9)` → `11.1.1 > 9.2.4`.)

2. `cli/config.yml:25-26` — Fedora defaults:
   - `base: "7.2.0"` → `base: "11.1.1"`
   - `rev: "7.fc39"` → `rev: "2.fc46"` (subject to Edit 7 pre-flight; fallback `1.fc46`)
   (yields koji path `packages/qemu/11.1.1/2.fc46/...` and image tags `f11.1.1`.)

3. `run.sh build()` fedora TARCH list (`run.sh:138-158`) — remove `cris` and `nios2`; keep exactly:
   `aarch64 alpha arm hexagon hppa loongarch64 m68k microblaze mips or1k ppc riscv s390x sh4 sparc x86 xtensa`.

4. `run.sh manifests()` (`run.sh:221-230`) — final shape (also removes `i386` from fedora):
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

5. `run.sh assets()` (`run.sh:270-279`) — converge to the final shared shape (the Debian commit already dropped mips; finish the restructure):
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
   (Drops fedora-only `armv7hl`; base no longer lists `i686` for fedora.)

6. `.github/workflows/Test.yml` `Images` excludes (`Test.yml:93-107`) — add the fedora/i686 exclude **between** the fedora mips64el block (`Test.yml:102-103`) and the debian mips excludes (`Test.yml:104-107`):
   ```yaml
           - src: fedora
             arch: i686
   ```
   (Keep all existing fedora excludes; keep the debian mips excludes added by the Debian commit.)

7. **Pre-flight — resolve the exact subversion before committing** (the `2.fc46` pin is unverified; this decides it):
   ```sh
   curl -fsSI https://kojipkgs.fedoraproject.org/packages/qemu/11.1.1/2.fc46/x86_64/qemu-user-static-aarch64-11.1.1-2.fc46.x86_64.rpm
   ```
   - exit 0 / `200` → use `rev: "2.fc46"` as planned (tags `f11.1.1`; Edit 2 unchanged).
   - `404` → fall back to the highest `200` subversion of `11.1.1` (`1.fc46`) and set that as `rev` (Edits 2 config value, the `cli.py check` expectation, and the commit message adjust accordingly).
   Either way the checker is green: the natural sort + `.rc` filter returns exactly the pinned value.

## Verification
- Edit 7 first (subversion pre-flight), then the rest.
- Baseline (before editing `fedora.py`): `GITHUB_STEP_SUMMARY=$(mktemp) ~/qusvenv/bin/python ./cli/cli.py check` prints `[Fedora] Current: 7.2.0/7.fc39 | Latest: 9.2.4/2.fc42` (empirically observed). After edit 1 it must print `[Fedora] Up to date: 11.1.1/2.fc46`.
- `bash -n run.sh`.
- `GITHUB_STEP_SUMMARY=$(mktemp) ~/qusvenv/bin/python ./cli/cli.py check` → exit 0; summary shows `[Fedora] Up to date: 11.1.1/2.fc46` **and** `[Debian] Up to date: 10.0.13+ds-0+deb13u1` (regression guard — the `HandleCheck` error path is shared).
- `~/qusvenv/bin/python ./cli/cli.py version -u fedora` → `11.1.1 2.fc46`.
- Spot checks (done at `1.fc46`; expected identical in `2.fc46`): 16 static-user targets `200` / cris·nios2 `404` on x86_64; host rpms `200` for aarch64/ppc64le/s390x/x86_64, `404` for i686/armv7hl.
- `python -m py_compile cli/fedora.py`; `grep -n "fedora" cli/cli.py` → only `check` consumer (lines 43, 130).
- Full runtime validation in CI.

## Commits (Fedora plan, in order)
1. `fix fedora latest detection (natural version sorting)` — `cli/fedora.py`.
2. `update fedora to 11.1.1/2.fc46` — `cli/config.yml` + `run.sh` + `Test.yml` (commit message uses the subversion resolved by Edit 7; fallback `1.fc46` if `2.fc46` is `404`).
(Matches repo style of one bump per commit; the checker fix is separated since it's logic, not a version move.)

## Risks / accepted tradeoffs
- **Rawhide sourcing**: released images will carry Fedora rawhide QEMU 11.1.1 (this is what makes the checker green; without it the daily Canary keeps failing). When rawhide advances (`3.fc46`, `11.1.2`, …), Canary reds again by design. The Edit 7 fallback (`1.fc46`) is baked in but changes the commit message.
- **`i386` Fedora image removed**: `i686` host no longer exists in Fedora; the fedora manifest set shrinks to `amd64 arm64v8 s390x`. 32-bit x86 guests remain covered by the debian images.
- Cris/nios2 user-mode interpreters disappear from fedora builds (upstream packaging dropped them); debian images still provide them via trixie's `qemu-user`.
- The checker now reports the semantically-newest dir; previously `9.2.4/2.fc42` was falsely reported as latest (confirmable at runtime before the fix).