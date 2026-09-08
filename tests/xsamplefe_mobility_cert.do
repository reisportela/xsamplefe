noi di as text "xsamplefe mobility certification: mobility structure of the sample"

* The mobility structure (movers vs stayers, number of distinct mobility
* values per unit, transitions) drives the identification of panel and
* two-way fixed-effect models. This file certifies what every sampling design
* preserves of it:
*   - whole-unit sampling keeps every spell, so the per-unit mobility of each
*     retained unit is exactly the one in the population, and the shares of
*     the mobility classes are unbiased (within sampling error);
*   - stratifying by the number of distinct mobility values per unit,
*     by(nmob), reproduces the class shares exactly (proportional allocation);
*   - observation-level sampling and sampling of the other dimension destroy
*     the mobility structure (documented, so that the failure is visible).

capture program drop xcert_akm
program define xcert_akm
    clear
    set seed 2026
    set obs 3000
    gen long worker = _n
    gen double alpha = rnormal()
    gen int firm = ceil(runiform() * 150)
    expand 8
    bysort worker: gen int year = _n
    bysort worker (year): replace firm = cond(runiform() < .15, ceil(runiform() * 150), firm[_n - 1]) if _n > 1
end

* per-unit mobility: nmob = distinct mobility values, ntrans = transitions,
* first = first row of the unit; class shares and firm-side coverage in r()
capture program drop xcert_mob
program define xcert_mob, rclass
    syntax [if], unit(varname) mob(varname) time(varname) [prefix(name)]
    marksample touse
    tempvar f fm
    quietly {
        bysort `touse' `unit' `mob': gen byte `f' = _n == 1 & `touse'
        bysort `touse' `unit': egen int `prefix'nmob = total(`f') if `touse'
        bysort `touse' `unit' (`time'): gen byte `prefix'tr = `mob' != `mob'[_n - 1] if _n > 1 & `touse'
        bysort `touse' `unit': egen int `prefix'ntrans = total(`prefix'tr) if `touse'
        bysort `touse' `unit': gen byte `prefix'first = _n == 1 & `touse'
        count if `prefix'first
        return scalar U = r(N)
        local U = r(N)
        forvalues k = 1/3 {
            count if `prefix'first & `prefix'nmob == `k'
            return scalar n`k' = r(N)
            return scalar p`k' = r(N) / `U'
        }
        count if `prefix'first & `prefix'nmob >= 4
        return scalar n4 = r(N)
        return scalar p4 = r(N) / `U'
        count if `prefix'first & `prefix'nmob >= 2
        return scalar movers = r(N) / `U'
        summarize `prefix'ntrans if `prefix'first
        return scalar trans = r(mean)
        bysort `touse' `mob': gen byte `fm' = _n == 1 & `touse'
        count if `fm'
        return scalar F = r(N)
    }
end

