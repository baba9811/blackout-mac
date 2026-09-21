"""Check two real, differently built apps; does not launch apps or grant permissions."""

import re
import subprocess
import sys


def codesign(*args):
    return subprocess.check_output(["codesign", *args], stderr=subprocess.STDOUT, text=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python3 Tests/Signing/verify_continuity.py First.app Updated.app")
    apps = sys.argv[1:]
    requirements = []
    hashes = []
    for app in apps:
        codesign("--verify", "--deep", "--strict", app)
        output = codesign("--display", "--requirements", "-", "--verbose=4", app)
        requirement = next(line.split("designated => ", 1)[1] for line in output.splitlines()
                           if "designated => " in line)
        assert 'identifier "local.blackout.overlay"' in requirement, "Unexpected app identity"
        assert re.search(r'(anchor|certificate root) = H"[0-9a-fA-F]{40}"', requirement), "Pin the signing certificate"
        assert "cdhash" not in requirement and " or " not in requirement, "Do not weaken identity checks"
        requirements.append(requirement)
        hashes.append(next(line for line in output.splitlines() if line.startswith("CDHash=")))
    assert hashes[0] != hashes[1], "Use two different builds, not two copies of one build"
    for app, requirement in zip(apps, reversed(requirements)):
        codesign("--verify", "--strict", "--test-requirement", "=" + requirement, app)
    print("Different builds satisfy each other's certificate-pinned identity. Check permission continuity on macOS separately.")
