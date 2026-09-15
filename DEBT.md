# DEBT

Inventory of known pain points, historical constraints, and places where a future agent can start improving the codebase. This is a **problem inventory**, not a roadmap — no fixes, priorities, or owners. Evidence is tagged with its source:

- **(code)** — directly visible in the current source tree.
- **(history)** — established from Git history (commits/`git blame`).
- **(inference)** — my reading of intent/consequences; verify before acting.

## 1. External / upstream coupling

- `register.sh` fetches `qemu-binfmt-conf.sh` from the personal fork `umarcor/qemu@series-qemu-binfmt-conf` at runtime, unless a copy exists locally at `./qemu-binfmt-conf.sh` or `/qemu-binfmt-conf.sh`. (code) — `register.sh:114-121`. This means:
  - All binfmt registration logic lives **outside this repository**; changes to how interpreters are registered can only be made in the fork, not here. (code/history — the runtime-fetch behaviour dates to `aeb72af`, 2019-03-04, which also *deleted* register.sh's own `-e`/`-r`/`-t` options and mount-checking logic because that logic moved into the fork's script).
  - `register.sh` is blocked on upstream QEMU accepting those patches; the project docs still describe the fork patches as pending upstream (`docs/development.rst:17-19`). (code)
  - `run.sh` builds the `-register` image with `ADD https://raw.githubusercontent.com/umarcor/qemu/series-qemu-binfmt-conf/scripts/qemu-binfmt-conf.sh`, so image builds also silently depend on that fork (and on network access to GitHub raw). (code) — `run.sh:101`.

## 2. Shell / build constraints

- `register.sh` is written in **strict POSIX `sh`**, not bash, because it is the `ENTRYPOINT` of busybox-based `-register` images. (history) — shebang changed `bash`→`sh` at `215b7f5` (2020-11-21). Any bashism introduced will break the container path.
- `run.sh` sets `DOCKER_BUILDKIT=0` and `COMPOSE_DOCKER_CLI_BUILD=0` but `test.sh` and `generate_bin_tests.sh` both export `DOCKER_BUILDKIT=1`. (code) — `run.sh:23-24`, `test.sh:21`, `generate_bin_tests.sh:21`. The buildkit-on change was originally made in 2019 (`d6c983f`) then "temporarily disabled" (`e64063c`, 2021-06-21) and never re-enabled; the two regimes coexist and depend on different builder behaviour (stdin-heredoc builds with `COPY --from` cross-image references in `run.sh`).
- The `-register` image is built FROM a busybox base chosen per host arch, then the qemu binaries are copied in from the `-pkg` image; there is `COPY --from="${IMG}-pkg"`, which requires the `-pkg` image to already be tagged locally. (code) — `run.sh:96-114`.
- `getSingleQemuUserStatic` (used in CI to build ARM/PPC/s390 images on an amd64 host) downloads and registers a single `qemu-*-static` binary to run the docker builds themselves — the build system depends on itself to build non-amd64 images. (code) — `run.sh:40-74`.

## 3. Version tracking

- Version bumping is a **manual, single-file edit** to `cli/config.yml` defaults; commit style "update debian to …" / "update fedora to …". (code/history) — e.g. `2849055` and `ddf8c3c` each touch only `cli/config.yml`. The default qemu version strings (`base`/`rev`) are strictly local.
- The **Canary** workflow detects new upstream versions by **scraping HTML directory listings** of `http://ftp.debian.org/debian/pool/main/q/qemu/` and `https://kojipkgs.fedoraproject.org/packages/qemu/`, then exits 1 to fail the daily job. (code) — `cli/debian.py:50-71`, `cli/fedora.py:30-68`, `.github/workflows/Canary.yml`.
- Version *detection* and version *use* are separate: `check` compares config defaults against scraped listings, but nothing auto-updates `config.yml`. (code)
- The release tag scheme embeds the qemu package version, e.g. `v0.0.11-v7.1+dfsg-2--bpo11+3`. Yes, tag names embed a Debian version string containing `+` and `-` characters (which must be URL-encoded when fetching assets). (history/code) — the scheme started with `71927d7` ("update TEST_RELEASE to 'v0.0.1-v3.1+dfsg-8'"); `test.sh:25` and `.github/get_tests.sh:18` fetch by such tag.

