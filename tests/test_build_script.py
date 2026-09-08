"""Build-plan contracts; foreign plans are not native-platform certification."""
from pathlib import Path
import os
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "stata/tools/build-xsamplefe-plugin.sh"


class BuildPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (ROOT / "tests/output").mkdir(exist_ok=True)

    def run_script(self, *args, env=None):
        clean = {k: v for k, v in os.environ.items()
                 if not k.startswith(("XSAMPLEFE_", "XHDFE_", "LIBOMP_PREFIX"))
                 and k not in {"CXX", "OBJDUMP"}}
        clean.update(env or {})
        return subprocess.run(["bash", str(SCRIPT), *args], env=clean,
                              text=True, capture_output=True)

    def plan(self, *args, env=None):
        result = self.run_script(*args, "--dry-run", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        command = next(line for line in result.stdout.splitlines() if line.startswith("  "))
        self.assertIn("have not been validated", result.stdout)
        return shlex.split(command)

    def test_linux_openmp_and_separate_output(self):
        cmd = self.plan("--linux")
        self.assertEqual(cmd[0], "g++")
        self.assertIn("-DSYSTEM=OPUNIX", cmd)
        self.assertIn("-fopenmp", cmd)
        self.assertTrue(cmd[-1].endswith("xsamplefe_linux64.plugin"))
        self.assertNotIn("-march=native", cmd)

    def test_windows_has_static_runtimes(self):
        cmd = self.plan("--windows", env={"CXX": "x86_64-w64-mingw32-g++"})
        for flag in ["-DSYSTEM=STWIN32", "-std=gnu++17", "-m64", "-static",
                     "-static-libgcc", "-static-libstdc++", "-fopenmp"]:
            self.assertIn(flag, cmd)
        self.assertTrue(any(x.endswith("mingw_stdio_shim.h") for x in cmd))
        self.assertTrue(cmd[-1].endswith("xsamplefe_win64.plugin"))

    def test_mac_architectures_and_runtime_paths(self):
        for option, arch, platform, variable in [
            ("--macos-arm64", "arm64", "macarm64", "LIBOMP_PREFIX_ARM64"),
            ("--macos-intel", "x86_64", "macintel64", "LIBOMP_PREFIX_X86_64"),
        ]:
            with self.subTest(arch=arch):
                prefix = str(ROOT / "tests/output/libomp prefix, with spaces")
                cmd = self.plan(option, env={variable: prefix})
                self.assertEqual(cmd[cmd.index("-arch") + 1], arch)
                self.assertIn("-DSYSTEM=APPLEMAC", cmd)
                self.assertIn("-bundle", cmd)
                self.assertIn("-Xpreprocessor", cmd)
                self.assertIn(prefix + "/lib/libomp.dylib", cmd)
                self.assertIn(prefix + "/lib", cmd)
                self.assertNotIn("-static", cmd)
                self.assertTrue(cmd[-1].endswith(f"xsamplefe_{platform}.plugin"))

    def test_dry_run_does_not_create_output(self):
        with tempfile.TemporaryDirectory(prefix="xsamplefe-plan-", dir=ROOT / "tests/output") as tmp:
            dest = Path(tmp) / "new directory, spaces" / "my.plugin"
            cmd = self.plan("--linux", "--output", str(dest))
            self.assertEqual(cmd[-1], str(dest))
            self.assertFalse(dest.parent.exists())

    def test_invalid_options_fail_without_compiling(self):
        for args in [("--arch",), ("--output",), ("--linux", "--arch", "arm64"),
                     ("--macos-intel", "--march-native"), ("--output", "manual.ado"),
                     ("--arch", "universal"), ("--unknown",)]:
            with self.subTest(args=args):
                self.assertNotEqual(self.run_script(*args, "--dry-run").returncode, 0)

    def test_explicit_options_override_legacy_environment(self):
        cmd = self.plan("--linux", "--openmp", "--no-march-native", env={
            "XHDFE_TARGET": "windows", "XHDFE_OPENMP": "off",
            "XHDFE_ENABLE_MARCH_NATIVE": "on", "WSL_DISTRO_NAME": "test"})
        self.assertIn("-DSYSTEM=OPUNIX", cmd)
        self.assertIn("-fopenmp", cmd)
        self.assertNotIn("-march=native", cmd)

    def test_failed_compiler_preserves_previous_binary(self):
        with tempfile.TemporaryDirectory(prefix="xsamplefe-failure-", dir=ROOT / "tests/output") as tmp:
            dest = Path(tmp) / "existing.plugin"
            dest.write_bytes(b"previous binary sentinel")
            result = self.run_script("--linux", "--output", str(dest), env={"CXX": "false"})
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(dest.read_bytes(), b"previous binary sentinel")
            self.assertEqual(sorted(p.name for p in Path(tmp).iterdir()), ["existing.plugin"])

    @unittest.skipUnless(os.uname().sysname == "Linux", "Linux host check")
    def test_real_mac_build_rejects_linux_before_runtime_lookup(self):
        result = self.run_script("--macos-arm64")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot build macos on Linux", result.stderr)


if __name__ == "__main__":
    unittest.main()
