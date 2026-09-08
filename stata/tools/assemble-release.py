#!/usr/bin/env python3
"""Assemble only the four native CI outputs that passed the plugin SPI test."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PLATFORMS = ("linux64", "win64", "macintel64", "macarm64")
FRONTEND = ("xsamplefe.ado", "xsamplefe.sthlp", "xsamplefe.pkg", "stata.toc",
            "xsamplefe_basics.do", "xsamplefe_tour.do", "xsamplefe_check.do", "xsamplefe_license.txt")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assemble(artifacts, out):
    if out.exists():
        raise ValueError("Use a new output directory; previous releases are preserved")
    out.mkdir(parents=True)
    version = re.search(r"version (\d+\.\d+\.\d+)", (ROOT / "stata/xsamplefe.ado").read_text().splitlines()[0])[1]
    receipts = {}
    for platform in PLATFORMS:
        directory = artifacts / ("xsamplefe-" + platform)
        if (directory / "native_spi.txt").read_text().strip() != "XSAMPLEFE NATIVE PLUGIN SPI TEST PASSED":
            raise ValueError(f"Native SPI verification missing for {platform}")
        receipt = json.loads((directory / f"{platform}_build.json").read_text())
        if receipt["git_commit"] != os.environ["GITHUB_SHA"]:
            raise ValueError(f"Mixed source commits: {platform}")
        names = [f"xsamplefe_{platform}.plugin"]
        if platform.startswith("mac"):
            names += [f"xsamplefe_libomp_{platform}.dylib", f"xsamplefe_{platform}_runtime_license.txt"]
        elif platform == "win64":
            names += ["xsamplefe_win64_runtime_license.txt"]
        for name in names:
            shutil.copy2(directory / name, out / name)
        receipt["native_spi"] = "PASS"
        receipts[platform] = receipt
    for name in FRONTEND:
        shutil.copy2(ROOT / "stata" / name, out / name)
    pkg = (out / "xsamplefe.pkg").read_text()
    additions = []
    for platform, machines in {"macintel64": ("MACINTEL64", "OSX.X8664"),
                               "macarm64": ("MACARM64", "OSX.ARM64")}.items():
        additions += [f"G {machine} xsamplefe_libomp_{platform}.dylib" for machine in machines]
    additions += [f"F xsamplefe_{platform}_runtime_license.txt" for platform in ("win64", "macintel64", "macarm64")]
    (out / "xsamplefe.pkg").write_text(pkg + "\n".join(additions) + "\n")
    metadata = {"version": version, "commit": os.environ["GITHUB_SHA"],
                "workflow_run": os.environ.get("GITHUB_RUN_ID"), "platforms": receipts,
                "native_stata_validation": "performed separately on the exact Linux artifact",
                "installation": "https://github.com/reisportela/xsamplefe/releases/latest/download"}
    (out / "RELEASE.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    payload = sorted(p.name for p in out.iterdir() if p.is_file())
    sources = ["src/xsamplefe_plugin.cpp", "tools/build-xsamplefe-plugin.sh", "tools/mingw_stdio_shim.h",
               "tools/_deps/stplugin.h", "tools/_deps/stplugin.c"]
    for platform in (None, *PLATFORMS):
        archive = out / ("xsamplefe.zip" if platform is None else f"xsamplefe-{platform}.zip")
        chosen = [name for name in payload if not name.endswith((".plugin", ".dylib")) or platform is None
                  or name in (f"xsamplefe_{platform}.plugin", f"xsamplefe_libomp_{platform}.dylib")]
        files = {"README.md": ROOT / "README.md", "INSTALL.md": ROOT / "INSTALL.md", "LICENSE": ROOT / "LICENSE",
                 "docs/VALIDATION.md": ROOT / "docs/VALIDATION.md"}
        files.update({"stata/" + name: out / name for name in chosen})
        files.update({"stata/" + name: ROOT / "stata" / name for name in sources})
        with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED) as z:
            for name, source in sorted(files.items()):
                z.write(source, "xsamplefe/" + name)
        with zipfile.ZipFile(archive) as z:
            if z.testzip() is not None:
                raise ValueError(f"Corrupt archive: {archive}")
    hashes = {p.name: sha(p) for p in sorted(out.iterdir()) if p.is_file()}
    (out / "SHA256SUMS.txt").write_text("".join(f"{value}  {name}\n" for name, value in hashes.items()))
    print(f"Release {version}: {len(hashes)} assets plus SHA256SUMS.txt; all four native probes passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assemble(args.artifacts, args.output)
