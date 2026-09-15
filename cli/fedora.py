# Copyright 2020 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
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
#
# SPDX-License-Identifier: Apache-2.0


from os import environ
from pathlib import Path
from tabulate import tabulate
import requests
import re

from config import Config


TMP_RPM = Path(__file__).parent.parent / "tmp_rpm"


def _nat_key(s):
    return [
        (0, int(t)) if t.isdigit() else (1, t)
        for t in re.split(r"(\d+)", s)
        if t != ""
    ]


def check_fedora_latest():
    print("Check Fedora")

    url = "https://kojipkgs.fedoraproject.org/packages/qemu/"
    versions = []
    for line in requests.get(url, stream=True).iter_lines():
        reg = re.search('.*">(.*)/</a>.*', str(line))
        if reg is not None:
            versions.append(reg.group(1))

    latest = None
    for version in sorted(versions, key=_nat_key, reverse=True):
        subvers = []
        for vline in requests.get(url + version, stream=True).iter_lines():
            reg = re.search('.*/">(.*fc.*)/</a>.*', str(vline))
            if reg is not None:
                subvers.append(reg.group(1))
        for l in sorted(subvers, key=_nat_key, reverse=True):
            if ".rc" not in l:
                latest = (version, l)
                break
        if latest is not None:
            break

    if latest is None:
        raise (Exception("could not find the latest version!"))
    latest = f"{latest[0]}/{latest[1]}"

    fedver = Config().version('fedora', 'amd64')
    fedver = f"{fedver[0]}/{fedver[1]}"

    with Path(environ.get("GITHUB_STEP_SUMMARY", "summary.md")).open("a") as wfptr:
        if fedver != latest:
            wfptr.write(f"\n- [Fedora] Current: `{fedver}` | Latest: `{latest}`\n")
            return 1
        wfptr.write(f"\n- [Fedora] Up to date: `{latest}`\n")
