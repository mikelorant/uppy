#!/usr/bin/python3
"""Correct Swift Build's Xcode-style paths when using Command Line Tools.

Only two known, nonexistent CLT layout paths are rewritten to existing CLT
locations. Linker diagnostics are never filtered and the toolchain is not changed.
"""
import os
import shlex
import subprocess
import sys
from pathlib import Path


def correct(arguments, developer):
    root = Path(developer)
    replacements = {
        str(root / "Developer/usr/lib"): str(root / "usr/lib"),
        str(root / "Developer/Library/Frameworks"): str(root / "Library/Frameworks"),
    }
    result = []
    for argument in arguments:
        if argument.startswith("@") and not argument.startswith(("@loader_path", "@executable_path", "@rpath")) and Path(argument[1:]).is_file():
            result.extend(correct(shlex.split(Path(argument[1:]).read_text()), developer))
            continue
        prefix = ""
        path = argument
        if argument.startswith(("-L", "-F")):
            prefix, path = argument[:2], argument[2:]
        replacement = replacements.get(path)
        if replacement and not Path(path).exists() and Path(replacement).is_dir():
            argument = prefix + replacement
        result.append(argument)
    return result


def main():
    linker = subprocess.check_output(["/usr/bin/xcrun", "--find", "ld"], text=True).strip()
    developer = subprocess.check_output(["/usr/bin/xcode-select", "-p"], text=True).strip()
    arguments = sys.argv[1:]
    if Path(developer).name == "CommandLineTools":
        arguments = correct(arguments, developer)
    os.execv(linker, [linker, *arguments])


if __name__ == "__main__":
    main()
