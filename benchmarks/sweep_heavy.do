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
set linesize 200
set more off
local OUT : env XSF_OUT
if ("`OUT'" == "") local OUT "sweep_heavy_results.csv"
file open R using "`OUT'", write text replace
file write R "dataset,N,fes,units,units_sampled,N_unit_sample,t_unit16,t_unit48,t_unit1,det_ok,integrity_ok,t_obs,t_sample,parity_ok,xhdfe_N,xhdfe_conv,xhdfe_t" _n
file close R
global SWEEP_OUT "`OUT'"

capture program drop xsf_heavy_body
program define xsf_heavy_body
    args name fes y xs clvar
    di as result _n "===================== `name' ====================="
    local N = _N
    local fe1 : word 1 of `fes'
    gen long __id = _n
    timer clear
    set seed 1
    timer on 1
    xsamplefe 10, absorb(`fes') generate(sU) numthreads(16)
    timer off 1
    local units = r(N_units)
    local usamp = r(N_units_sampled)
    local NU = r(N)
    set seed 1
    timer on 2
    xsamplefe 10, absorb(`fes') generate(sU48) numthreads(48)
    timer off 2
    set seed 1
    timer on 3
    xsamplefe 10, absorb(`fes') generate(sU1) numthreads(1)
    timer off 3
    quietly count if sU != sU1 | sU != sU48
    local det_ok = (r(N) == 0)
    drop sU1 sU48
    quietly bysort `fe1' (sU): gen byte __bad = sU[1] != sU[_N]
    quietly count if __bad
    local integ_ok = (r(N) == 0)
    drop __bad
    sort __id
    set seed 4
    timer on 5
    xsamplefe 10, generate(sO) numthreads(16)
    timer off 5
    preserve
    set seed 4
    timer on 6
    sample 10
    timer off 6
    keep __id
    gen byte __inS = 1
    tempfile S
    quietly save `S'
    restore
    quietly merge 1:1 __id using `S', nogen
    quietly count if (sO == 1) != (__inS == 1)
    local parity_ok = (r(N) == 0)
    drop __inS sO
    quietly timer list
    local t1 = r(t1)
    local t2 = r(t2)
    local t3 = r(t3)
    local t5 = r(t5)
    local t6 = r(t6)
    keep if sU == 1
    timer on 8
    xhdfe `y' `xs', absorb(`fes') vce(cluster `clvar') numthreads(16)
    timer off 8
    quietly timer list 8
    local xt = r(t8)
    local xN = e(N)
    local xconv = e(converged)
    di as result "SWEEP `name': N=`N' units=`units' sampled=`usamp' NU=`NU' t16=`t1' t48=`t2' t1=`t3' det=`det_ok' integ=`integ_ok' parity=`parity_ok' t_obs=`t5' t_sample=`t6' xhdfe=`xN'/`xconv' xt=`xt'"
    file open R using "$SWEEP_OUT", write text append
    file write R "`name',`N',`fes',`units',`usamp',`NU',`t1',`t2',`t3',`det_ok',`integ_ok',`t5',`t6',`parity_ok',`xN',`xconv',`xt'" _n
    file close R
end


* every case writes a row: on failure the dataset name and the rc are recorded
capture program drop xsf_fail
program define xsf_fail
    args name rc
    di as error "SWEEP `name': FAILED rc=`rc'"
    file open R using "$SWEEP_OUT", write text append
    file write R "`name',ERROR,rc=`rc'" _n
    file close R
end

capture program drop xsf_heavy
program define xsf_heavy
    local name : word 1 of `0'
    capture noisily xsf_heavy_body `0'
    if (_rc) xsf_fail `name' `=_rc'
end

capture noisily pq use using "`AKM1'", clear
if (_rc) xsf_fail akm_v02_firstreg `=_rc'
else xsf_heavy akm_v02_firstreg "idtrab ano NPC_FIC" ln_wgain_hour_wz "exp_akm exp_akm_sq_100 exp_akm_cu_1000 exp_akm_qt_10000 firm_seniority_obs firm_seniority_spline10" idtrab
capture noisily pq use using "`AKM2'", clear
if (_rc) xsf_fail akm_v02_secondreg_data `=_rc'
else xsf_heavy akm_v02_secondreg_data "idtrab ano NPC_FIC" ln_wgain_hour_wz "exp_akm exp_akm_sq_100 exp_akm_cu_1000 exp_akm_qt_10000" idtrab
capture noisily pq use worker_id year firm_id occupation_id education experience experience_sq union ln_wage using "`SIM'", clear
if (_rc) xsf_fail simulated_panel `=_rc'
else xsf_heavy simulated_panel "worker_id firm_id occupation_id year" ln_wage "education experience experience_sq union" worker_id
di as result "HEAVY DONE"
