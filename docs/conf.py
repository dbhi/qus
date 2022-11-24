# -*- coding: utf-8 -*-

# Copyright 2021 Unai Martinez-Corral <unai.martinezcorral@ehu.eus>
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


from sys import path as sys_path
from os.path import abspath
from pathlib import Path
from json import loads
from tabulate import tabulate

ROOT = Path(__file__).resolve().parent

sys_path.insert(0, abspath("."))

with (ROOT / "TestsTable.inc").open("w", encoding="utf-8") as wfptr:
    wfptr.write(tabulate(
        [
            ["" , "``aptman/qus``"         , "n" , "y" , "y " , "\-"                  , ""     , ""          , "n" ],
            ["f", "``register.sh``"        , "n" , "y" , "y " , "``/usr/bin/$file``"  , "host ", "[curl]"    , "n" ],
            ["F", "``aptman/qus:register``", "n" , "y" , "y*" , "``/usr/bin/$file``"  , "host ", "[curl]"    , "n" ],
            ["c", "``register.sh``"        , "n" , "y" , "y " , "``$(pwd)/$file``"    , "host ", "[curl]"    , "n" ],
            ["C", "``aptman/qus:register``", "n" , "y" , "y*" , "``$(pwd)/$file``"    , "host ", "[curl]"    , "n" ],
            ["v", "``register.sh``"        , "n" , "y" , "n " , "``$(pwd)/$file``"    , "host ", "[curl]"    , "y" ],
            ["V", "``aptman/qus:register``", "n" , "y" , "n " , "``$(pwd)/$file``"    , "host ", "[curl]"    , "y" ],
            ["i", "``register.sh``"        , "n" , "y" , "n " , "``$file``"           , "image", "[add/copy]", "n" ],
            ["I", "``aptman/qus:register``", "n" , "y" , "n " , "``$file``"           , "image", "[add/copy]", "n" ],
            ["d", "``register.sh``"        , "n" , "y" , "n " , "``qemu-user``"       , "image", "[apt]"     , "n" ],
            ["D", "``aptman/qus:register``", "n" , "y" , "n " , "``qemu-user``"       , "image", "[apt]"     , "n" ],
            ["r", "``register.sh``"        , "y" , "y" , "y " , "``qemu-user-static``", "host ", "[apt]"     , "n" ],
            ["R", "``aptman/qus:register``", "y" , "y" , "y*" , "``qemu-user-static``", "host ", "[apt]"     , "n" ],
            ["s", "\-"                     , "\-", "\-", "\-" , "``qemu-user-static``", "host ", "[apt]"     , "y" ],
            ["n", "\-"                     , "\-", "\-", "\-" , "``qemu-user-binfmt``", "host ", "[apt]"     , "\-"],
            ["h", "``register.sh``"        , "y" , "n" , "y"  , "``qemu-user``"       , "host ", "[apt]"     , "n" ],
            ["H", "``aptman/qus:register``", "y" , "n" , "y*" , "``qemu-user``"       , "host ", "[apt]"     , "n" ],
        ],
        headers=["Job","Register method","-r","-s","-p","Dependency","Install method","vol",],
        tablefmt="rst"
    ))

# -- General configuration ------------------------------------------------

extensions = [
    # Standard Sphinx extensions
    #"sphinx.ext.autodoc",
    "sphinx.ext.extlinks",
    "sphinx.ext.intersphinx",
    #"sphinx.ext.graphviz",
    #"sphinx.ext.viewcode",
    "sphinxcontrib.bibtex"
]

bibtex_default_style = 'plain'
bibtex_bibfiles = [
    str(ROOT / 'references/Containers.bib'),
]
for item in bibtex_bibfiles:
    if not Path(item).exists():
        raise Exception(f"Bibliography file {item} does not exist!")

#autodoc_default_options = {
#    "members": True,
#    #"private-members": True,
#    "undoc-members": True,
#}

source_suffix = {
    ".rst": "restructuredtext",
}

master_doc = "index"

project = u"qemu-user-static (qus) and containers"
copyright = u"2019-2022, Unai Martinez-Corral"
author = u"Unai Martinez-Corral and contributors"

# TODO: it would be interesting if Sphinx supported additional metadata for each author.
# name: Unai Martinez-Corral
# url: https://github.com/umarcor
# affiliation: "Digital Electronics Design Group, University of the Basque Country (UPV/EHU)"
# affiliation_url: https://ehu.eus/gded

version = "latest"
release = version  # The full version, including alpha/beta/rc tags.

language = None

exclude_patterns = []

# reST settings
#prologPath = "prolog.inc"
#try:
#    with open(prologPath, "r") as prologFile:
#        rst_prolog = prologFile.read()
#except Exception as ex:
#    print("[ERROR:] While reading '{0!s}'.".format(prologPath))
#    print(ex)
#    rst_prolog = ""

numfig = True

# -- Options for HTML output ----------------------------------------------

html_context = {}
ctx = ROOT / "context.json"
if ctx.is_file():
    html_context.update(loads(ctx.open("r", encoding="utf-8").read()))

if (ROOT / "_theme").is_dir():
	html_theme_path = ["."]
	html_theme = "_theme"
	html_theme_options = {
		'logo_only': True,
		'home_breadcrumbs': False,
		'vcs_pageview_mode': 'blob',
	}
else:
	html_theme = "alabaster"

html_static_path = ["_static"]

html_logo = str(Path(html_static_path[0]) / "logo" / "logo_blur.png")
html_favicon = str(Path(html_static_path[0]) / "logo" / "favicon.svg")

htmlhelp_basename = "qusDoc"

# -- Options for LaTeX output ---------------------------------------------

latex_elements = {
    "papersize": "a4paper",
}

latex_documents = [
    (master_doc, "qusDoc.tex", u"qemu-user-static (qus) and containers: Documentation", author, "manual"),
]

# -- Options for manual page output ---------------------------------------

# One entry per manual page. List of tuples
# (source start file, name, description, authors, manual section).
man_pages = [(master_doc, "qus", u"qemu-user-static (qus) and containers: Documentation", [author], 1)]

# -- Options for Texinfo output -------------------------------------------

texinfo_documents = [
    (
        master_doc,
        "qus",
        u"qemu-user-static (qus) and containers: Documentation",
        author,
        "qus",
        "Containers",
        "Miscellaneous",
    ),
]

# -- Sphinx.Ext.InterSphinx -----------------------------------------------

intersphinx_mapping = {
    "python": ("https://docs.python.org/3/", None)
}

# -- Sphinx.Ext.ExtLinks --------------------------------------------------
extlinks = {
    "wikipedia": ("https://en.wikipedia.org/wiki/%s", None),
    "qussharp": ("https://github.com/dbhi/qus/issues/%s", "#"),
    "qusissue": ("https://github.com/dbhi/qus/issues/%s", "issue #"),
    "quspull": ("https://github.com/dbhi/qus/pull/%s", "pull request #"),
    "qussrc": ("https://github.com/dbhi/qus/blob/main/%s", ''),
}
