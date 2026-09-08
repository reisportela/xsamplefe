* ===========================================================================
* xsamplefe certification: run every Stata test and require the PASS marker
* ===========================================================================

version 16
clear all
set more off
set varabbrev off
set linesize 120
capture log close _all

local testdir : env XSAMPLEFE_TEST_DIR
if (`"`testdir'"' == "") {
    local testdir "`c(pwd)'"
}
local adopath : env XSAMPLEFE_ADOPATH
if (`"`adopath'"' == "") {
    local adopath "`testdir'/../stata"
}

local xhdfe_adopath : env XHDFE_ADOPATH
local fixture_dir : env XSAMPLEFE_FIXTURE_DIR
if (`"`fixture_dir'"' != "") global S_WEB `"`fixture_dir'"'

discard
if (`"`xhdfe_adopath'"' != "") adopath ++ `"`xhdfe_adopath'"'
adopath ++ `"`adopath'"'
capture which xsamplefe
if (c(rc)) {
    di as error "xsamplefe not found: build the plugin and set XSAMPLEFE_ADOPATH."
    exit 601
}
which xsamplefe
capture which reghdfe
if (c(rc)) {
    di as error "reghdfe not found: install it (ssc install reghdfe) to run the certification."
    exit 601
}
capture which sample2
if (c(rc)) {
    di as error "sample2 not found: install it (net install dm46, from(http://www.stata.com/stb/stb37)) to run the certification."
    exit 601
}

* harness self-test (tests/selftest.sh): inject a failing certification file
* before the real ones; unset, this changes nothing
local selftest : env XSAMPLEFE_SELFTEST
if ("`selftest'" == "1") {
    di as text _n "{hline 72}"
    di as text "Running xsamplefe_selftest_fail.do (harness self-test)"
    di as text "{hline 72}"
    do "`testdir'/xsamplefe_selftest_fail.do"
}

di as text _n "{hline 72}"
di as text "Running xsamplefe_cert.do"
di as text "{hline 72}"
do "`testdir'/xsamplefe_cert.do"

di as text _n "{hline 72}"
di as text "Running xsamplefe_compat_cert.do"
di as text "{hline 72}"
do "`testdir'/xsamplefe_compat_cert.do"

di as text _n "{hline 72}"
di as text "Running xsamplefe_estimation_cert.do"
di as text "{hline 72}"
do "`testdir'/xsamplefe_estimation_cert.do"

di as text _n "{hline 72}"
di as text "Running xsamplefe_mobility_cert.do"
di as text "{hline 72}"
do "`testdir'/xsamplefe_mobility_cert.do"

do "`testdir'/xsamplefe_adversarial_cert.do"
do "`testdir'/xsamplefe_binding_cert.do"

di as text _n "{hline 72}"
di as text "XSAMPLEFE CERTIFICATION TESTS COMPLETED SUCCESSFULLY"
di as text "{hline 72}"
