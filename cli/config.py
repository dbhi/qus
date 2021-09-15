#!/usr/bin/env python3

# Copyright 2020-2021 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
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

from pathlib import Path

from yaml import load

try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper


class Config:

    def __init__(self):
        with (Path(__file__).parent / "config.yml").open("r") as fptr:
            CONFIG = load(fptr, Loader=Loader)
        self._archs = CONFIG["archs"]
        pass

    def keys(self):
        return [item for item in self._archs]

    def _normalise_arch(self, arch):
        """
        Return the normalised name of one of archs.
        """
        for key, val in self._archs.items():
            if key == arch:
                return key
            if "alias" in val:
                alias = val["alias"]
                if alias is not None:
                    if arch in alias:
                        return key
        raise Exception("Unknown architecture {}".format(arch))

    def normalise_arch(self, usage, arch):
        """
        Return the name of one of the archs, normalised for a given usage.
        """
        key = self._normalise_arch(arch)
        return self._archs[key][usage] if usage in self._archs[key] else key

    def version(self, usage, host):
        """
        Return the version of one of the archs, normalised for a given usage.
        """
        key = self._normalise_arch(host)
        ver = self._archs[key]["version"][usage]
        return (ver["base"], ver["rev"])

if __name__ == "__main__":
    from sys import argv as sys_argv
    print(Config().normalise_arch(sys_argv[1], sys_argv[2]))
