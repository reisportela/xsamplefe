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
which xsamplefe
set linesize 140

* ---------- 1. parity with sample: no by ----------
sysuse auto, clear
gen long id = _n
set seed 20260908
sample 10
sort id
list id, clean noobs
local n1 = _N
quietly levelsof id, local(ids_sample)
sysuse auto, clear
gen long id = _n
set seed 20260908
xsamplefe 10
return list
sort id
quietly levelsof id, local(ids_x)
assert "`ids_sample'" == "`ids_x'"
di as result "PARITY OK: sample 10 vs xsamplefe 10"

* ---------- 2. parity with by() + if ----------
webuse nlswork, clear
gen long id = _n
set seed 42
sample 5 if age > 30, by(race year)
quietly levelsof id, local(ids_sample)
local n_s = _N
webuse nlswork, clear
gen long id = _n
set seed 42
xsamplefe 5 if age > 30, by(race year)
quietly levelsof id, local(ids_x)
assert "`ids_sample'" == "`ids_x'"
assert _N == `n_s'
di as result "PARITY OK: sample 5 if age>30, by(race year)"

* ---------- 3. parity with count + by ----------
webuse nlswork, clear
gen long id = _n
set seed 7
sample 3, count by(idcode)
quietly levelsof id, local(ids_sample)
webuse nlswork, clear
gen long id = _n
set seed 7
xsamplefe 3, count by(idcode)
quietly levelsof id, local(ids_x)
assert "`ids_sample'" == "`ids_x'"
di as result "PARITY OK: sample 3, count by(idcode)"

* ---------- 4. by varlist: prefix parity ----------
webuse nlswork, clear
gen long id = _n
sort race, stable
set seed 99
by race: sample 10
quietly levelsof id, local(ids_sample)
webuse nlswork, clear
gen long id = _n
sort race, stable
set seed 99
by race: xsamplefe 10
quietly levelsof id, local(ids_x)
assert "`ids_sample'" == "`ids_x'"
di as result "PARITY OK: by race: sample 10"

* ---------- 5. unit sampling (panel units) ----------
webuse nlswork, clear
set seed 1
xsamplefe 10, absorb(idcode year) generate(s)
return list
bysort idcode: egen mins = min(s)
bysort idcode: egen maxs = max(s)
assert mins == maxs
di as result "UNIT OK: whole idcode units"
* same seed, different threads -> identical
set seed 1
xsamplefe 10, absorb(idcode year) generate(s1) numthreads(1)
set seed 1
xsamplefe 10, absorb(idcode year) generate(s8) numthreads(8)
assert s == s1 & s == s8
di as result "DETERMINISM OK: threads 1 vs 8 vs auto"
* order invariance: shuffle rows, same seed -> same units
gen double shuffle = runiform()
sort shuffle
set seed 1
xsamplefe 10, absorb(idcode year) generate(s_sh)
assert s == s_sh
di as result "ORDER INVARIANCE OK"

* ---------- 6. balanced panel ----------
webuse nlswork, clear
set seed 3
xsamplefe 50, absorb(idcode year) time(year) balanced generate(b)
return list
bysort idcode year: gen byte first = _n == 1
bysort idcode: egen nyears = total(first)
quietly tab year
assert nyears == r(r) if b == 1
di as result "BALANCED OK"

* ---------- 7. mobility: movers/stayers rates + connected ----------
webuse nlswork, clear
set seed 5
xsamplefe 10, absorb(idcode ind_code year) movers(50) stayers(5) connected generate(m)
return list
bysort idcode ind_code: gen byte f = _n == 1
bysort idcode: egen nind = total(f)
gen byte mover = nind >= 2
tab mover m, missing
di as result "MOBILITY OK"

* ---------- 8. toy patents: group()/individual() ----------
use "`XHDFE_ROOT'/stata/example/data/toy-patents-long.dta", clear
set seed 11
xsamplefe 40, absorb(inventor_id) group(patent_id) individual(inventor_id) generate(g)
return list
bysort patent_id: egen ming = min(g)
bysort patent_id: egen maxg = max(g)
assert ming == maxg
di as result "GROUP CLOSURE OK (unit = patent)"
reghdfe citations funding if g == 1, a(inventor_id) group(patent_id) individual(inventor_id)
* individual as sampling unit
use "`XHDFE_ROOT'/stata/example/data/toy-patents-long.dta", clear
set seed 11
xsamplefe 30, absorb(inventor_id) group(patent_id) individual(inventor_id) unit(inventor_id) generate(g)
return list
bysort patent_id: egen ming = min(g)
bysort patent_id: egen maxg = max(g)
assert ming == maxg
di as result "GROUP CLOSURE OK (unit = inventor, any)"
use "`XHDFE_ROOT'/stata/example/data/toy-patents-long.dta", clear
set seed 11
xsamplefe 30, absorb(inventor_id) group(patent_id) individual(inventor_id) minmobility(3) maxmobility(6) generate(g)
bysort patent_id: gen ninv = _N
tab ninv g
* count mode with units + strata
use "`XHDFE_ROOT'/stata/example/data/toy-patents-long.dta", clear
set seed 12
xsamplefe 2, count group(patent_id) by(year) generate(g)
bysort year patent_id: gen byte fp = _n == 1
tab year if g == 1 & fp
di as result "ALL SMOKE TESTS PASSED"
