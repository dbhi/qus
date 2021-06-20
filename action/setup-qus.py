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

from sys import stdout, stderr
from os import environ
from subprocess import check_call

targets = environ.get("INPUT_TARGETS")

print("> setup-qus: {}".format(targets))

cmd = ["docker", "run", "--rm", "--privileged", "aptman/qus", "-s", "--", "-p"]


def _exec(cmd):
    print("> {}".format(cmd))
    stdout.flush()
    stderr.flush()
    check_call(cmd)


_exec(["docker", "pull", "aptman/qus"])


if targets is None:
    _exec(cmd)
else:
    for target in targets.replace("\n", " ").split(" "):
        _exec(cmd + [target])
