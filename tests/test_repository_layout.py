"""Fast source-layout checks; no emulator, engine, downloads or user data required."""
import ast
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "PocketFrameNative"


class RepositoryLayoutTests(unittest.TestCase):
    def test_dependency_inputs_exist(self):
        for relative in (
            "third_party/azahar/CMakeLists.txt",
            "third_party/azahar/LICENSE.txt",
            "third_party/azahar/externals/libretro-common/libretro-common/include/libretro.h",
            "third_party/azahar/externals/vulkan-headers/include/vulkan/vulkan.h",
            "third_party/godot-cpp/CMakeLists.txt",
            "extension_api.json",
        ):
            with self.subTest(path=relative):
                self.assertTrue((ROOT / relative).is_file(), relative)

    def test_active_build_and_packager_use_current_layout(self):
        for relative in (
            "CMakeLists.txt", "tools/build-linux-arm64.sh",
            "tools/share/build-share.py", "native/pocketframe_azahar/CMakeLists.txt",
        ):
            text = (APP / relative).read_text(encoding="utf-8-sig")
            with self.subTest(path=relative):
                self.assertIn("third_party/azahar", text)
                self.assertIn("third_party/godot-cpp", text)
                self.assertNotIn("work/AzaharSource", text)
                self.assertNotIn("work/godot-cpp-main", text)

    def test_historical_manifest_paths_still_map_to_source(self):
        manifest = json.loads((ROOT / "SOURCE-MANIFEST.json").read_text())
        missing = []
        optional = "work/AzaharSource/externals/teakra/src/test_verifier/data/teaklite2_tests_result.bin"
        for old_path in manifest["source_files"]:
            if old_path == optional:
                continue
            current = old_path.replace("work/AzaharSource/", "third_party/azahar/", 1)
            current = current.replace("work/godot-cpp-main/", "third_party/godot-cpp/", 1)
            if not (ROOT / current).is_file():
                missing.append(current)
        self.assertEqual(missing, [])

    def test_project_python_syntax(self):
        for path in list((APP / "tools").rglob("*.py")) + list((ROOT / "tests").glob("*.py")):
            with self.subTest(path=str(path.relative_to(ROOT))):
                ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))

    def test_root_markdown_local_links(self):
        for path in ROOT.glob("*.md"):
            for target in re.findall(r"\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
                if "://" in target or target.startswith("#"):
                    continue
                with self.subTest(document=path.name, link=target):
                    self.assertTrue((ROOT / target.split("#", 1)[0]).exists(), target)


if __name__ == "__main__":
    unittest.main()
