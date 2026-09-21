"""Exercise installer failures without building, launching, or stopping an app."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class InstallTests(unittest.TestCase):
    def test_replacement_preserves_previous_app_on_failure(self):
        cases = [(failure, True) for failure in ("", "build", "backup", "swap", "rollback", "interrupt")]
        cases += [("", False), ("swap", False)]
        for failure, existing in cases:
            with self.subTest(failure=failure, existing=existing), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                applications = root / "Applications"
                app = applications / "Blackout.app"
                applications.mkdir()
                if existing:
                    app.mkdir()
                    (app / "version").write_text("previous")
                preferences = root / "preferences"
                preferences.write_text("password and language")
                commands = root / "commands"
                commands.mkdir()

                def script(path, body):
                    path.write_text("#!/bin/zsh\nset -eu\n" + body)
                    path.chmod(0o755)

                # Redirect only the fixed install destination; execute the actual installer logic.
                source = (ROOT / "scripts/install.command").read_text()
                self.assertEqual(source.count('APP_DIR="$HOME/Applications/Blackout.app"'), 1)
                source = source.replace(
                    'APP_DIR="$HOME/Applications/Blackout.app"',
                    'APP_DIR="$INSTALL_TEST_DIR/Applications/Blackout.app"',
                )
                (root / "install.command").write_text(source)
                script(root / "build.command", '''
print -r -- "$1" > "$INSTALL_TEST_DIR/build-output"
[[ "$INSTALL_TEST_FAILURE" != build ]] || exit 23
mkdir -p "$1"
print -rn -- new > "$1/version"
''')
                for command in ("xcrun", "pkill", "sleep", "open"):
                    script(commands / command, "exit 0\n")
                script(commands / "mv", '''
if [[ "$2" == "$INSTALL_TEST_DIR/Applications/Blackout.app" ]]; then
  if [[ "$1" == */Blackout.app && "$INSTALL_TEST_FAILURE" == (swap|rollback) ]] ||
     [[ "$1" == */Previous.app && "$INSTALL_TEST_FAILURE" == rollback ]]; then
    exit 24
  fi
elif [[ "$1" == "$INSTALL_TEST_DIR/Applications/Blackout.app" ]]; then
  [[ "$INSTALL_TEST_FAILURE" != backup ]] || exit 25
  if [[ "$INSTALL_TEST_FAILURE" == interrupt ]]; then
    /bin/mv "$@"
    kill -TERM "$PPID"
    exit 0
  fi
fi
exec /bin/mv "$@"
''')
                result = subprocess.run(
                    ["/bin/zsh", str(root / "install.command")],
                    env={**os.environ, "PATH": f"{commands}:/usr/bin:/bin:/usr/sbin:/sbin",
                         "INSTALL_TEST_DIR": str(root), "INSTALL_TEST_FAILURE": failure},
                    capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode == 0, not failure, result.stderr)
                previous = list(applications.glob(".Blackout-install.*/Previous.app"))
                if failure == "rollback":
                    self.assertEqual(len(previous), 1, result.stderr)
                    self.assertEqual((previous[0] / "version").read_text(), "previous")
                    self.assertIn(str(previous[0]), result.stderr)
                elif existing or not failure:
                    self.assertTrue(app.exists(), result.stderr)
                    self.assertEqual((app / "version").read_text(), "previous" if failure else "new")
                    self.assertFalse(list(applications.glob(".Blackout-install.*")))
                else:
                    self.assertFalse(app.exists())
                    self.assertFalse(list(applications.glob(".Blackout-install.*")))
                self.assertEqual(preferences.read_text(), "password and language")
                staged = Path((root / "build-output").read_text().strip())
                self.assertEqual(staged.parent.parent, applications)


if __name__ == "__main__":
    unittest.main()
