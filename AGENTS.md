# AGENTS.md

qus builds/registers OCI images and binfmt interpreters that let you run foreign-architecture binaries using QEMU user-mode emulation. Ships a GitHub Action, a `qemu-binfmt-conf.sh` wrapper, a Python CLI, Sphinx docs, and a shell-based test matrix.

## Structure

- Top-level `*.sh` scripts are the real entry points (bash, `set -e`). There is no build tool / package manager.
- `cli/` — Python CLI (`cli/cli.py`, deps `pyAttributes`, `tabulate`, see `cli/requirements.txt`). `cli/config.yml` is the **single source of truth** for the arch-name mapping (docker vs debian vs fedora vs qemu names) and the tracked upstream qemu versions. `run.sh`'s `pkg_arch`/`guest_arch` are thin delegates to `cli/cli.py arch`, not logic.
- `action/` — GitHub Action (Docker-based action, `using: docker`).
- `docs/` — Sphinx docs, published by BuildTheDocs (`.btd.yml`, target `gh-pages`).

A full inventory of known pain points and where to start improving lives in `DEBT.md`.

## Scripts

- `register.sh` — wrapper around `qemu-binfmt-conf.sh`, written in **strict POSIX `sh`** (it is the `ENTRYPOINT` of busybox-based `-register` images) — no bashisms. Requires `sudo`. Needs `qemu-*-static` binaries on the host; `QEMU_BIN_DIR` (default `/usr/bin`) points at them. Reads `-- ARGS` for qemu-binfmt-conf.sh; `-s` adds `--suffix -static`; `-- -r` unregisters.
  - The conf script itself is NOT vendored: `register.sh` fetches it from the personal fork `umarcor/qemu@series-qemu-binfmt-conf` at runtime unless a local `./qemu-binfmt-conf.sh` or `/qemu-binfmt-conf.sh` exists. binfmt logic patches belong in that fork, not here.
- `run.sh` — image/manifest build automation. Modes: `-b` build one image, `-m` manifests, `-a` all assets. Key env: `BUILD` (debian|fedora), `BASE_ARCH`, `REPO` (default `docker.io/aptman/qus`), `QUS_RELEASE` (skips docker builds), `VERSION`. Downloads `.deb`/`.rpm` qemu packages and extracts static binaries with curl. Builds `pkg`/`register`/`final` images from `qus.dockerfile` via a `for` loop using `dockerd/builder` BuildKit with `--platform`/`--target`/`--build-arg` (no `DOCKER_BUILDKIT` env).
- `test.sh` — CI test matrix, driven by `QUS_JOB`. Lowercase jobs (`f c v i d`) use `register.sh` on the host; uppercase (`F C V I D`) use the `aptman/qus:register` container. Network, docker, sudo and binfmt support all required. Download the test binary from a pinned release tag: `TEST_RELEASE` (default `v0.0.11-v7.1+dfsg-2--bpo11+3`), override with `$1`.
- `generate_bin_tests.sh` — cross-compiles `test-aarch64`/`test-riscv64` inside `ubuntu:bionic`.

## Verify

- CLI: `python3 -m pip install -r cli/requirements.txt` (`.github/setup.sh`), then e.g. `./cli/cli.py check` (exit 1 if a new upstream release exists), `./cli/cli.py arch -u qemu -a arm64v8`. Beware undeclared deps: `requests`/`pyyaml` are not in `requirements.txt` (pulled implicitly via pyAttributes / runner images) and `cli/cli.py debian` needs the `7z` binary on the host.
- Docs: `make -C docs references` (fetches bib from `umarcor/umarcor`), then build via `.btd.yml` (buildthedocs/btd). `docs/conf.py` regenerates the gitignored `docs/TestsTable.inc` on every Sphinx run — don't commit it.
- `test.sh`/`run.sh` are not runnable in an unprivileged sandbox (need docker + sudo + binfmt); they also always hit the network.

## Conventions

- Updating a qemu version = editing `cli/config.yml` defaults (commit style seen in git log, e.g. "update debian to 7.2+dfsg-5"). `cli/cli.py check` only detects new versions (daily `Canary` workflow); bumping is manual. In the docker tags, `latest` manifest maps to the debian build (`run.sh` `manifests()`).
- CI Action jobs (`Action-*`) `needs: Manifests` — they run the published `aptman/qus` images, so the Action can't be validated independently of an image publish.
- Code style: Black with `line-length = 120` (`pyproject.toml`). Shell scripts are plain POSIX-ish bash with Apache-2.0 license headers.
- `.btd.yml` / docs deploy config drives the `gh-pages` branch; `releases/`, `bin-static/`, `main`, `releases.json`, `report.md`, `debian.md` are build artifacts of the scripts/CLI, not source.