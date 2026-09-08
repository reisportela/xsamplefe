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
if ("`OUT'" == "") local OUT "sweep_core23_results.csv"
file open R using "`OUT'", write text replace
file write R "dataset,N,fes,units,units_sampled,N_unit_sample,t_unit16,t_unit1,det_ok,integrity_ok,t_unit2,t_movers,components,t_obs,t_sample,parity_ok,t_balanced,xhdfe_N,xhdfe_conv,xhdfe_t,reghdfe_N,reghdfe_t,max_b_diff" _n
file close R

capture program drop xsf_sweep_body
program define xsf_sweep_body
    args name fes y xs clvar timevar do_reghdfe
    di as result _n "===================== `name' ====================="
    local N = _N
    local nfe : word count `fes'
    local fe1 : word 1 of `fes'
    local fe2 : word 2 of `fes'
    gen long __id = _n
    timer clear
    * unit-level sample (unit = first FE), 16 threads
    set seed 1
    timer on 1
    xsamplefe 10, absorb(`fes') generate(sU) numthreads(16)
    timer off 1
    local units = r(N_units)
    local usamp = r(N_units_sampled)
    local NU = r(N)
    * determinism: 1 thread
    set seed 1
    timer on 2
    xsamplefe 10, absorb(`fes') generate(sU1) numthreads(1)
    timer off 2
    quietly count if sU != sU1
    local det_ok = (r(N) == 0)
    * integrity: whole units
    quietly bysort `fe1' (sU): gen byte __bad = sU[1] != sU[_N]
    quietly count if __bad
    local integ_ok = (r(N) == 0)
    sort __id
    * unit = second FE
    local t_unit2 .
    local t_mov .
    local ncomp .
    if (`nfe' >= 2) {
        set seed 2
        timer on 3
        xsamplefe 10, absorb(`fes') unit(`fe2') generate(sU2) numthreads(16)
        timer off 3
        quietly timer list 3
        local t_unit2 = r(t3)
        set seed 3
        timer on 4
        xsamplefe 10, absorb(`fes') movers(100) stayers(5) connected generate(sM) numthreads(16)
        timer off 4
        quietly timer list 4
        local t_mov = r(t4)
        local ncomp = r(n_components)
    }
    * observation-level parity with sample
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
    drop __inS
    * balanced panel when a time variable exists
    local t_bal .
    if ("`timevar'" != "") {
        set seed 5
        timer on 7
        xsamplefe 20, absorb(`fes') time(`timevar') balanced generate(sB) numthreads(16)
        timer off 7
        quietly timer list 7
        local t_bal = r(t7)
    }
    quietly timer list
    local t1 = r(t1)
    local t2 = r(t2)
    local t5 = r(t5)
    local t6 = r(t6)
    * estimation on the unit sample
    timer on 8
    xhdfe `y' `xs' if sU == 1, absorb(`fes') vce(cluster `clvar') numthreads(16)
    timer off 8
    quietly timer list 8
    local xt = r(t8)
    local xN = e(N)
    local xconv = e(converged)
    matrix bX = e(b)
    local rN .
    local rt .
    local maxdiff .
    if (`do_reghdfe') {
        timer on 9
        reghdfe `y' `xs' if sU == 1, absorb(`fes') vce(cluster `clvar')
        timer off 9
        quietly timer list 9
        local rt = r(t9)
        local rN = e(N)
        matrix bR = e(b)
        local k = colsof(bX)
        local maxdiff 0
        forvalues j = 1/`k' {
            local d = abs(bX[1, `j'] - bR[1, `j'])
            if (`d' > `maxdiff') local maxdiff = `d'
        }
    }
    di as result "SWEEP `name': N=`N' units=`units' sampled=`usamp' NU=`NU' t16=`t1' t1=`t2' det=`det_ok' integ=`integ_ok' parity=`parity_ok' t_obs=`t5' t_sample=`t6' xhdfe=`xN'/`xconv' reghdfe=`rN' maxdiff=`maxdiff'"
    file open R using "$SWEEP_OUT", write text append
    file write R "`name',`N',`fes',`units',`usamp',`NU',`t1',`t2',`det_ok',`integ_ok',`t_unit2',`t_mov',`ncomp',`t5',`t6',`parity_ok',`t_bal',`xN',`xconv',`xt',`rN',`rt',`maxdiff'" _n
    file close R
end
global SWEEP_OUT "`OUT'"

* every case writes a row: on failure the dataset name and the rc are recorded
capture program drop xsf_fail
program define xsf_fail
    args name rc
    di as error "SWEEP `name': FAILED rc=`rc'"
    file open R using "$SWEEP_OUT", write text append
    file write R "`name',ERROR,rc=`rc'" _n
    file close R
end

capture program drop xsf_sweep
program define xsf_sweep
    local name : word 1 of `0'
    capture noisily xsf_sweep_body `0'
    if (_rc) xsf_fail `name' `=_rc'
end

* small fixtures first
capture noisily use "`XHDFE_ROOT'/stata/example/data/felsdvsimul.dta", clear
if (_rc) xsf_fail felsdvsimul `=_rc'
else {
    describe, short
    xsf_sweep felsdvsimul "i j" y "x1 x2" i "" 1
}
capture noisily do "`XHDFE_ROOT'/tests/stata/fixtures/toy-patents-chain.do"
if (_rc) xsf_fail toy_patents_chain `=_rc'
else {
    toy_dificil 128 2
    xsf_sweep toy_patents_chain "inventor_id year" citations "funding lab_size" inventor_id year 1
}
* Sergio core datasets
foreach d in credit2 soccer synthetic-zigzag credit directors enron patents synthetic-complete synthetic-uniform-easy synthetic-uniform-hard synthetic-uniform-harder {
    capture noisily use "`SERGIO'/`d'.dta", clear
    if (_rc) xsf_fail `d' `=_rc'
    else xsf_sweep `d' "id1 id2" y "x1 x2" id1 "" 1
}
capture noisily use "`SERGIO'/synthetic-assortative.dta", clear
if (_rc) xsf_fail synthetic-assortative `=_rc'
else xsf_sweep synthetic-assortative "id1 id2 year" y "x1 x2" id1 year 1
capture noisily use "`SERGIO'/github.dta", clear
if (_rc) xsf_fail github `=_rc'
else xsf_sweep github "id1 id2 id3" y "x1 x2" id1 "" 1
capture noisily use "`SERGIO'/schools.dta", clear
if (_rc) xsf_fail schools `=_rc'
else xsf_sweep schools "id1 id2 id3" y "x1 x2" id1 "" 1
capture noisily use "`SERGIO'/workers.dta", clear
if (_rc) xsf_fail workers `=_rc'
else xsf_sweep workers "id1 id2 id3 id4" y "x1 x2" id1 "" 1
* pyfixest DGP 1M and 10M
capture noisily pq use using "`PF'/benchmark_difficult_n1000000_k10.parquet", clear
if (_rc) xsf_fail pf_difficult_1m `=_rc'
else xsf_sweep pf_difficult_1m "indiv_id firm_id year" y "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10" indiv_id year 1
capture noisily pq use using "`PF'/benchmark_simple_n10000000_k10.parquet", clear
if (_rc) xsf_fail pf_simple_10m `=_rc'
else xsf_sweep pf_simple_10m "indiv_id firm_id year" y "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10" indiv_id year 0
capture noisily pq use using "`PF'/benchmark_difficult_n10000000_k10.parquet", clear
if (_rc) xsf_fail pf_difficult_10m `=_rc'
else xsf_sweep pf_difficult_10m "indiv_id firm_id year" y "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10" indiv_id year 0
* main_95_21_ready (47.6M, proprietary, local)
capture noisily pq use using "`READY'", clear
if (_rc) xsf_fail main_95_21_ready `=_rc'
else xsf_sweep main_95_21_ready "w_id f_id year" log_rhwage "age_sq tenure tenure_sq educ" w_id year 1
di as result "SWEEP DONE"
