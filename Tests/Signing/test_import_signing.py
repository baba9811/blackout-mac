"""Exercise CI signing with an identity absent from the user's login keychain."""

import base64
import os
from pathlib import Path
import secrets
import shlex
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=30, **kwargs).stdout


class ImportSigningTests(unittest.TestCase):
    def test_fresh_identity_can_sign_without_a_login_keychain_copy(self):
        original = shlex.split(run("security", "list-keychains", "-d", "user"))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            keychain = root / "blackout-signing.keychain-db"
            environment = dict(os.environ, RUNNER_TEMP=temporary, GITHUB_ENV=str(root / "environment"),
                               BLACKOUT_SIGN_CERT_PASSWORD=secrets.token_hex(32))
            (root / "certificate.conf").write_text("""[req]
distinguished_name = subject
x509_extensions = extensions
prompt = no
[subject]
CN = Blackout disposable signing test
[extensions]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
""")
            try:
                run("/usr/bin/openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                    "-config", str(root / "certificate.conf"), "-keyout", str(root / "key.pem"),
                    "-out", str(root / "certificate.pem"))
                fingerprint = run("/usr/bin/openssl", "x509", "-in", str(root / "certificate.pem"),
                                  "-noout", "-fingerprint", "-sha1").strip().split("=", 1)[1].replace(":", "")
                run("/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(root / "key.pem"),
                    "-in", str(root / "certificate.pem"), "-out", str(root / "test.p12"),
                    "-passout", "env:BLACKOUT_SIGN_CERT_PASSWORD", env=environment)
                environment.update(BLACKOUT_SIGN_IDENTITY=fingerprint,
                                   BLACKOUT_SIGN_CERT_BASE64=base64.b64encode((root / "test.p12").read_bytes()).decode())
                run("zsh", str(ROOT / "scripts/ci/import-signing.command"), env=environment)
                self.assertFalse((root / "blackout-signing.p12").exists())
                probe = root / "probe"
                shutil.copy("/usr/bin/true", probe)
                result = subprocess.run(["codesign", "--force", "--sign", fingerprint, "--keychain", str(keychain), str(probe)],
                                        capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                run("codesign", "--verify", "--strict", str(probe))
            finally:
                try:
                    if keychain.exists():
                        run("security", "delete-keychain", str(keychain))
                finally:
                    run("security", "list-keychains", "-d", "user", "-s", *original)
        self.assertEqual(shlex.split(run("security", "list-keychains", "-d", "user")), original)


if __name__ == "__main__":
    unittest.main()
