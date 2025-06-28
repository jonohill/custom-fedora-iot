#!/usr/bin/env python3

import json
import sys

from datetime import datetime
from subprocess import run
from typing import TypedDict
from urllib.request import urlopen


class ImageDict(TypedDict):
    version_tag: str
    tags: str
    runner: str
    image_base: str
    image_tag: str | int
    with_rpi_kernel: str


class ManifestDict(TypedDict):
    tag: str
    images: list[str]  # Always a list during construction


class ManifestFinal(TypedDict):
    tag: str
    images: str  # Joined string in final output


class BuildOutput(TypedDict):
    images: list[ImageDict]
    manifests: list[ManifestDict]


class BuildOutputFinal(TypedDict):
    images: list[ImageDict]
    manifests: list[ManifestFinal]

def err(msg: str):
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

versions: list[int | str] = ["rawhide", testing, latest, stable, latest - 2]
archs = ["arm64", "amd64"]

err(f"Checking for versions ({' '.join(map(str, versions))}) on archs ({' '.join(archs)})")

IMAGE_REGISTRY = "quay.io"
IMAGE_REPO = "fedora/fedora-iot"

today = datetime.now().strftime("%Y%m%d")

result = run(["skopeo", "--version"], check=False, capture_output=True)
if result.returncode != 0:
    err("skopeo is not available")
    sys.exit(1)

output: BuildOutput = {
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

        docker_manifest = json.loads(result.stdout)

        available_arch = docker_manifest["Architecture"]
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
            
        # Set WITH_RPI_KERNEL to false for prerelease versions (rawhide and testing)
        is_prerelease = version == "rawhide" or version == testing
        with_rpi_kernel = "false" if is_prerelease else "true"
            
        image: ImageDict = {
            "version_tag": f"{version}.{today}-{arch}",
            "tags": ",".join(map(lambda t: f"{output_image}:{t}-{arch}", tags)),
            "runner": runner,
            "image_base": f"{IMAGE_REGISTRY}/{IMAGE_REPO}",
            "image_tag": version,
            "with_rpi_kernel": with_rpi_kernel
        }
        output["images"].append(image)

        for tag in tags:
            manifest_tag = f"{output_image}:{tag}"
            manifest: ManifestDict | None = next((m for m in output["manifests"] if m["tag"] == manifest_tag), None)
            if manifest is None:
                manifest = {
                    "tag": manifest_tag,
                    "images": []
                }
                output["manifests"].append(manifest)
            manifest["images"].append(f"{output_image}:{tag}-{arch}")

for manifest in output["manifests"]:
    # Convert images list to space-separated string for final output
    manifest["images"] = " ".join(manifest["images"])  # type: ignore[assignment]

# At this point, output conforms to BuildOutputFinal
final_output: BuildOutputFinal = output  # type: ignore[assignment]

print(json.dumps(final_output))
