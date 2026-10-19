import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import struct

spec = importlib.util.spec_from_file_location("installer", Path(__file__).with_name("install.py"))
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / "package"
        self.source.mkdir()
        for name in ["launch.sh", "PocketFrameNative.arm64"]:
            (self.source / name).write_text("test payload")
        self.manifest = {"version": "0.1.0-preview.1", "files": {name: installer.digest(self.source / name) for name in ["launch.sh", "PocketFrameNative.arm64"]}}
        (self.source / "manifest.json").write_text(json.dumps(self.manifest))
        self.root = self.base / "install"

    def test_update_preserves_games_and_previous(self):
        first = installer.install(self.source, self.root, self.manifest, False)
        (self.root / "games/owned.cci").write_bytes(b"owned original")
        self.manifest["version"] = "0.1.0-preview.2"
        second = installer.install(self.source, self.root, self.manifest, False)
        self.assertEqual((self.root / "current").resolve(), second)
        self.assertEqual((self.root / "previous").resolve(), first)
        self.assertEqual((second / "games/owned.cci").read_bytes(), b"owned original")

    def test_corrupt_update_does_not_switch(self):
        first = installer.install(self.source, self.root, self.manifest, False)
        (self.source / "launch.sh").write_text("corruption")
        self.manifest["version"] = "0.1.0-preview.2"
        with self.assertRaises(ValueError):installer.install(self.source, self.root, self.manifest, False)
        self.assertEqual((self.root / "current").resolve(), first)

    def test_idempotent_install(self):
        first = installer.install(self.source, self.root, self.manifest, False)
        self.assertEqual(installer.install(self.source, self.root, self.manifest, False), first)
        self.assertFalse((self.root / "previous").exists())

    def test_manifest_traversal_rejected(self):
        for name in ["../secret", "/etc/passwd", "runtime/../../other", "runtime\\other"]:
            with self.assertRaises(ValueError):installer.relative(name)

    def test_source_symlinks_rejected(self):
        (self.source / "launch.sh").unlink()
        (self.source / "launch.sh").symlink_to(self.source / "PocketFrameNative.arm64")
        with self.assertRaises(ValueError):installer.verify(self.source, self.manifest)

    def test_import_never_overwrites_or_moves(self):
        games = self.base / "games";games.mkdir()
        destination = self.base / "target";destination.mkdir()
        (games / "owned.cci").write_bytes(b"original")
        (destination / "owned.cci").write_bytes(b"keep")
        self.assertEqual(installer.import_games(games, destination), 0)
        self.assertEqual((destination / "owned.cci").read_bytes(), b"keep")
        self.assertEqual((games / "owned.cci").read_bytes(), b"original")

    def test_failed_runtime_check_keeps_active(self):
        first = installer.install(self.source, self.root, self.manifest, False)
        self.manifest["version"] = "0.1.0-preview.2"
        old = installer.RUNTIME
        installer.RUNTIME = self.base / "nonexistent"
        try:
            with self.assertRaises(OSError):installer.install(self.source, self.root, self.manifest, True)
        finally:installer.RUNTIME = old
        self.assertEqual((self.root / "current").resolve(), first)

    def test_binary_vdf_capitalized_root(self):
        data = b'\x00Shortcuts\0\x000\0\x01AppName\0Devkit Game: PocketFrame\0\x02appid\0' + struct.pack('<I',4149411747) + b'\x08\x08\x08'
        result = installer.read_shortcuts(data)
        self.assertEqual(result['Shortcuts']['0']['appid'], 4149411747)

    def test_rollback_retains_both_releases(self):
        first = installer.install(self.source, self.root, self.manifest, False)
        self.manifest['version']='0.1.0-preview.2'
        second = installer.install(self.source, self.root, self.manifest, False)
        installer.switch_link(self.root, 'current', (self.root/'previous').resolve())
        self.assertEqual((self.root/'current').resolve(),first)
        self.assertTrue(first.is_dir() and second.is_dir())


if __name__ == "__main__":unittest.main()
