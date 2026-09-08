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
describe
timer clear
* A: 10% of groups (unit = group; mobility = individual = team size)
set seed 1
timer on 1
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) generate(sA) numthreads(16) verbose
timer off 1
return list
* B: 10% of firms (unit = ntrab), groups closed by any
set seed 1
timer on 2
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(ntrab) generate(sB) numthreads(16)
timer off 2
return list
* C: 10% of individuals (unit = p_ntrab), closure any
set seed 1
timer on 3
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(p_ntrab) generate(sC) numthreads(16)
timer off 3
return list
* D: stratified by year, teams of 2-4 members only
set seed 1
timer on 4
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) by(year) minmobility(2) maxmobility(4) generate(sD) numthreads(16)
timer off 4
return list
* E: connected set after sampling
set seed 1
timer on 5
xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) connected generate(sE) numthreads(16)
timer off 5
return list
* F: individuals with movers/stayers rates, groups closed
set seed 1
timer on 6
xsamplefe 5, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(p_ntrab) movers(20) stayers(2) generate(sF) numthreads(16)
timer off 6
return list
* thread scaling on A
local i 30
foreach t in 1 8 48 {
    local ++i
    set seed 1
    timer on `i'
    xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) generate(st`t') numthreads(`t')
    timer off `i'
    di "threads_used = " r(threads_used) "  (timer `i')"
}
assert sA == st1 & sA == st8 & sA == st48
di as result "THREAD DETERMINISM OK on 3M"
timer list
* integrity: whole groups
foreach s in sA sB sC sD sE sF {
    bysort p_groupid: egen byte mn_`s' = min(`s')
    bysort p_groupid: egen byte mx_`s' = max(`s')
    assert mn_`s' == mx_`s'
}
di as result "GROUP INTEGRITY OK on 3M"
* regression on sample A: reghdfe vs xhdfe
preserve
keep if sA == 1
timer on 20
reghdfe lhwage FTC tenure tenure2, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) aggregation(sum)
timer off 20
matrix bR = e(b)
timer on 21
xhdfe lhwage FTC tenure tenure2, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) aggregation(sum) numthreads(16)
timer off 21
matrix bX = e(b)
matrix D = bR - bX
matrix list D
restore
timer list
di as result "MARTA DONE"
