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
clear
set seed 2026
set obs 20000000
gen long worker = ceil(_n / 10)
gen int year = 2000 + mod(_n - 1, 10)
gen long firm = ceil(runiform() * 200000)
bysort worker: replace firm = firm[1] if runiform() < 0.85
timer clear
set seed 1
timer on 1
xsamplefe 10, absorb(worker firm year) generate(s48) numthreads(48) verbose
timer off 1
return list
set seed 1
timer on 2
xsamplefe 10, absorb(worker firm year) generate(s1) numthreads(1)
timer off 2
assert s48 == s1
set seed 1
timer on 3
xsamplefe 10, absorb(worker firm year) generate(s8) numthreads(8)
timer off 3
set seed 1
timer on 4
xsamplefe 10, generate(o) numthreads(48)
timer off 4
set seed 1
timer on 5
sample 10
timer off 5
timer list
di as result "SYNTH DONE"
