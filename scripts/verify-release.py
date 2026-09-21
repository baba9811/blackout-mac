#!/usr/bin/env python3
"""Validate JSON from gh release view before treating a version as published."""

import json
import re
import sys


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2 or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", sys.argv[1]):
            raise ValueError("Pass the expected major.minor.patch version")
        version = sys.argv[1]
        release = json.load(sys.stdin)
        if not isinstance(release, dict) or release.get("isDraft") is not False:
            raise ValueError("Release must be published, not a draft")
        assets = {
            asset.get("name"): asset.get("size")
            for asset in release.get("assets", []) if isinstance(asset, dict)
        }
        required = [
            f"BlackoutMac-{version}-universal.dmg",
            f"BlackoutMac-{version}-universal.zip",
            "SHA256SUMS",
        ]
        for name in required:
            size = assets.get(name)
            if type(size) is not int or size <= 0:
                raise ValueError(f"Release asset is missing or empty: {name}")
    except (ValueError, TypeError) as error:
        print(f"Release is incomplete: {error}", file=sys.stderr)
        sys.exit(1)
