import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
COMPLETE = {
    "isDraft": False,
    "assets": [
        {"name": "BlackoutMac-0.1.0-universal.dmg", "size": 1024},
        {"name": "BlackoutMac-0.1.0-universal.zip", "size": 2048},
        {"name": "SHA256SUMS", "size": 192},
    ],
}


class VerifyReleaseTests(unittest.TestCase):
    def verify(self, release, version="0.1.0"):
        return subprocess.run(
            [sys.executable, str(ROOT / "scripts/verify-release.py"), version],
            input=json.dumps(release), text=True, capture_output=True,
        )

    def test_accepts_published_release_with_all_three_nonempty_assets(self):
        result = self.verify(COMPLETE)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_draft_missing_or_empty_assets_and_wrong_version(self):
        cases = []
        draft = copy.deepcopy(COMPLETE)
        draft["isDraft"] = True
        cases.append(("draft", draft, "0.1.0"))
        for index in range(3):
            missing = copy.deepcopy(COMPLETE)
            del missing["assets"][index]
            cases.append((f"missing asset {index}", missing, "0.1.0"))
            empty = copy.deepcopy(COMPLETE)
            empty["assets"][index]["size"] = 0
            cases.append((f"empty asset {index}", empty, "0.1.0"))
        cases.append(("another version", COMPLETE, "0.2.0"))
        cases.append(("missing release state", {"assets": COMPLETE["assets"]}, "0.1.0"))
        for label, release, version in cases:
            with self.subTest(label=label):
                result = self.verify(release, version)
                self.assertEqual(result.returncode, 1, result.stderr)


if __name__ == "__main__":
    unittest.main()
