* ===========================================================================
* xsamplefe certification: run every Stata test and require the PASS marker
* ===========================================================================

version 16
clear all
set more off
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

discard
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

di as text _n "{hline 72}"
di as text "Running xsamplefe_cert.do"
di as text "{hline 72}"
do "`testdir'/xsamplefe_cert.do"

di as text _n "{hline 72}"
di as text "XSAMPLEFE CERTIFICATION TESTS COMPLETED SUCCESSFULLY"
di as text "{hline 72}"