## 4. CLI implementation

- The CLI carries the whole arch/version logic but with **undeclared runtime dependencies**: `requests` (imported by `cli/debian.py:23`, `cli/fedora.py:21`, `cli/assets.py:23`) and `yaml` (`cli/config.py:22`) are not in `cli/requirements.txt` (which lists only `pyAttributes` and `tabulate`). (code) They work because PyYAML comes in transitively via pyAttributes and GitHub runners preinstall `requests`; a bare `pip install -r cli/requirements.txt` does not guarantee them. (inference)
- `cli/cli.py debian` *downloads every `qemu-user-static_*.deb` for every available version and host* from the Debian pool and needs the **`7z` binary** to unpack them (`cli/debian.py:113-146`, `128`, `130`). CI invokes it in the release job (`Test.yml` Release steps) where `7z` happens to be present on the runner image. (code/inference)
- `cli/assets.py` calls the GitHub releases API **without pagination** (`requests.get("https://api.github.com/repos/dbhi/qus/releases")`, `cli/assets.py:36`) — fine today with few releases, wrong for a long-lived project. (code)
- Version checking scrapes HTML instead of using any API; it also **only checks amd64 host versions** — `check_debian_latest` uses `Config().version('debian', 'amd64')` and `check_fedora_latest` the same. (code) — `cli/debian.py:64`, `cli/fedora.py:61`.
- The check-report path falls back to writing a local `summary.md` when `GITHUB_STEP_SUMMARY` is unset (`environ.get("GITHUB_STEP_SUMMARY", "summary.md")`) — a stray file can be left in the working dir. (code) — `cli/debian.py:67`, `cli/fedora.py:64`.
- `cli/config.py` `normalise_arch` raises a bare `Exception` for unknown architectures, and CLI commands propagate it as a traceback rather than a clean error/exit code. (code) — `cli/config.py:52`, `cli/cli.py`.
- The **entire shell build automation could not be moved into the CLI**: the `py` branch (`91dd817` "mv cli qus", 2022-09) is an attempt to convert `cli/` into a `qus/` Python package and `run.sh` into `qus/run.py`; it was never merged. The project's own roadmap lists migrating `run.sh` test/build logic into the CLI as desired (`docs/development.rst:23-25`). (history/code)

## 5. Packaging and image manifests

- `run.sh` builds per-source (`debian`/`fedora`) with all cross-source differences hardcoded in shell: package URL construction, extraction (`.deb` via `dpkg --fsys-tarfile`, `.rpm` via `rpm2cpio | zstdcat | cpio`), and per-source arch lists. (code) — `run.sh:40-59,130-167`. Historical quirks encoded: rpm packages compressed with zstd (`42fb752`), Debian renamed `mips`→`mipsel` (`33bf8b1`), `armv7hl` unavailable on fc37 (`c6d9ffa`), `arm32v7` excluded from Fedora manifests (`fd8e6a8`).
- Manifests: the `latest` manifest alias points at the **debian** build by convention (`manifests()` maps `BUILD=latest` to debian names); there is no first-class "latest = newest" resolution. (code) — `run.sh:197-254`.
- Manifest arch lists differ by source: fedora ships `amd64 arm64v8 i386 s390x`, debian adds `arm32v6 arm32v7 ppc64le`. (code) — `run.sh:209-217`.
- Fedora builds/distro version is `SOURCE_VERSION` from the CLI (`7.fc38`, …) but the build itself does not pin a Fedora release beyond what the URLs encode. (code/inference)
- `assets()` and the CI matrix enumerate host archs by different lists (`x86_64 i686 aarch64 ppc64le s390x` ± `armv7hl`/`armhf armel mipsel mips64el`), with no single registry of "supported hosts"; drifts are possible. (code) — `run.sh:259-266`, `Test.yml` Images matrix.

## 6. Tests

