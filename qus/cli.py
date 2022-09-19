#!/usr/bin/env python3

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


from pathlib import Path
from os import listdir
from sys import exit as sys_exit

from pyAttributes.ArgParseAttributes import (
    ArgParseMixin,
    ArgumentAttribute,
    Attribute,
    CommandAttribute,
    CommonSwitchArgumentAttribute,
    DefaultAttribute,
    SwitchArgumentAttribute,
)

from config import Config
from assets import get_json_from_api, extract_from_json, releases_report
from debian import (
    check_debian_latest,
    get_debs_list,
    get_debs,
    debian_report,
    extract_debs,
)
from fedora import check_fedora_latest


ROOT = Path(__file__).parent.parent


class Tool:
    HeadLine = "dbhi/qus CLI tool"

    def __init__(self):
        pass

    def PrintHeadline(self):
        print("{line}".format(line="=" * 80))
        print("{headline: ^80s}".format(headline=self.HeadLine))
        print("{line}".format(line="=" * 80))

    @staticmethod
    def assets(fname: Path = ROOT / "releases.json", report: Path = ROOT / "report.md"):
        (TARGETS, TABLES) = extract_from_json(get_json_from_api(fname))
        TARGETS.sort()
        releases_report(TARGETS, TABLES, report)

    @staticmethod
    def debian(report: Path = ROOT / "debian.md"):
        tmpdir = ROOT / "tmp_deb"
        debs = get_debs_list()
        get_debs(debs, tmpdir)
        targets = []
        extract_debs(targets, debs, tmpdir)
        targets.sort()
        debian_report(targets, debs, report)


class CLI(Tool, ArgParseMixin):
    def __init__(self):
        import argparse
        import textwrap

        # Call constructor of the main interitance tree
        super().__init__()
        # Call constructor of the ArgParseMixin
        ArgParseMixin.__init__(
            self,
            description=textwrap.dedent(
                "Tool for building (multiarch) images, and for easily browsing publicly available tags and assets."
            ),
            epilog=textwrap.fill("Happy hacking!"),
            formatter_class=argparse.RawDescriptionHelpFormatter,
            add_help=False,
        )

    def Run(self):
        ArgParseMixin.Run(self)

    @DefaultAttribute()
    def HandleDefault(self, args):
        self.PrintHeadline()
        self.MainParser.print_help()

    @CommandAttribute("help", help="Display help page(s) for the given command name.")
    @ArgumentAttribute(
        metavar="<Command>",
        dest="Command",
        type=str,
        nargs="?",
        help="Print help page(s) for a command.",
    )
    def HandleHelp(self, args):
        if args.Command == "help":
            print("This is a recursion ...")
            return
        if args.Command is None:
            self.PrintHeadline()
            self.MainParser.print_help()
        else:
            try:
                self.PrintHeadline()
                self.SubParsers[args.Command].print_help()
            except KeyError:
                print("Command {0} is unknown.".format(args.Command))

    @CommandAttribute("check", help="Check if new releases are available upstream (Debian/Fedora).")
    def HandleCheck(self, _):
        ecode = 0
        if check_debian_latest() is not None:
            ecode = 1
        if check_fedora_latest() is not None:
            ecode = 1
        sys_exit(ecode)

    @CommandAttribute("arch", help="Get normalised architecture key/name.")
    @ArgumentAttribute(
        "-u",
        "--usage",
        dest="Usage",
        type=str,
        help="Target usage to get the normalised name for.",
        default=None,
    )
    @ArgumentAttribute(
        "-a",
        "--arch",
        dest="Arch",
        type=str,
        help="Target architecture to get the normalised name for.",
        default="amd64",
    )
    def HandleArch(self, args):
        print(Config().normalise_arch(args.Usage, args.Arch))

    @CommandAttribute("version", help="Get version items for a usage and host (arch).")
    @ArgumentAttribute(
        "-u",
        "--usage",
        dest="Usage",
        type=str,
        help="Target usage to get the version for.",
        default=None,
    )
    @ArgumentAttribute(
        "-a",
        "--arch",
        dest="Arch",
        type=str,
        help="Target architecture to get the version for.",
        default="amd64",
    )
    def HandleVersion(self, args):
        items = Config().version(args.Usage, args.Arch)
        print(f"{items[0]} {items[1]}")

    @CommandAttribute("assets", help="Generate report of available releases and assets.")
    def HandleAssets(self, _):
        self.assets()

    @CommandAttribute("debian", help="Generate report of available resources in DEB packages.")
    def HandleDebian(self, _):
        self.debian()


if __name__ == "__main__":
    CLI().Run()
