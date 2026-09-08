* Run by testall.do in the fresh output directory selected by run_tests.sh.
local source : env XSAMPLEFE_ADOPATH
local output : env XSAMPLEFE_TEST_OUTDIR
mkdir "`output'/plugin_alternate"
mkdir "`output'/plugin_missing"
copy "`source'/xsamplefe.ado" "`output'/plugin_alternate/xsamplefe.ado"
copy "`source'/xsamplefe.plugin" "`output'/plugin_alternate/xsamplefe.plugin"
copy "`source'/xsamplefe.ado" "`output'/plugin_missing/xsamplefe.ado"

clear
set obs 100
gen long worker = ceil(_n / 5)
xsamplefe 50, unit(worker) seed(1) generate(reference) numthreads(1)
local state = c(rngstate)

* A loaded plugin from a different location must be refused until discard.
adopath ++ "`output'/plugin_alternate"
capture xsamplefe 50, unit(worker) seed(1) generate(alternate) numthreads(1)
assert _rc == 498
assert c(rngstate) == "`state'"
discard
xsamplefe 50, unit(worker) seed(1) generate(alternate) numthreads(1)
assert alternate == reference

* Missing binaries preserve the RNG and data, and still return an error.
local state = c(rngstate)
adopath ++ "`output'/plugin_missing"
discard
capture xsamplefe 50, unit(worker) seed(2) generate(missing_plugin) numthreads(1)
assert _rc == 601
assert c(rngstate) == "`state'"
assert _N == 100 & worker == ceil(_n / 5)
capture confirm variable missing_plugin
assert _rc == 111

adopath - "`output'/plugin_missing"
adopath - "`output'/plugin_alternate"
discard
xsamplefe 50, unit(worker) seed(1) generate(original) numthreads(1)
assert original == reference
noi di as result "XSAMPLEFE PLUGIN BINDING CERTIFICATION PASSED"
