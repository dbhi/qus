#!/usr/bin/env python3

from tabulate import tabulate

def TestsTable():

    print(tabulate(
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