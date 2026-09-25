noi di as text "xsamplefe certification (panel / fixed-effect aware sampling)"
set varabbrev off

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
* capture the results before the rclass helper overwrites r()
local n_outside = r(N_outside)
local n_frame = r(N_frame)
xcert_ids
assert "`ref'" == "`r(ids)'"
assert !missing(`n_outside') & `n_outside' > 0
assert `n_frame' + `n_outside' == 28534
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
* components: compare with a pure-Stata label propagation on the same rows
* (the previous assert r(n_components) >= 1 could not fail)
capture program drop xcert_comp
program define xcert_comp, rclass
    syntax [if], unit(varname) mob(varname)
    marksample touse
    tempvar lab lm lu f
    quietly {
        egen long `lab' = group(`unit') if `touse'
        local changed 1
        while (`changed') {
            bysort `touse' `mob': egen long `lm' = min(`lab') if `touse' & !missing(`mob')
            replace `lm' = `lab' if `touse' & missing(`lm')
            bysort `touse' `unit': egen long `lu' = min(`lm') if `touse'
            count if `touse' & `lu' != `lab'
            local changed = (r(N) > 0)
            replace `lab' = `lu' if `touse'
            drop `lm' `lu'
        }
        bysort `touse' `lab': gen byte `f' = _n == 1 & `touse'
        count if `f'
        return scalar ncomp = r(N)
        bysort `touse' `lab': gen long `lm' = _N if `touse'
        summarize `lm' if `touse', meanonly
        return scalar lccrows = r(max)
        count if `touse'
        return scalar rows = r(N)
    }
end
* the diagnostics are opt-in: without connectivity/connected/reconnect they are
* missing, and asking for them does not change the draw
set seed 7
xsamplefe 10, absorb(idcode ind_code year) generate(cc_off)
foreach s in N_components_frame lcc_share_frame N_components lcc_share ///
    lcc_units_share lcc_mobility_share N_units_lcc_kept {
    assert missing(r(`s'))
}
set seed 7
xsamplefe 10, absorb(idcode ind_code year) connectivity generate(cc0)
local nc_plain = r(N_components)
local lcc_share = r(lcc_share)
assert cc0 == cc_off
assert !missing(`nc_plain') & `nc_plain' > 1
assert inrange(r(lcc_units_share), 0, 1) & inrange(r(lcc_mobility_share), 0, 1)
assert r(N_units_lcc_kept) <= r(N_units_retained)
xcert_comp if cc0 == 1, unit(idcode) mob(ind_code)
assert r(ncomp) == `nc_plain'
assert abs(r(lccrows) / r(rows) - `lcc_share') < 1e-12
set seed 7
xsamplefe 10, absorb(idcode ind_code year) connected generate(cc)
assert r(n_components) == `nc_plain'
assert r(N_components) == 1 & r(lcc_share) == 1
assert cc <= cc0
xcert_comp if cc == 1, unit(idcode) mob(ind_code)
assert r(ncomp) == 1
noi di as text "  mobility: rates, bounds and connected set (`nc_plain' components verified in Stata)"

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
local u_ret = r(N_units_retained)
local u_samp = r(N_units_sampled)
local u_inelig_ret = r(N_units_ineligible_retained)
bysort patent: egen byte imn = min(gi)
bysort patent: egen byte imx = max(gi)
assert imn == imx
assert !missing(`u_ret') & `u_ret' >= `u_samp'
assert `u_inelig_ret' == 0
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

* ---------------------------------------------------------------------------
* 7. generate()/keep(): reserved names, exact matching, nothing is ever lost
* ---------------------------------------------------------------------------
clear
set obs 10
gen long original = _n
gen long selection_original = 12345
gen str5 s5 = "abc"
foreach bad in _all _n _N _pi _rc _b _se _cons _coef _skip {
    capture xsamplefe 20, generate(`bad')
    assert _rc == 198
    capture xsamplefe 20, keep(`bad')
    assert _rc == 198
    assert _N == 10 & c(k) == 3
}
* a new name that abbreviates an existing variable does not touch it
set seed 1
xsamplefe 20, generate(selection)
assert c(k) == 4
confirm variable selection_original, exact
assert selection_original == 12345
xsamplefe 20, generate(selection) replace
confirm variable selection_original, exact
assert selection_original == 12345
capture xsamplefe 20, generate(selection_original)
assert _rc == 110
assert selection_original == 12345
* replace over a string variable produces the byte indicator
set seed 1
xsamplefe 20, generate(s5) replace
quietly count if s5 == 1
assert r(N) == 2
capture confirm string variable s5
assert _rc != 0
noi di as text "  generate(): reserved names refused, exact matching, no data loss"

* ---------------------------------------------------------------------------
* 8. Empty frame: the indicator and the stored results are still produced
* ---------------------------------------------------------------------------
clear
set obs 4
gen byte id = _n
local s0 = c(rngstate)
xsamplefe 50 if 0, unit(id) generate(flag)
assert r(N) == 4 & r(N_frame) == 0 & r(N_outside) == 4 & r(N_units) == 0
assert "`r(cmd)'" == "xsamplefe"
assert c(rngstate) == "`s0'"
assert flag == 1
* all ids missing, with an existing (stale) indicator
replace id = .
gen byte stale = 9
xsamplefe 50, unit(id) generate(stale) replace
assert stale == 1 & r(N_frame) == 0
* zero observations
clear
set obs 0
gen byte id = .
xsamplefe 50, unit(id) generate(f2)
assert r(N) == 0 & r(N_total) == 0
noi di as text "  empty frame: indicator, r() and untouched RNG"

* ---------------------------------------------------------------------------
* 9. group closure and connected respect the indivisible blocks
* ---------------------------------------------------------------------------
* documented consequence of the closure: ineligible units come back whole
clear
input byte(g u)
1 1
1 2
2 2
2 3
end
xsamplefe 100, unit(u) group(g) minobs(2) generate(s)
assert r(N_units_eligible) == 1 & r(N_units_ineligible) == 2
assert r(N_units_sampled) == 1 & r(N_units_retained) == 3
assert r(N_units_ineligible_retained) == 2 & r(N_units_partial) == 0
assert s == 1
* the closure can also keep only part of a drawn unit: that is reported
clear
input byte(g u)
1 1
1 2
2 2
2 3
3 2
end
xsamplefe 100, unit(u) group(g) minobs(2) grouprule(all) generate(s)
assert r(N_units_sampled) == 1 & r(N_units_partial) == 1
quietly count if s
assert r(N) == 1
* connected must not split a group: unions run over groups as well
clear
input byte(g u m)
1 1 10
1 2 20
2 2 20
2 3 30
end
xsamplefe 100, unit(u) group(g) mobility(m) connected generate(s)
assert r(n_components) == 1 & r(N_connected_dropped) == 0 & s == 1
* two blocks joined only by a group stay together
clear
input byte(g u m)
1 1 10
1 2 20
2 3 30
2 4 40
3 2 20
3 3 30
end
xsamplefe 100, unit(u) group(g) mobility(m) connected generate(s2)
assert r(n_components) == 1 & r(N_connected_dropped) == 0 & s2 == 1
noi di as text "  group closure: partial/ineligible units reported; connected keeps groups whole"

* ---------------------------------------------------------------------------
* 10. absorb() parsing, abbreviations, option domains and stray scalars
* ---------------------------------------------------------------------------
clear
set obs 20
gen long worker_id = ceil(_n / 2)
gen byte firm_id = mod(_n, 2)
gen double x = _n
gen double z = -_n
set seed 3
xsamplefe 100, unit(worker_id) absorb(worker_id firm_id) minmobility(2) generate(a)
local mob_full "`r(mobility)'"
* Explicit abbreviations obey Stata's varabbrev setting.
capture xsamplefe 100, unit(worker_id) absorb(work firm_id) minmobility(2) generate(b)
assert _rc == 111
set varabbrev on
set seed 3
xsamplefe 100, unit(worker_id) absorb(work firm_id) minmobility(2) generate(b)
assert "`r(mobility)'" == "`mob_full'" & "`mob_full'" == "firm_id"
assert a == b & a == 1
set varabbrev off
* reghdfe slope syntax with a parenthesised continuous list
set seed 4
xsamplefe 50, absorb(worker_id##c.(x z) firm_id) generate(c1)
assert "`r(unit)'" == "worker_id" & "`r(mobility)'" == "firm_id"
set seed 4
xsamplefe 50, absorb(worker_id##(c.x c.z) firm_id) generate(c2)
assert c1 == c2
set seed 4
xsamplefe 50, absorb(worker_id firm_id) generate(c3)
assert c1 == c3
* movers()/stayers() counts must be representable
capture xsamplefe 1, count unit(worker_id) mobility(firm_id) stayers(1e30)
assert _rc == 198
capture xsamplefe 1, count unit(worker_id) mobility(firm_id) movers(1e30)
assert _rc == 198
* a count larger than the stratum keeps the stratum whole
preserve
clear
set obs 40
gen long w = ceil(_n / 4)
gen byte f = 1
xsamplefe 1, count unit(w) mobility(f) stayers(99) generate(big)
assert r(N_units_eligible) == 10 & r(N_units_sampled) == 10 & r(N_target) == 10
assert big == 1
restore
* option domains: negative bounds are refused, min()/max() are not abbreviations
capture xsamplefe 10, unit(worker_id) minobs(-2)
assert _rc == 125
capture xsamplefe 10, unit(worker_id) maxperiods(-9)
assert _rc == 125
capture xsamplefe 10, unit(worker_id) min(2)
assert _rc == 198
capture xsamplefe 10, unit(worker_id) max(2)
assert _rc == 198
* group() equal to the unit still reports the group counts
xsamplefe 100, group(worker_id) generate(gg)
assert r(N_groups) == r(N_units) & r(N_groups_kept) == r(N_units_sampled)
assert r(N_groups_retained) == r(N_units_retained) & r(N_groups) == 10
* user scalars named like the plugin transport survive
scalar __xsf_N_total = 12345
set seed 1
xsamplefe 20, generate(safe)
confirm scalar __xsf_N_total
assert __xsf_N_total == 12345
scalar drop __xsf_N_total
noi di as text "  parsing: abbreviations, c.(x z) slopes, option domains, group counts, scalar safety"

* ---------------------------------------------------------------------------
* 11. time() is resolved before the default mobility dimension
* ---------------------------------------------------------------------------
clear
set obs 10
gen long worker = _n
gen int firm = mod(_n, 3)
expand 2
bysort worker: gen int year = _n
xtset worker year
xsamplefe 100, absorb(worker year firm) balanced minmobility(2) generate(mi)
local mob_xtset "`r(mobility)'"
xsamplefe 100, absorb(worker year firm) time(year) balanced minmobility(2) generate(me)
assert "`r(mobility)'" == "`mob_xtset'" & "`mob_xtset'" == "firm"
assert mi == me
* balanced with no non-missing period leaves no unit eligible
clear
input byte(u t)
1 .
1 .
2 .
2 .
end
xsamplefe 100, unit(u) time(t) balanced generate(s)
assert r(N_periods) == 0 & r(N_units_eligible) == 0 & s == 0
noi di as text "  time(): xtset and explicit agree; balanced with no period keeps nobody"

* ---------------------------------------------------------------------------
* 12. int(n*#/100+.5) is rounded as Stata evaluates it, n*(#/100)
* ---------------------------------------------------------------------------
* In these pairs (n*#)/100 lands on a half and n*(#/100) just below it, so
* sample draws one fewer than a left-to-right product would (1.3.0 did).
local edges 25 58 45 70 50 29 50 57 75 82 85 70 90 35 100 14.5 100 28.5 100 56.5 100 57.5 500 0.7
while ("`edges'" != "") {
    gettoken n edges : edges
    gettoken p edges : edges
    assert int(`n'*`p'/100+.5) == floor((`n'*`p')/100+.5) - 1
    clear
    quietly set obs `n'
    gen long __id = _n
    set seed 11
    quietly sample `p'
    assert _N == int(`n'*`p'/100+.5)
    xcert_ids
    local ref `r(ids)'
    local ref_state = c(rngstate)
    clear
    quietly set obs `n'
    gen long __id = _n
    set seed 11
    quietly xsamplefe `p'
    xcert_ids
    assert "`ref'" == "`r(ids)'"
    assert c(rngstate) == "`ref_state'"
}

* by(): each stratum rounds on its own (45, 85 and 165 are edges at 70 percent)
clear
quietly set obs 305
gen long __id = _n
gen byte g = 1 + (_n > 45) + (_n > 130) + (_n > 295)
preserve
set seed 12
quietly sample 70, by(g)
assert _N == 31 + 59 + 115 + 7
xcert_ids
local ref `r(ids)'
local ref_state = c(rngstate)
restore
set seed 12
quietly xsamplefe 70, by(g)
assert r(N_target) == 31 + 59 + 115 + 7
xcert_ids
assert "`ref'" == "`r(ids)'"
assert c(rngstate) == "`ref_state'"

* units, and movers()/stayers() rates, use the same rounding
clear
quietly set obs 50
gen long id = _n
expand 3
quietly xsamplefe 29, unit(id) seed(13) generate(s)
assert r(N_units_sampled) == int(50*29/100+.5) & r(N_units_sampled) == 14
clear
quietly set obs 135
gen long u = _n
expand 2
bysort u: gen int m = cond(u <= 45, 10*u + _n, 10*u)
quietly xsamplefe 10, unit(u) mobility(m) movers(70) stayers(35) seed(14) generate(s)
assert r(N_movers_eligible) == 45 & r(N_units_eligible) == 135
assert r(N_movers_sampled) == int(45*70/100+.5)
assert r(N_units_sampled) == int(45*70/100+.5) + int(90*35/100+.5)
* # and the rates reach the plugin as typed: a numlist would round
* 12.49999999999999 to 12.5, and 4 units at 12.5 percent round to 1, not 0
clear
quietly set obs 4
gen long __id = _n
quietly sample 12.49999999999999
assert _N == 0
clear
quietly set obs 4
gen long __id = _n
quietly xsamplefe 12.49999999999999
assert _N == 0
clear
quietly set obs 24
gen long u = _n
expand 2
bysort u: gen int m = cond(u <= 4, 10*u + _n, 10*u)
quietly xsamplefe 10, unit(u) mobility(m) movers(12.49999999999999) stayers(0) seed(15) generate(s)
assert r(N_movers_eligible) == 4 & r(N_movers_sampled) == 0
noi di as text "  rounding: int(n*#/100+.5) as Stata evaluates it (rows, by(), units, movers/stayers)"

* ---------------------------------------------------------------------------
* 13. Frequency weights: a table of distinct rows with their counts draws
*     exactly what the rows draw
* ---------------------------------------------------------------------------
* The rows and contract's table must agree in every retained row and in every
* stored result, except the number of uniform columns, which follows the rows
* in memory (so does the random-number state after the call).
capture program drop xcert_fw
program define xcert_fw
    syntax, rows(string) tuples(string) keys(string) num(string) [qual(string) opts(string)]
    use `"`rows'"', clear
    quietly xsamplefe `num' `qual', `opts' generate(k)
    local rsc : r(scalars)
    foreach s of local rsc {
        local E_`s' : display %21x r(`s')
    }
    collapse (min) kmin = k (max) kmax = k, by(`keys')
    assert kmin == kmax
    tempfile ek
    quietly save `ek'
    use `"`tuples'"', clear
    quietly xsamplefe `num' `qual' [fw=w], `opts' generate(k)
    assert "`r(wtype)'" == "fweight"
    foreach s of local rsc {
        if ("`s'" == "n_uniforms") continue
        local b : display %21x r(`s')
        if ("`b'" != "`E_`s''") {
            di as error "`num' `qual', `opts': r(`s') is `E_`s'' on the rows, `b' with weights"
            exit 9
        }
    }
    merge 1:1 `keys' using `ek', assert(match) nogenerate
    assert k == kmin
end

* worker-firm-year cells repeated over months; some firms missing
clear
set seed 20260925
quietly set obs 1500
gen long worker = 3*_n + 1
gen byte region = 1 + floor(4*runiform())
gen int entry = 2000 + floor(5*runiform())
gen byte len = 1 + floor(6*runiform())
expand len
bysort worker: gen int year = entry + _n - 1
gen int firm = 1 + floor(150*runiform())
bysort worker (year): replace firm = cond(runiform() < 0.2, 1 + floor(150*runiform()), firm[_n-1]) if _n > 1
expand 1 + floor(12*runiform())
replace firm = . if runiform() < 0.01
drop entry len
tempfile rows tuples
quietly save `rows'
contract worker firm year region, freq(w)
quietly save `tuples'
local fw rows(`rows') tuples(`tuples') keys(worker firm year region)

xcert_fw, `fw' num(20) opts(unit(worker) mobility(firm) minobs(24) seed(1))
xcert_fw, `fw' num(20) opts(unit(worker) mobility(firm) time(year) maxobs(30) minperiods(2) by(region) seed(2))
xcert_fw, `fw' num(10) opts(unit(worker) mobility(firm) connected seed(3))
xcert_fw, `fw' num(20) opts(unit(worker) mobility(firm) reconnect seed(4))
xcert_fw, `fw' num(25) opts(unit(worker) mobility(firm) reconnect reconrule(key) recontarget(90) seed(5))
xcert_fw, `fw' num(30) opts(unit(worker) mobility(firm) minmovers(2) seed(6))
xcert_fw, `fw' num(15) opts(unit(worker) mobility(firm) time(year) movers(50) stayers(10) mobstrata connectivity seed(7))
xcert_fw, `fw' num(15) opts(unit(worker) time(year) balanced seed(8))
xcert_fw, `fw' num(40) opts(count unit(worker) by(region) seed(9))
xcert_fw, `fw' num(20) qual(if year >= 2004) opts(unit(worker) all seed(10))
xcert_fw, `fw' num(20) qual(if year >= 2004) opts(unit(worker) mobility(firm) any connectivity seed(11))

* group closure: patents and inventors, each pair repeated
clear
quietly set obs 800
gen long patent = 5*_n
gen byte nteam = 1 + floor(4*runiform())
expand nteam
gen long inventor = 1 + floor(600*runiform())
expand 1 + floor(5*runiform())
drop nteam
tempfile prow ptup
quietly save `prow'
contract patent inventor, freq(w)
quietly save `ptup'
local fw rows(`prow') tuples(`ptup') keys(patent inventor)
xcert_fw, `fw' num(30) opts(group(patent) individual(inventor) unit(inventor) seed(12))
xcert_fw, `fw' num(30) opts(group(patent) individual(inventor) unit(inventor) grouprule(all) seed(13))
xcert_fw, `fw' num(20) opts(group(patent) individual(inventor) unit(inventor) connected seed(14))

* rows without a unit (outside the frame, kept), a string unit, absorb()
clear
quietly set obs 1200
gen long worker = 3*_n + 1
gen byte region = 1 + floor(4*runiform())
gen int entry = 2000 + floor(5*runiform())
gen byte len = 1 + floor(6*runiform())
expand len
bysort worker: gen int year = entry + _n - 1
gen int firm = 1 + floor(120*runiform())
bysort worker (year): replace firm = cond(runiform() < 0.2, 1 + floor(120*runiform()), firm[_n-1]) if _n > 1
expand 1 + floor(12*runiform())
replace worker = . if runiform() < 0.02
gen str8 sid = cond(missing(worker), "", "w" + string(worker, "%06.0f"))
drop entry len
tempfile mrow mtup
quietly save `mrow'
contract worker sid firm year region, freq(w)
quietly save `mtup'
local fw rows(`mrow') tuples(`mtup') keys(worker sid firm year region)
xcert_fw, `fw' num(20) opts(absorb(worker firm year) minobs(20) connected seed(15))
xcert_fw, `fw' num(25) opts(unit(sid) mobility(firm) reconnect seed(16))
xcert_fw, `fw' num(30) opts(unit(worker) mobility(firm) time(year) minperiods(2) connectivity seed(17))
* the by prefix equals by(), weighted or on the rows
use `mtup', clear
sort region
set seed 18
by region: xsamplefe 20 [fw=w], unit(worker) minobs(10) generate(kp)
local np = r(N)
set seed 18
xsamplefe 20 [fw=w], unit(worker) minobs(10) by(region) generate(kb)
assert kp == kb & r(N) == `np'
use `mrow', clear
sort region
set seed 18
by region: xsamplefe 20, unit(worker) minobs(10) generate(kr)
assert r(N) == `np'

* the weighted draw is invariant to threads and row order; r(N) sums weights
use `tuples', clear
foreach threads in 1 8 48 {
    set seed 1
    xsamplefe 20 [fw=w], unit(worker) mobility(firm) minobs(24) generate(t`threads') numthreads(`threads')
    assert r(threads_used) == min(`threads', r(thread_capacity))
}
assert t1 == t8 & t1 == t48
foreach d in connected reconnect {
    foreach threads in 1 48 {
        quietly xsamplefe 20 [fw=w], unit(worker) mobility(firm) `d' seed(2) generate(`d'`threads') numthreads(`threads')
    }
    assert `d'1 == `d'48
}
gen double __shuffle = runiform()
sort __shuffle
set seed 1
xsamplefe 20 [fw=w], unit(worker) mobility(firm) minobs(24) generate(tsh)
assert t1 == tsh
quietly summarize w if t1, meanonly
local wsum = r(sum)
set seed 1
xsamplefe 20 [fw=w], unit(worker) mobility(firm) minobs(24)
assert r(N) == `wsum'
quietly summarize w, meanonly
assert r(sum) == `wsum'

* weights beyond 2^31: multiplying them all by 10^9 changes no decision and
* multiplies every count of observations exactly
use `tuples', clear
gen double wbig = 1e9 * w
foreach d in connected reconnect {
    quietly xsamplefe 20 [fw=w], unit(worker) mobility(firm) `d' seed(31) generate(small)
    local n = r(N)
    local total = r(N_total)
    quietly xsamplefe 20 [fw=wbig], unit(worker) mobility(firm) `d' seed(31) generate(big)
    assert small == big & r(N) == 1e9 * `n' & r(N_total) == 1e9 * `total'
    drop small big
}
* the sum of the weights must stay below 2^53, where every count is exact
clear
quietly set obs 2
gen long u = _n
gen double w = cond(_n == 1, 2^52, 2^52 - 1)
xsamplefe 100 [fw=w], unit(u)
assert r(N_total) == 2^53 - 1
replace w = 2^52 in 2
capture xsamplefe 100 [fw=w], unit(u)
assert _rc == 402

* weights need a unit, and must be positive integers
use `tuples', clear
capture xsamplefe 20 [fw=w]
assert _rc == 101
capture xsamplefe 20 [aw=w], unit(worker)
assert _rc == 101
replace w = 1.5 in 1
capture xsamplefe 20 [fw=w], unit(worker)
assert _rc == 401
replace w = 0 in 1
capture xsamplefe 20 [fw=w], unit(worker)
assert _rc == 402
replace w = . in 1
capture xsamplefe 20 [fw=w], unit(worker)
assert _rc == 402
noi di as text "  fweights: contract's table with [fw=] equals the rows (17 designs, by prefix), threads, order, 2^31 and 2^53, errors"

noi di as text "xsamplefe certification passed"