- The test matrix is a **single `case` statement** in `test.sh` (jobs `f F c C v V i I d D r R s n h H`) rather than parametrized logic; `h`/`H` are commented out with `exit 1` shells, though the docs' table still lists them (`docs/conf.py:48-49`). (code) — `test.sh:103-178`.
- Lowercase vs uppercase jobs encode *host register.sh* vs *docker `aptman/qus:register`* — but only the container path works on Windows/macOS hosts, which the README documents by noting that only the `C V I D` jobs work there. (code) — `test.sh:32-47`, `README.md:67-71`.
- Test binaries are pinned by **per-repo release tag**: `test.sh` default `TEST_RELEASE=v0.0.11-v7.1+dfsg-2--bpo11+3` (override via `$1`), but `.github/get_tests.sh` (used by the Action CI jobs) fetches from a much older `v0.0.6-v5.2+dfsg-3` — inconsistent pins and stale drift, plus a `v5.2+dfsg-3` binary being run against a 7.x runtime in the Action jobs. (code) — `test.sh:25`, `.github/get_tests.sh:18`.
- Running the matrix requires docker, sudo, network, and binfmt support — it cannot run in an unprivileged sandbox, and is scheduled on PRs. (code) — `.github/workflows/Test.yml`.
- `get_static()` downloads `qemu-aarch64-static_amd64.tgz` from the release — an asset whose name interleaves target, separator and host (`qemu-<target>-static_<host>.tgz`) and which only exists because the release job uploaded per-arch tgz in this shape. (code) — `test.sh:57-63`.

## 7. GitHub Action

- The Action is **Docker-based** (`action/action.yml` `using: docker`) and merely shells out to `docker run --privileged aptman/qus` (inside a Python image that also bundles a hardcoded docker 18.06 CLI binary from a static tarball URL). (code) — `action/Dockerfile`, `action/setup-qus.py:25`.
- It therefore cannot run on runners without a working Docker-in-Docker/privileged setup, and it hardcodes `aptman/qus` (no input/`REPO` override). (code)
- The Action's params are read from the env pseudo-input `INPUT_TARGETS` and split on newlines+spaces with no quoting concerns handled — multi-word YAML folding is expected to be handled by the caller. (code) — `action/setup-qus.py:21,41`.
- CI `Action-*` jobs `needs: Manifests`; they run the *published* `aptman/qus` images, so a PR changing `action/` cannot be validated against this repo's own images unless images were already published. (code/history) — `Test.yml` jobs 164+.

## 8. Docs

- `docs/conf.py` **regenerates `docs/TestsTable.inc` on every Sphinx run** from hardcoded table data (the job matrix duplicated inside Python) — writing into the source tree by convention; the file is gitignored. (code) — `docs/conf.py:30-53`, `.gitignore`.
- The bibliography is fetched at build time from the author's private-ish repo `umarcor/umarcor` (`make -C docs references` downloads `umarcor-main/references/`), and `conf.py` hard-fails if `references/Containers.bib` is missing. (code) — `docs/Makefile` `references:` target, `docs/conf.py:68-73`. Docs cannot build offline. (inference)
- Docs deploy: `.btd.yml` drives `gh-pages`, which is an **orphan, single-commit root** branch (`dafad2a`, parentless, authored by "BuildTheDocs") — the published site history is destroyed/rewritten wholesale on each deploy rather than accumulated. (history)
- Leftover docs references: README prose partially duplicates the Tests table and the arch list (`README.md:63-65` list of ~32 qemu targets), and there is no single source pinning the supported target list (the authoritative list is whatever the shipped `qemu-*-static` set provides). (code/inference)

## 9. Architecture naming / mapping legacy

- `cli/config.yml` carries frozen quirks inherited from the old shell `case` mappings (which lived in `run.sh` until Sept 2021; moved into the CLI via `72d6e26` / `85489ac` / `3e6f875`):
  - `ppc64le` aliases `` `ppc64` `` — i.e. calling the CLI with `ppc64` returns the `ppc64le` key, conflating big- and little-endian. (code) — `cli/config.yml:86-92`.
  - `i386` has no `qemu` mapping (host-only) while `amd64→x86_64` does; a `guest_arch`-style lookup on i386 fails. (code) — `cli/config.yml:79-84`.
  - `arm32v6` and `arm32v5` both map to `armel`/`arm`; distinct docker image platforms collapse to one qemu binary/DEB name. (code) — `cli/config.yml:64-77`.
  - `amd64`/`arm64v8`/`ppc64le`/`s390x`/`i386`/`arm32v7`/`arm32v6` are the docker-official-style names; hosts in CI are actually listed as `x86_64 i686 aarch64 ppc64le s390x armhf armel mipsel mips64el` — the two vocabularies overlap through aliases, which is easy to trip over. (code) — `cli/config.yml:28-113`, `run.sh:259-266`.
