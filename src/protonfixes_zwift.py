from subprocess import run
from urllib.request import urlretrieve

import __main__ as protonmain

from protonfixes import util

def main() -> None:
    util.protontricks('corefonts dotnet48 d3dcompiler_47 webview2')

    util.regedit_add('HKCU\\Software\\Wine\\Drivers', name='Graphics', value='x11,wayland')
