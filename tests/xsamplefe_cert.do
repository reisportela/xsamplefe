noi di as text "xsamplefe certification (panel / fixed-effect aware sampling)"

capture which xsamplefe
if (c(rc)) {
    di as error "xsamplefe not found: build the plugin and set XSAMPLEFE_ADOPATH."
    exit 601
}
which xsamplefe

* ---------------------------------------------------------------------------
* 1. Observation-level parity with sample: same drawn rows under the same seed
* ---------------------------------------------------------------------------
capture program drop xcert_ids
program define xcert_ids, rclass
    quietly levelsof __id, local(ids)
    return local ids "`ids'"
end

sysuse auto, clear
gen long __id = _n
set seed 20260908
sample 10
xcert_ids
local ref `r(ids)'
local ref_state = c(rngstate)
sysuse auto, clear
gen long __id = _n
set seed 20260908
xsamplefe 10
assert r(N) == _N
xcert_ids
assert "`ref'" == "`r(ids)'"
assert c(rngstate) == "`ref_state'"
noi di as text "  parity: xsamplefe 10 == sample 10 (rows and RNG state)"

webuse nlswork, clear
gen long __id = _n
set seed 42
sample 5 if age > 30, by(race year)
xcert_ids
local ref `r(ids)'
webuse nlswork, clear
gen long __id = _n
set seed 42
xsamplefe 5 if age > 30, by(race year)
xcert_ids
assert "`ref'" == "`r(ids)'"
assert r(N_outside) > 0
noi di as text "  parity: sample 5 if age>30, by(race year)"

webuse nlswork, clear
gen long __id = _n
set seed 7
sample 3, count by(idcode)
xcert_ids
local ref `r(ids)'
webuse nlswork, clear
gen long __id = _n
set seed 7
xsamplefe 3, count by(idcode)
xcert_ids
assert "`ref'" == "`r(ids)'"
noi di as text "  parity: sample 3, count by(idcode)"

* sample 100 / count >= _N draw nothing and leave the RNG untouched
sysuse auto, clear
set seed 5
local s0 = c(rngstate)
xsamplefe 100
assert _N == 74
assert c(rngstate) == "`s0'"
xsamplefe 100, count
assert _N == 74
assert c(rngstate) == "`s0'"

* generate()/keep(): no rows deleted, indicator equals the drawn set
sysuse auto, clear
gen long __id = _n
set seed 3
xsamplefe 25, by(foreign) generate(pick)
assert _N == 74
assert r(N) == 19
quietly count if pick == 1
assert r(N) == 19
sysuse auto, clear
set seed 3
xsamplefe 25, by(foreign) keep(pick2)
quietly count if pick2 == 1
assert r(N) == 19

* ---------------------------------------------------------------------------
* 2. Unit-level sampling: whole units, determinism, order invariance
* ---------------------------------------------------------------------------
webuse nlswork, clear
set seed 1
xsamplefe 10, absorb(idcode year) generate(s)
assert r(N_units) == 4711
assert r(N_units_sampled) == 471
bysort idcode: egen byte mn = min(s)
bysort idcode: egen byte mx = max(s)
assert mn == mx
set seed 1
xsamplefe 10, absorb(idcode year) generate(s1) numthreads(1)
assert r(threads_used) == 1
set seed 1
xsamplefe 10, absorb(idcode year) generate(s8) numthreads(8)
assert s == s1 & s == s8
gen double __shuffle = runiform()
sort __shuffle
set seed 1
xsamplefe 10, absorb(idcode year) generate(s_sh)
assert s == s_sh
noi di as text "  units: whole idcode units, thread-invariant, order-invariant"

* string identifiers are accepted (zero-padded so that the lexicographic
* rank equals the numeric rank; otherwise the units drawn legitimately differ)
webuse nlswork, clear
gen str12 sid = "w" + string(idcode, "%05.0f")
set seed 1
xsamplefe 10, unit(sid) generate(sstr)
set seed 1
xsamplefe 10, unit(idcode) generate(snum)
assert sstr == snum
noi di as text "  units: string identifier equals numeric identifier"

* ---------------------------------------------------------------------------
* 3. Panel structure: balanced, minperiods, minobs
* ---------------------------------------------------------------------------
webuse nlswork, clear
set seed 3
xsamplefe 50, absorb(idcode year) time(year) balanced generate(b)
assert r(N_units_eligible) == 86
assert r(N_units_sampled) == 43
assert r(N_periods) == 15
bysort idcode year: gen byte __first = _n == 1
bysort idcode: egen int nyears = total(__first)
assert nyears == 15 if b == 1
xtset idcode year
set seed 3
xsamplefe 50, absorb(idcode year) balanced generate(b2)
assert b == b2
set seed 4
xsamplefe 100, absorb(idcode year) minperiods(5) maxperiods(8) minobs(5) generate(p)
bysort idcode: gen long nobs = _N
assert inrange(nyears, 5, 8) & nobs >= 5 if p == 1
assert !(inrange(nyears, 5, 8) & nobs >= 5) if p == 0
noi di as text "  panel: balanced (explicit and xtset time), period and obs bounds"