- `riscv64` is **half-supported**: `generate_bin_tests.sh` cross-compiles `test-riscv64`, workflows execute it, and run.sh's Fedora target list includes `riscv`, but `cli/config.yml` has **no riscv64 entry** — the CLI cannot normalise/version it, so qus images do not officially ship it. The `riscv` branch (`87e588e` "WIP add riscv64 ! DEB|RPM for riscv64 not available yet") shows the blocked attempt. (code/history)
- `generate_bin_tests.sh` uses `riscv64-unknown-elf-gcc` from a 2017 SiFive toolchain download — `riscv64-unknown-elf` is a bare-metal toolchain producing ELF without a sysroot; `test-riscv64` runs only under direct qemu invocation semantics. (code) — `generate_bin_tests.sh:43-46`.

## 10. WIP / orphan branches and their cargo

- `origin/develop` — head `98f0915` "cli: getters and builders" (dated 2020-11): an early CLI restructure that never merged; its ideas reappear on main in the Sept-2021 CLI refactor. (history)
- `origin/py` — head `4e34647` "TEST" (2022-09, on top of `91dd817` "mv cli qus"): the abandoned full migration of `run.sh` into a Python package (`qus/run.py`), the literal roadmap item from `docs/development.rst`. (history)
- `origin/riscv` — head `87e588e` (2021-10): WIP riscv64 support, blocked on upstream packaging. (history)
- `origin/test-release` — head `813b140` "fix" (content: "print items", "mkdir", "fix"; 2023-01): unpublished release-automation tweaks to the CLI/debian report. (history)
- `origin/test/service` — head `e917589` "ci: add GHA workflow 'service'" (2020-11): a `service` workflow that never made it to main; workflow consolidation removed it early. (history)
- `gh-pages` — single orphan root commit `dafad2a`; entirely regenerated by BuildTheDocs. (history)

## 11. CI workflow sprawl remnants

- Workflows were consolidated over time from multiple small files (`push.yml`, `check.yml`, `docs.yml`, `service.yml`, `Canary.yml`, plus prior Travis config) into today's `Test.yml` + `Canary.yml`. (history) — `push.yml`→`Test.yml` rename (`dac45e6` era; ~59% rename similarity), `check` split to `Canary.yml` (`edd315b`), Travis deleted (`42bde80`).
- `Test.yml` still uses `with-post-step` / docker-login-style credential plumbing with `${{ secrets.DOCKER_PASS }}` and runtime `docker login`. (code) — `Test.yml` Images/Manifests jobs.
- CI can only publish images when `github.repository == 'dbhi/qus'` on non-PR runs — fork PRs silently skip deploys but still run the whole matrix. (code) — `Test.yml`.

## 12. Runtime/environment assumptions

- All scripts assume `curl`, GNU `tar`, `dpkg`, `rpm2cpio`, `cpio`, `zstdcat`, `sudo`, and docker are present (some only on certain paths); the fedora extraction specifically needs `zstd` RPM support. (code) — `run.sh:40-59`, `test.sh`.
- `register.sh` registers via `/proc/sys/fs/binfmt_misc/` and requires `sudo`; in-container registration (uppercase jobs) needs `--privileged`. (code) — `register.sh:123-124`, `test.sh:41`.
- Test/CI depends on `ubuntu:bionic` images (now at EOL) both for cross-compilation (`generate_bin_tests.sh:36`) and as the test containers (`test.sh:83,125,137`). (code)
- Single-maintainer history and a linear default branch (`main`) means convention knowledge (release flow, "update X to Y" bumps, feature-branch abandonment) is mostly in `git log` and not in docs. (history/inference)