* Deliberately failing "certification" file. It is run only by tests/selftest.sh
* (through XSAMPLEFE_SELFTEST=1) to prove that the harness reports a failure:
* run_tests.sh must exit non-zero and testall.log must not carry the success
* marker. Nothing else runs this file.

noi di as text "xsamplefe harness self-test: the assert below must fail"
sysuse auto, clear
assert _N == 0
noi di as error "xsamplefe harness self-test: this line must never be reached"