* ---------------------------------------------------------------------------
* 4. Mobility structure: movers/stayers rates, bounds, connected
* ---------------------------------------------------------------------------
webuse nlswork, clear
set seed 5
xsamplefe 10, absorb(idcode ind_code year) movers(50) stayers(5) generate(m)
assert "`r(mobility)'" == "ind_code"
assert r(N_movers_sampled) == int(r(N_movers_eligible) * 50 / 100 + .5)
assert r(N_units_sampled) - r(N_movers_sampled) == ///
    int((r(N_units_eligible) - r(N_movers_eligible)) * 5 / 100 + .5)
bysort idcode ind_code: gen byte __f = _n == 1 if !missing(ind_code)
bysort idcode: egen int nind = total(__f)
gen byte mover = nind >= 2
set seed 6
xsamplefe 100, absorb(idcode ind_code year) minmobility(2) generate(mv)
assert mv == mover
set seed 6
xsamplefe 100, absorb(idcode ind_code year) maxmobility(1) generate(st)
assert st == 1 - mover
set seed 7
xsamplefe 10, absorb(idcode ind_code year) connected generate(cc)
assert r(n_components) >= 1
noi di as text "  mobility: rates, bounds and connected set"

* ---------------------------------------------------------------------------
* 5. reghdfe group()/individual() designs (synthetic patents)
* ---------------------------------------------------------------------------
clear
set seed 11
set obs 400
gen int patent = floor((_n - 1) / 4) + 1
gen int inventor = mod((_n - 1) * 7 + floor((_n - 1) / 4), 60) + 1
gen int year = mod(patent - 1, 5) + 2001
gen double x = rnormal()
bysort patent: replace x = x[1]
gen double y = x + rnormal()
bysort patent: replace y = y[1]
duplicates drop patent inventor, force
bysort patent: gen int team = _N

set seed 12
xsamplefe 30, absorb(inventor) group(patent) individual(inventor) generate(g)
assert "`r(unit)'" == "patent"
assert "`r(mobility)'" == "inventor"
bysort patent: egen byte gmn = min(g)
bysort patent: egen byte gmx = max(g)
assert gmn == gmx
set seed 12
xsamplefe 30, absorb(inventor) group(patent) i(inventor) generate(g_alias)
assert g == g_alias
reghdfe y x if g == 1, absorb(inventor) group(patent) individual(inventor)
assert e(N) > 0

set seed 13
xsamplefe 30, group(patent) individual(inventor) unit(inventor) generate(gi)
assert "`r(mobility)'" == "patent"
bysort patent: egen byte imn = min(gi)
bysort patent: egen byte imx = max(gi)
assert imn == imx
assert r(N_units_retained) >= r(N_units_sampled)
set seed 13
xsamplefe 30, group(patent) individual(inventor) unit(inventor) grouprule(all) generate(ga)
assert ga <= gi

set seed 14
xsamplefe 100, group(patent) individual(inventor) minmobility(3) maxmobility(4) generate(gt)
assert gt == inrange(team, 3, 4)

set seed 15
xsamplefe 2, count group(patent) by(year) generate(gc)
local nstrata = r(N_strata)
assert r(N_units_sampled) == 2 * `nstrata'
bysort year patent: gen byte __fp = _n == 1
quietly count if gc == 1 & __fp
assert r(N) == 2 * `nstrata'
noi di as text "  group()/individual(): closure, alias, bounds, count per stratum"

* ---------------------------------------------------------------------------
* 6. if/in frame rules and expected errors
* ---------------------------------------------------------------------------
webuse nlswork, clear
set seed 21
capture xsamplefe 10 if year >= 80, absorb(idcode year)
assert _rc == 198
set seed 21
xsamplefe 10 if year >= 80, absorb(idcode year) any generate(fa)
assert r(N_units_split) > 0
bysort idcode: egen byte famn = min(fa)
bysort idcode: egen byte famx = max(fa)
assert famn == famx
set seed 21
xsamplefe 10 if year >= 80, absorb(idcode year) all generate(fb)
assert fb == 1 if year < 80
capture xsamplefe 10, individual(idcode)
assert _rc == 198
capture xsamplefe 10, absorb(idcode year) by(age)
assert _rc == 198
capture xsamplefe 10, absorb(idcode) movers(50)
assert _rc == 198
capture xsamplefe 120
assert _rc == 198
sysuse auto, clear
capture xsamplefe 10, unit(foreign) balanced
assert _rc == 198
noi di as text "  frame rules: strict error, any, all; expected errors"

noi di as text "xsamplefe certification passed"
