* Paths: override with environment variables (defaults are the development host)
local xsf_ado : env XSAMPLEFE_ADOPATH
if ("`xsf_ado'" == "") local xsf_ado "/home/mangelo/Documents/GitHub/xsamplefe/stata"
local xhdfe_ado : env XHDFE_ADOPATH
if ("`xhdfe_ado'" == "") local xhdfe_ado "/home/mangelo/Documents/GitHub/xhdfe/stata"
local XHDFE_ROOT : env XHDFE_ROOT
if ("`XHDFE_ROOT'" == "") local XHDFE_ROOT "/home/mangelo/Documents/GitHub/xhdfe"
local SERGIO : env XSF_SERGIO_DIR
if ("`SERGIO'" == "") local SERGIO "/home/mangelo/Documents/BigData/Sergio/all-dta"
local PF : env XSF_PF_DIR
if ("`PF'" == "") local PF "/srv/projetos/P008/dataset/pyfixest"
local READY : env XSF_READY
if ("`READY'" == "") local READY "/home/mangelo/Documents/BigData/Paulo/main_95_21_ready.parquet"
local AKM1 : env XSF_AKM1
if ("`AKM1'" == "") local AKM1 "/home/mangelo/Documents/GitHub/xhdfe/benchmarks/_out/akm_v02_firstreg_full_fast_comparable_5x_20260619_163305/akm_v02_firstreg_common.parquet"
local AKM2 : env XSF_AKM2
if ("`AKM2'" == "") local AKM2 "/srv/projetos/P008/04_to_test_xhdfe/data/coauthor_base/derived/akm_v02_r_julia_full/akm_v02_r_julia.parquet"
local SIM : env XSF_SIM
if ("`SIM'" == "") local SIM "/home/mangelo/Documents/BigData/Simulated_Data/simulated_panel.parquet"
local MARTA : env XSF_MARTA
if ("`MARTA'" == "") local MARTA "`XHDFE_ROOT'/benchmarks/data/marta_core24_group_individual_3m.parquet"
adopath ++ "`xhdfe_ado'"
adopath ++ "`xsf_ado'"
set linesize 160
pq use using "`MARTA'", clear
set seed 1
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(ntrab) generate(sB) numthreads(16)
set seed 1
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(p_ntrab) generate(sC) numthreads(16)
set seed 1
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(p_ntrab) grouprule(all) generate(sG) numthreads(16)
timer clear
foreach s in sB sC sG {
    preserve
    keep if `s' == 1
    timer on 1
    reghdfe lhwage FTC tenure tenure2, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) aggregation(sum)
    timer off 1
    timer on 2
    xhdfe lhwage FTC tenure tenure2, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) aggregation(sum) numthreads(16)
    timer off 2
    timer list
    timer clear
    restore
}
di as result "MARTA REG DONE"
