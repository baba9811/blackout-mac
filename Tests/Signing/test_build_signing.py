"""Run the real build preflight, stopping at the external compiler boundary."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class BuildSigningTests(unittest.TestCase):
    def test_release_requires_identity_and_explicit_choice_overrides_local_config(self):
        fingerprint = "A" * 40
        cases = [
            (None, None, "1", 1),
            (None, "-", "1", 1),
            (None, "invalid", "1", 1),
            (None, fingerprint, "1", 97),
            (fingerprint, None, "1", 97),
            (fingerprint, "-", "1", 1),
            ("invalid", None, "1", 1),
            (None, None, "0", 97),
        ]
        for configured, explicit, required, expected in cases:
            with self.subTest(configured=configured, explicit=explicit, required=required), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                (root / "scripts").mkdir()
                shutil.copy(ROOT / "scripts/build.command", root / "scripts/build.command")
                (root / "VERSION").write_text("0.1.1\n")
                commands = root / "commands"
                commands.mkdir()
                compiler = commands / "xcrun"
                compiler.write_text("#!/bin/sh\nexit 97\n")
                compiler.chmod(0o755)
                if configured is not None:
                    subprocess.run(["git", "init", "-q", str(root)], check=True)
                    subprocess.run(["git", "-C", str(root), "config", "--local", "blackout.signingIdentity", configured], check=True)
                environment = {key: value for key, value in os.environ.items() if not key.startswith("BLACKOUT_")}
                environment.update(PATH=f"{commands}:/usr/bin:/bin:/usr/sbin:/sbin", BLACKOUT_REQUIRE_SIGNING=required)
                if explicit is not None:
                    environment["BLACKOUT_SIGN_IDENTITY"] = explicit
                result = subprocess.run(["zsh", str(root / "scripts/build.command"), str(root / "Blackout.app")],
                                        env=environment, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertFalse((root / "Blackout.app").exists())


if __name__ == "__main__":
    unittest.main()
