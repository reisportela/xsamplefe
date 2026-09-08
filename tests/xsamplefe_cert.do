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
set seed 3
xsamplefe 100, unit(worker_id) absorb(work firm_id) minmobility(2) generate(b)
assert "`r(mobility)'" == "`mob_full'" & "`mob_full'" == "firm_id"
assert a == b & a == 1
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

noi di as text "xsamplefe certification passed"
