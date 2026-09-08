#!/usr/bin/env python3
"""Collect a native CI binary; make Mac OpenMP dependencies relocatable."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[2]


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def collect(platform, out):
    out.mkdir(parents=True, exist_ok=True)
    plugin = out / f"xsamplefe_{platform}.plugin"
    shutil.copy2(ROOT / "stata" / plugin.name, plugin)
    receipt = {"platform": platform, "git_commit": os.environ.get("GITHUB_SHA", "local"),
               "plugin": plugin.name, "validation": "native SPI probe required"}
    if platform.startswith("mac"):
        arch = "arm64" if platform == "macarm64" else "x86_64"
        prefix = Path(command("brew", "--prefix", "libomp"))
        runtime = out / f"xsamplefe_libomp_{platform}.dylib"
        shutil.copy2(prefix / "lib/libomp.dylib", runtime)
        subprocess.run(["chmod", "u+w", str(plugin), str(runtime)], check=True)
        dependencies = command("otool", "-L", str(plugin)).splitlines()[1:]
        previous = [line.strip().split(" (", 1)[0] for line in dependencies if "libomp.dylib" in line]
        if len(previous) != 1:
            raise ValueError("Expected exactly one libomp dependency")
        relocated = "@loader_path/" + runtime.name
        subprocess.run(["install_name_tool", "-change", previous[0], relocated, str(plugin)], check=True)
        subprocess.run(["install_name_tool", "-id", relocated, str(runtime)], check=True)
        # The plugin now resolves libomp beside itself, independently of Homebrew.
        subprocess.run(["install_name_tool", "-delete_rpath", str(prefix / "lib"), str(plugin)], check=True)
        for path in (runtime, plugin):
            subprocess.run(["lipo", "-verify_arch", arch, str(path)], check=True)
            subprocess.run(["codesign", "--force", "--sign", "-", str(path)], check=True)
            subprocess.run(["codesign", "--verify", "--strict", str(path)], check=True)
            for line in command("otool", "-L", str(path)).splitlines()[1:]:
                dep = line.strip().split(" (", 1)[0]
                if not dep.startswith(("/usr/lib/", "/System/Library/", "@loader_path/")):
                    raise ValueError(f"Non-relocatable Mac dependency: {dep}")
        version = command("brew", "list", "--versions", "libomp").split()[1].split("_")[0]
        url = f"https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-{version}/openmp/LICENSE.TXT"
        text = urllib.request.urlopen(url, timeout=60).read().decode()
        notice = f"LLVM OpenMP {version}\nSource: {url}\nThe dylib install name was relocated and the binary ad-hoc signed for distribution.\n\n"
        (out / f"xsamplefe_{platform}_runtime_license.txt").write_text(notice + text)
        receipt.update(runtime=runtime.name, runtime_version=version, architecture=arch)
    elif platform == "win64":
        raw_prefix = os.environ["MINGW_PREFIX"]
        prefix = Path(raw_prefix)
        if os.name == "nt":
            prefix = Path(command("cygpath", "-w", raw_prefix))
        license_root = prefix / "share/licenses"
        licenses = [p for p in license_root.rglob("*") if p.is_file() and
                    any(word in str(p.relative_to(license_root)).lower() for word in ("gcc", "mingw", "winpthread"))]
        if not licenses:
            raise ValueError("MinGW/GNU runtime licence files were not found")
        text = "GNU and MinGW-w64 runtime notices from the native build toolchain.\n\n"
        for path in sorted(licenses):
            text += f"\n===== {path.relative_to(license_root)} =====\n" + path.read_text(errors="replace")
        (out / "xsamplefe_win64_runtime_license.txt").write_text(text)
    (out / f"{platform}_build.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=["linux64", "win64", "macarm64", "macintel64"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    collect(args.platform, args.output)