* ---------------------------------------------------------------------------
* 1. Synthetic AKM panel: 3,000 workers x 8 years, 150 firms, 15 percent
*    yearly mobility (67 percent movers, 1.03 transitions per worker)
* ---------------------------------------------------------------------------
xcert_akm
xcert_mob, unit(worker) mob(firm) time(year) prefix(p_)
local U = r(U)
local F = r(F)
forvalues k = 1/4 {
    local n`k' = r(n`k')
    local p`k' = r(p`k')
}
local movers = r(movers)
local trans = r(trans)
assert `movers' > .6 & `F' == 150
tempfile pop
save `pop'

* whole-worker sample: the mobility of every retained worker is exactly the
* one in the population, every firm is still covered
set seed 1
xsamplefe 20, absorb(worker firm year) generate(g)
assert r(N_mobility_retained) == r(N_mobility) & r(N_mobility) == 150
assert r(N_movers_eligible) == round(`movers' * `U')
keep if g
xcert_mob, unit(worker) mob(firm) time(year) prefix(s_)
assert s_nmob == p_nmob & s_ntrans == p_ntrans & s_tr == p_tr
* class shares within 3 binomial standard errors of the population shares
forvalues k = 1/4 {
    assert abs(r(p`k') - `p`k'') < 3 * sqrt(`p`k'' * (1 - `p`k'') / r(U))
}
assert abs(r(movers) - `movers') < 3 * sqrt(`movers' * (1 - `movers') / r(U))
assert r(F) == 150
noi di as text "  20% of workers: per-unit mobility exact; movers " %5.3f r(movers) ///
    " (pop " %5.3f `movers' "); transitions/unit " %5.3f r(trans) " (pop " %5.3f `trans' ")"

* stratified by the number of distinct firms: exact proportional allocation
use `pop', clear
set seed 1
xsamplefe 20, absorb(worker firm year) by(p_nmob) generate(g)
assert r(N_strata) == 6
keep if g
xcert_mob, unit(worker) mob(firm) time(year) prefix(s_)
forvalues k = 1/3 {
    assert r(n`k') == int(`n`k'' * 20 / 100 + .5)
}
assert abs(r(movers) - `movers') < .002
assert abs(r(trans) - `trans') < .01
noi di as text "  20% of workers by(nmob): class counts int(n*20/100+.5); movers " %5.3f r(movers) ///
    "; transitions/unit " %5.3f r(trans)

* the mover/stayer rates change the class shares on purpose (all movers kept)
use `pop', clear
set seed 1
xsamplefe 20, absorb(worker firm year) movers(100) stayers(20) generate(g)
assert r(N_movers_sampled) == r(N_movers_eligible)
keep if g
xcert_mob, unit(worker) mob(firm) time(year) prefix(s_)
assert s_nmob == p_nmob & s_ntrans == p_ntrans
assert r(movers) > .9
assert r(n1) == int(`n1' * 20 / 100 + .5)

* connected set: the 20 percent worker sample is still one component; at 5
* percent the graph fragments and connected reports it
use `pop', clear
xsamplefe 100, absorb(worker firm year) connected generate(g)
assert r(n_components) == 1 & r(N_connected_dropped) == 0
set seed 1
xsamplefe 20, absorb(worker firm year) connected generate(g20)
assert r(n_components) == 1 & r(N_connected_dropped) == 0
set seed 1
xsamplefe 5, absorb(worker firm year) connected generate(g5)
assert r(n_components) > 1 & r(N_connected_dropped) > 0
noi di as text "  connected: 1 component at 100% and 20%; " r(n_components) " components at 5% (" ///
    r(N_connected_dropped) " rows dropped)"

* observation-level sampling of the same number of rows destroys mobility
use `pop', clear
set seed 1
sample 20
xcert_mob, unit(worker) mob(firm) time(year) prefix(s_)
assert r(movers) < `movers' / 2
assert r(trans) < `trans' / 3
noi di as text "  sample 20 (rows): movers " %5.3f r(movers) "; transitions/unit " %5.3f r(trans) " (destroyed)"

* sampling the other dimension (firms) truncates the workers' histories;
* group(worker) restores the full histories of every worker touched by a
* sampled firm, at the price of over-representing movers
use `pop', clear
set seed 1
xsamplefe 20, absorb(worker firm year) unit(firm) generate(g)
assert r(N_units_sampled) == 30
keep if g
xcert_mob, unit(worker) mob(firm) time(year) prefix(s_)
assert r(movers) < `movers' / 3
local movers_firm = r(movers)
use `pop', clear
set seed 1
xsamplefe 20, absorb(worker firm year) unit(firm) group(worker) generate(g)
assert r(N_units_sampled) == 30 & r(N_units_retained) == 150
keep if g
xcert_mob, unit(worker) mob(firm) time(year) prefix(s_)
assert s_nmob == p_nmob & s_ntrans == p_ntrans
assert r(movers) > `movers'
noi di as text "  20% of firms: movers " %5.3f `movers_firm' "; with group(worker): full histories, movers " ///
    %5.3f r(movers) " (over-represented)"

* ---------------------------------------------------------------------------
* 2. nlswork: women x industry (56 percent movers across ind_code)
* ---------------------------------------------------------------------------
webuse nlswork, clear
drop if missing(ind_code)
xcert_mob, unit(idcode) mob(ind_code) time(year) prefix(p_)
local movers = r(movers)
local trans = r(trans)
forvalues k = 1/4 {
    local n`k' = r(n`k')
    local p`k' = r(p`k')
}
tempfile nls
save `nls'
set seed 2
xsamplefe 20, absorb(idcode ind_code year) generate(g)
assert r(N_mobility_retained) == r(N_mobility)
keep if g
xcert_mob, unit(idcode) mob(ind_code) time(year) prefix(s_)
assert s_nmob == p_nmob & s_ntrans == p_ntrans
forvalues k = 1/4 {
    assert abs(r(p`k') - `p`k'') < 3 * sqrt(`p`k'' * (1 - `p`k'') / r(U))
}
assert abs(r(movers) - `movers') < 3 * sqrt(`movers' * (1 - `movers') / r(U))
noi di as text "  nlswork 20% of idcode: per-unit mobility exact; movers " %5.3f r(movers) " (pop " %5.3f `movers' ")"
use `nls', clear
set seed 2
xsamplefe 20, absorb(idcode ind_code year) by(p_nmob) generate(g)
keep if g
xcert_mob, unit(idcode) mob(ind_code) time(year) prefix(s_)
forvalues k = 1/3 {
    assert r(n`k') == int(`n`k'' * 20 / 100 + .5)
}
assert abs(r(movers) - `movers') < .002
noi di as text "  nlswork 20% by(nmob): exact class counts; movers " %5.3f r(movers) "; transitions/unit " ///
    %5.3f r(trans) " (pop " %5.3f `trans' ")"

* ---------------------------------------------------------------------------
* 3. Connectivity fidelity: diagnostics, and reconnect on a sparse graph
*    3,000 workers x 6 years, 1,500 firms, 8 percent yearly mobility: the
*    frame has one dominant component but a simple unit sample shatters it
* ---------------------------------------------------------------------------
* pure-Stata components by label propagation (min label over the bipartite
* unit x mobility graph); returns the component count and the largest one
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

clear
set seed 4242
set obs 3000
gen long worker = _n
gen int firm = ceil(runiform() * 1500)
expand 6
bysort worker: gen int year = _n
bysort worker (year): replace firm = cond(runiform() < .08, ceil(runiform() * 1500), firm[_n - 1]) if _n > 1
tempfile sparse
save `sparse'

* the frame diagnostic matches the pure-Stata components exactly
xcert_comp, unit(worker) mob(firm)
local o_ncomp = r(ncomp)
local o_share = r(lccrows) / r(rows)
xsamplefe 100, absorb(worker firm year) connectivity generate(g100)
assert r(N_components_frame) == `o_ncomp'
assert abs(r(lcc_share_frame) - `o_share') < 1e-12
assert r(N_components) == `o_ncomp' & abs(r(lcc_share) - `o_share') < 1e-12
noi di as text "  frame connectivity: " `o_ncomp' " components, largest " %5.1f 100 * `o_share' ///
    "% of the rows (verified in Stata)"

* a simple 10 percent unit sample keeps the per-unit mobility but shatters the
* graph: the largest component of the sample is a small share of its rows
use `sparse', clear
set seed 1
xsamplefe 10, absorb(worker firm year) connectivity generate(g)
local share_simple = r(lcc_share)
local ncomp_simple = r(N_components)
assert `share_simple' < .10 & `ncomp_simple' > 100
xcert_comp if g == 1, unit(worker) mob(firm)
assert r(ncomp) == `ncomp_simple'
assert abs(r(lccrows) / r(rows) - `share_simple') < 1e-12

* reconnect grows the largest component back to the frame's share
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect generate(gr)
local share_rec = r(lcc_share)
local added = r(N_units_reconnected)
local added_rows = r(N_reconnected)
assert `share_rec' >= `o_share' - .01
assert `added' > 0 & `added_rows' > 0
assert r(N_units_retained) == r(N_units_sampled) + `added'
assert r(N_frame_retained) == 1800 + `added_rows'
* whole units only, and every drawn unit is still in the sample
bysort worker: egen byte rmn = min(gr)
bysort worker: egen byte rmx = max(gr)
assert rmn == rmx
assert gr >= g
xcert_comp if gr == 1, unit(worker) mob(firm)
assert abs(r(lccrows) / r(rows) - `share_rec') < 1e-12
noi di as text "  reconnect: largest component " %5.1f 100 * `share_simple' "% -> " ///
    %5.1f 100 * `share_rec' "% of the sample rows (" `added' " units, " `added_rows' " rows added)"

* reconrule(key) takes the frontier in random-key order instead of the
* largest-gain order: it must reach the same target
use `sparse', clear
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect reconrule(key) generate(gk)
local share_key = r(lcc_share)
local added_key = r(N_units_reconnected)
assert "`r(reconrule)'" == "key"
assert `share_key' >= `o_share' - .01
assert `added_key' > 0
bysort worker: egen byte kmn = min(gk)
bysort worker: egen byte kmx = max(gk)
assert kmn == kmx
noi di as text "  reconrule(key): largest component " %5.1f 100 * `share_key' "% with " `added_key' ///
    " units added (gain: " %5.1f 100 * `share_rec' "% with " `added' ")"

* deterministic: same result with 1 and 8 threads and with shuffled rows,
* under both rules
use `sparse', clear
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect generate(r1) numthreads(1)
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect generate(r8) numthreads(8)
assert r1 == r8
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect reconrule(key) generate(k1) numthreads(1)
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect reconrule(key) generate(k8) numthreads(8)
assert k1 == k8
gen double __sh = runiform()
sort __sh
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect generate(rsh) numthreads(4)
assert r1 == rsh
set seed 1
xsamplefe 10, absorb(worker firm year) reconnect reconrule(key) generate(ksh) numthreads(4)
assert k1 == ksh
* an explicit target is honoured, and reconnect does nothing when it is met
use `sparse', clear
set seed 1
xsamplefe 10, absorb(worker firm year) generate(g0)
set seed 1
xsamplefe 10, absorb(worker firm year) recontarget(50) generate(t50)
assert r(lcc_share) >= .50 & r(lcc_share) < .60
set seed 1
xsamplefe 10, absorb(worker firm year) recontarget(1) generate(t1)
assert r(N_units_reconnected) == 0 & r(N_reconnected) == 0
assert t1 == g0
noi di as text "  reconnect: deterministic (1/8 threads, shuffled rows) and target-aware"

* ---------------------------------------------------------------------------
* 4. mobstrata: the mobility class of the unit as a native stratum
* ---------------------------------------------------------------------------
use `sparse', clear
bysort worker firm: gen byte mfirst = _n == 1 & !missing(firm)
bysort worker: egen int nmob = total(mfirst)
set seed 77
xsamplefe 20, absorb(worker firm year) by(nmob) generate(gb)
local sfinal = r(N_strata_final)
set seed 77
xsamplefe 20, absorb(worker firm year) mobstrata generate(gm)
assert r(N_strata) == 1 & r(N_strata_final) == `sfinal'
assert gm == gb
noi di as text "  mobstrata: identical to by(nmob) computed with !missing() (`sfinal' classes)"

* ---------------------------------------------------------------------------
* 5. Optional: the same diagnostics on the HDFE benchmark collection
*    (only when XSF_SERGIO_DIR points at it; skipped otherwise)
* ---------------------------------------------------------------------------
local sergio : env XSF_SERGIO_DIR
local ran 0
foreach d in patents synthetic-assortative enron {
    capture confirm file "`sergio'/`d'.dta"
    if (_rc) continue
    use "`sergio'/`d'.dta", clear
    set seed 1
    quietly xsamplefe 10, absorb(id1 id2) connectivity generate(s0)
    local fshare = r(lcc_share_frame)
    local sshare = r(lcc_share)
    set seed 1
    quietly xsamplefe 10, absorb(id1 id2) reconnect generate(s1)
    * reconnect can stop early when the frontier runs out, never go backwards
    assert r(lcc_share) >= `sshare'
    assert s1 >= s0
    local g_share = r(lcc_share)
    local g_added = r(N_units_reconnected)
    local g_rows = r(N_frame_retained)
    set seed 1
    quietly xsamplefe 10, absorb(id1 id2) reconnect reconrule(key) generate(s2)
    assert r(lcc_share) >= `sshare'
    assert s2 >= s0
    local ran 1
    noi di as text "  `d': frame largest " %5.1f 100 * `fshare' "%, sample " %5.1f 100 * `sshare' ///
        "% -> gain " %5.1f 100 * `g_share' "% (" `g_added' " units, " `g_rows' " rows), key " ///
        %5.1f 100 * r(lcc_share) "% (" r(N_units_reconnected) " units, " r(N_frame_retained) " rows)"
}
if (!`ran') noi di as text "  XSF_SERGIO_DIR datasets not found: benchmark connectivity block skipped"

noi di as text "xsamplefe mobility certification passed"
