#!/usr/bin/env python
#
# Copyright 2019-2022 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
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


from os import environ
from subprocess import check_call
from sys import stdout, stderr

from qus.config import Config
from qus.context import REPO


def update_manifests():
    arch_list = ["amd64", "arm64v8", "i386", "s390x", "ppc64le"]
    for build in ["latest", "debian", "fedora"]:
        isFedora = build == "fedora"
        isLatest = build == "latest"
        b_arch_list = arch_list + ([] if isFedora else ["arm32v6", "arm32v7"])

        version = ("f" if isFedora else "d") + Config().version("fedora" if isFedora else "debian", "amd64")[0]

        for image in ["latest", "pkg", "register"]:
            b_prefix = image if isLatest else ("" if image == "latest" else f"-{image}")
            manifest = f"{REPO}:{'' if isLatest else version}{b_prefix}"

            i_prefix = "" if image == "latest" else f"-{image}"
            image_list = [f"{REPO}:{arch}-{version}{i_prefix}" for arch in b_arch_list]

            print(f"[qus] Docker manifest {manifest}")
            print(f"[qus] Images:")
            print("\n".join(image_list))
            print("[qus] Create")
            stdout.flush()
            stderr.flush()
            check_call(["docker", "manifest", "create", "-a", manifest] + image_list)
            print("[qus] Push")
            check_call(["docker", "manifest", "push", "--purge", manifest])
            stdout.flush()
            stderr.flush()
