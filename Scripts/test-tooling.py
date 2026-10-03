#!/usr/bin/python3
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("clt_linker", Path(__file__).with_name("clt-linker.py"))
linker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(linker)


class LinkerPaths(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name) / "CommandLineTools"
        (self.root / "usr/lib").mkdir(parents=True)
        (self.root / "Library/Frameworks").mkdir(parents=True)

    def test_only_known_missing_paths_are_corrected(self):
        old_lib = str(self.root / "Developer/usr/lib")
        old_frameworks = str(self.root / "Developer/Library/Frameworks")
        arguments = ["-L" + old_lib, "-F", old_frameworks, "-L/unrelated/missing", "-fatal_warnings"]
        expected = ["-L" + str(self.root / "usr/lib"), "-F", str(self.root / "Library/Frameworks"), "-L/unrelated/missing", "-fatal_warnings"]
        self.assertEqual(linker.correct(arguments, str(self.root)), expected)

    def test_existing_paths_are_never_replaced(self):
        old = self.root / "Developer/usr/lib"
        old.mkdir(parents=True)
        self.assertEqual(linker.correct(["-L" + str(old)], str(self.root)), ["-L" + str(old)])

    def test_response_files_and_runtime_paths(self):
        response = self.root / "link.rsp"
        response.write_text('"-F' + str(self.root / "Developer/Library/Frameworks") + '" -rpath @loader_path')
        result = linker.correct(["@" + str(response), "@rpath/libExample.dylib"], str(self.root))
        self.assertEqual(result, ["-F" + str(self.root / "Library/Frameworks"), "-rpath", "@loader_path", "@rpath/libExample.dylib"])

    def test_missing_replacement_preserves_original_diagnostic(self):
        (self.root / "usr/lib").rmdir()
        original = "-L" + str(self.root / "Developer/usr/lib")
        self.assertEqual(linker.correct([original], str(self.root)), [original])


if __name__ == "__main__":
    unittest.main()
