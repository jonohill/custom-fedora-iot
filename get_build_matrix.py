#!/usr/bin/env python3

import json
import sys

from datetime import datetime
from subprocess import run
from urllib.request import urlopen

def err(msg):
    print(msg, file=sys.stderr)

if len(sys.argv) != 2:
    err("Usage: get_build_matrix.py <output_image>")
    sys.exit(1)

output_image = sys.argv[1]

PATH_PREFIX = "./linux/releases/"

latest = None
with urlopen("https://dl.fedoraproject.org/pub/fedora/imagelist-fedora") as f:
    data = f.read().decode("utf-8")
    for line in data.splitlines():
        if not line.startswith(PATH_PREFIX):
            continue
        version_val = line.split("/")[3]
        try:
            version = int(version_val)
            if latest is None or version > latest:
                latest = version
        except ValueError:
            version = version_val

if latest is None:
    err("Couldn't read the latest Fedora release")
    sys.exit(1)

err(f"The latest Fedora release is {latest}")

stable = latest - 1
testing = latest + 1

versions = ["rawhide", testing, latest, stable, latest - 2]
archs = ["arm64", "amd64"]

err(f"Checking for versions ({' '.join(map(str, versions))}) on archs ({' '.join(archs)})")

IMAGE_REGISTRY = "quay.io"
IMAGE_REPO = "fedora/fedora-iot"

today = datetime.now().strftime("%Y%m%d")

result = run(["skopeo", "--version"], check=False, capture_output=True)
if result.returncode != 0:
    err("skopeo is not available")
    sys.exit(1)

output = {
    "images": [],
    "manifests": []
}

for version in versions:

    try:
        if int(version) <= 40:
            # dnf not available in container for <= 40
            continue
    except ValueError:
        pass

    for arch in archs:
        err(f"Checking {version}/{arch}")

        result = run(
            ["skopeo", "inspect", f"docker://{IMAGE_REGISTRY}/{IMAGE_REPO}:{version}", "--override-os", "linux", "--override-arch", arch], 
            capture_output=True, text=True
        )

        if result.returncode != 0:
            continue

        manifest = json.loads(result.stdout)

        available_arch = manifest["Architecture"]
        if available_arch != arch:
            continue

        tags = [str(version), f"{version}.{today}"]

        if version == latest:
            tags.extend(["latest", f"latest.{today}"])
        if version == stable:
            tags.extend(["stable", f"stable.{today}"])
        if version == testing:
            tags.extend(["testing", f"testing.{today}"])

        runner = "ubuntu-24.04"
        if arch == "arm64":
            runner += "-arm"
            
        image = {
            "version_tag": f"{version}.{today}-{arch}",
            "tags": ",".join(map(lambda t: f"{output_image}:{t}-{arch}", tags)),
            "runner": runner,
            "image_base": f"{IMAGE_REGISTRY}/{IMAGE_REPO}",
            "image_tag": version
        }
        output["images"].append(image)

        for tag in tags:
            manifest_tag = f"{output_image}:{tag}"
            manifest = next((m for m in output["manifests"] if m["tag"] == manifest_tag), None)
            if manifest is None:
                manifest = {
                    "tag": manifest_tag,
                    "images": []
                }
                output["manifests"].append(manifest)
            manifest["images"].append(f"{output_image}:{tag}-{arch}")

for manifest in output["manifests"]:
    manifest["images"] = " ".join(manifest["images"])

print(json.dumps(output))
