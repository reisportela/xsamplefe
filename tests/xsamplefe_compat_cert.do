noi di as text "xsamplefe compatibility certification: sample2, sample, bsample, splitsample"

* sample2 (Weesie, STB-37 dm46) runs under -version 5.0- but Stata picks the
* generator from c(userversion), so its uniform() draws the same mt64 stream as
* runiform(). At the observation level sample2 keys rows with one float
* uniform, sample/xsamplefe with two doubles: the drawn rows coincide unless
* two float keys tie at the cutoff, which never happens in the fixed seeds
* below. With cluster() the assignment of uniforms differs by design (sample2
* keys the first row of every cluster in cluster order, xsamplefe gives the
* r-th draw to the r-th smallest unit value), so cluster tests compare
* semantics: frame, counts per stratum, whole-cluster integrity and errors.

capture which sample2
if (c(rc)) {
    di as error "sample2 not found: net install dm46, from(http://www.stata.com/stb/stb37)"
    exit 601
}

capture program drop xcert_ids
program define xcert_ids, rclass
    quietly levelsof __id, local(ids)
    return local ids "`ids'"
end

* sample2-style reference implementation of the xsamplefe unit draw in pure
* Stata: u1,u2 = runiform() in physical order, the r-th smallest unit value
* takes (u1[r], u2[r]), the K smallest keys per stratum are drawn, whole units
* are propagated
capture program drop xcert_refunit
program define xcert_refunit
    syntax anything(name=num), unit(varname) gen(name) seed(integer) [by(varname) count]
    tempvar u1 u2 rank k1 k2 first n K sel
    set seed `seed'
    quietly {
        gen double `u1' = runiform()
        gen double `u2' = runiform()
        egen long `rank' = group(`unit')
        gen double `k1' = `u1'[`rank']
        gen double `k2' = `u2'[`rank']
        bysort `unit': gen byte `first' = _n == 1
        replace `k1' = . if !`first'
        replace `k2' = . if !`first'
        if ("`by'" == "") {
            tempvar by
            gen byte `by' = 1
        }
        bysort `by': egen long `n' = total(`first')
        if ("`count'" == "") gen long `K' = int(`n' * `num' / 100 + .5)
        else gen long `K' = min(`num', `n')
        bysort `by' (`k1' `k2'): gen byte `sel' = _n <= `K' if `first'
        bysort `unit' (`first'): replace `sel' = `sel'[_N]
        gen byte `gen' = `sel'
    }
end

* ---------------------------------------------------------------------------
* 1. sample2 at the observation level: same rows as sample and xsamplefe
* ---------------------------------------------------------------------------
sysuse auto, clear
gen long __id = _n
set seed 20260908
sample2 10
xcert_ids
local ref `r(ids)'
sysuse auto, clear
gen long __id = _n
set seed 20260908
xsamplefe 10
xcert_ids
assert "`ref'" == "`r(ids)'"
noi di as text "  sample2: xsamplefe 10 == sample2 10"

* if: rows outside the condition are kept; keep() == generate()
webuse nlswork, clear
set seed 2
xsamplefe 5 if age > 30, generate(g)
assert _N == 28534
set seed 2
sample2 5 if age > 30, keep(k)
assert _N == 28534
assert k == g
assert k == 1 if !(age > 30)
quietly count if age > 30
local n_in = r(N)
quietly count if k
assert r(N) == _N - `n_in' + int(`n_in' * 5 / 100 + .5)
noi di as text "  sample2: 5 if age>30 with keep() == generate()"

* by(): sample2 sorts by the strata before drawing, so with the data already in
* that order sample2, sample and xsamplefe draw the same rows
webuse nlswork, clear
gen long __id = _n
sort race, stable
set seed 3
sample2 10, by(race) keep(k)
xcert_ids
local n_all = _N
quietly keep if k
xcert_ids
local ref `r(ids)'
webuse nlswork, clear
gen long __id = _n
sort race, stable
set seed 3
xsamplefe 10, by(race)
xcert_ids
assert "`ref'" == "`r(ids)'"
webuse nlswork, clear
gen long __id = _n
sort race, stable
set seed 3
sample 10, by(race)
xcert_ids
assert "`ref'" == "`r(ids)'"
noi di as text "  sample2: 10, by(race) == sample == xsamplefe on data sorted by race"

* 0 percent: nothing drawn, only rows outside if survive
webuse nlswork, clear
gen long __id = _n
set seed 4
sample2 0 if age > 30
xcert_ids
local ref `r(ids)'
webuse nlswork, clear
gen long __id = _n
set seed 4
xsamplefe 0 if age > 30
assert r(N) == 16779 & r(N_frame_retained) == 0
xcert_ids
assert "`ref'" == "`r(ids)'"

* ---------------------------------------------------------------------------
* 2. sample2 cluster() versus xsamplefe unit(): frame, counts, integrity
* ---------------------------------------------------------------------------
webuse nlswork, clear
set seed 5
sample2 20, cluster(idcode) keep(k)
assert _N == 28534
bysort idcode: gen byte __f = _n == 1
bysort idcode: egen byte kmn = min(k)
bysort idcode: egen byte kmx = max(k)
assert kmn == kmx
quietly count if __f & k
local k_sample2 = r(N)
assert `k_sample2' == int(4711 * 20 / 100 + .5)
set seed 5
xsamplefe 20, unit(idcode) generate(g)
assert r(N_units) == 4711
assert r(N_units_sampled) == `k_sample2'
quietly count if __f & g
assert r(N) == `k_sample2'
noi di as text "  sample2 cluster(): whole clusters, same number of clusters drawn"

* the sampling frame under any / all / strict is the same set of rows:
* at 0 percent keep()/generate() flag exactly the rows outside the frame
webuse nlswork, clear
foreach rule in any all {
    sample2 0 if age > 30, cluster(idcode) `rule' keep(k_`rule')
    xsamplefe 0 if age > 30, unit(idcode) `rule' generate(g_`rule')
    assert k_`rule' == g_`rule'
    assert r(N_units_split) == 2666
}
assert g_any <= g_all
assert "`r(frame_rule)'" == "all"
sample2 0 if race == 1, cluster(idcode) keep(k_strict)
xsamplefe 0 if race == 1, unit(idcode) generate(g_strict)
assert k_strict == g_strict
assert r(N_units_split) == 0 & "`r(frame_rule)'" == "strict"
noi di as text "  sample2 cluster(): identical frames under any, all and strict"

* by() with cluster(): same number of clusters drawn in every stratum
webuse nlswork, clear
bysort idcode: gen byte __f = _n == 1
foreach rule in any all {
    set seed 6
    sample2 20 if age > 30, cluster(idcode) `rule' by(race) keep(k_`rule')
    set seed 6
    xsamplefe 20 if age > 30, unit(idcode) `rule' by(race) generate(g_`rule')
    assert r(N_strata) == 3
    bysort race: egen long nk_`rule' = total(__f & k_`rule')
    bysort race: egen long ng_`rule' = total(__f & g_`rule')
    assert nk_`rule' == ng_`rule'
    bysort idcode: egen byte kmn_`rule' = min(k_`rule')
    bysort idcode: egen byte kmx_`rule' = max(k_`rule')
    assert kmn_`rule' == kmx_`rule'
}
noi di as text "  sample2 cluster() by(): same clusters per stratum under any and all"

* ---------------------------------------------------------------------------
* 3. sample2 / sample / xsamplefe: same errors, documented differences
* ---------------------------------------------------------------------------
webuse nlswork, clear
capture sample2 10 if year >= 80, cluster(idcode)
assert _rc == 198
capture xsamplefe 10 if year >= 80, unit(idcode)
assert _rc == 198
capture sample2 10, cluster(idcode) by(age)
assert _rc == 198
capture xsamplefe 10, unit(idcode) by(age)
assert _rc == 198
capture sample2 10, cluster(idcode) any all
assert _rc == 198
capture xsamplefe 10, unit(idcode) any all
assert _rc == 198
gen byte k = 1
capture sample2 10, keep(k)
assert _rc == 110
capture xsamplefe 10, keep(k)
assert _rc == 110
capture xsamplefe 10, keep(k2) generate(g2)
assert _rc == 198
noi di as text "  errors: split clusters, by() not constant, any+all, keep() exists"

* any/all without a cluster are ignored by both commands (rows as sample)
sysuse auto, clear
gen long __id = _n
set seed 7
sample 10
xcert_ids
local ref `r(ids)'
sysuse auto, clear
gen long __id = _n
set seed 7
sample2 10, any
xcert_ids
assert "`ref'" == "`r(ids)'"
sysuse auto, clear
gen long __id = _n
set seed 7
xsamplefe 10, any
assert "`r(frame_rule)'" == "strict"
xcert_ids
assert "`ref'" == "`r(ids)'"

* in with by(): sample and sample2 refuse it because they sort by the strata;
* xsamplefe never sorts, so the range is well defined and rows outside it are kept
sysuse auto, clear
capture sample 10 in 1/50, by(foreign)
assert _rc == 190
capture sample2 10 in 1/50, by(foreign)
assert _rc == 190
set seed 8
xsamplefe 10 in 1/50, by(foreign) generate(g)
assert _rc == 0
assert g == 1 if _n > 50
quietly count if foreign == 0 & _n <= 50
local n0 = r(N)
quietly count if foreign == 0 & _n <= 50 & g
assert r(N) == int(`n0' * 10 / 100 + .5)

* missing values in the cluster variable: sample2 requires a non-missing
* cluster variable and otherwise treats missing as one more cluster inside the
* frame; xsamplefe leaves those rows outside the frame (kept, unsampled)
sysuse auto, clear
set seed 9
sample2 50, cluster(rep78) keep(k)
bysort rep78: egen byte kmn = min(k)
bysort rep78: egen byte kmx = max(k)
assert kmn == kmx
bysort rep78: gen byte __f = _n == 1
quietly count if __f & k
assert r(N) == int(6 * 50 / 100 + .5)
set seed 9
xsamplefe 50, unit(rep78) generate(g)
assert r(N_units) == 5 & r(N_units_sampled) == 3 & r(N_outside) == 5
assert g == 1 if missing(rep78)
noi di as text "  documented differences: in with by(), missing cluster values"

* ---------------------------------------------------------------------------
* 4. pure-Stata reference of the unit draw reproduces xsamplefe bit for bit
* ---------------------------------------------------------------------------
webuse nlswork, clear
set seed 10
xsamplefe 10, unit(idcode) generate(g)
assert r(n_uniforms) == 2
xcert_refunit 10, unit(idcode) gen(ref) seed(10)
assert g == ref
set seed 11
xsamplefe 15, unit(idcode) by(race) generate(gb)
xcert_refunit 15, unit(idcode) by(race) gen(refb) seed(11)
assert gb == refb
set seed 12
xsamplefe 25, count unit(idcode) by(race) generate(gc)
xcert_refunit 25, count unit(idcode) by(race) gen(refc) seed(12)
assert gc == refc
gen double __shuffle = runiform()
sort __shuffle
set seed 11
xsamplefe 15, unit(idcode) by(race) generate(gb_sh)
assert gb_sh == refb
noi di as text "  reference: r-th smallest unit takes the r-th draw (pct, by, count, shuffled)"

* ---------------------------------------------------------------------------
* 5. sample: further parity cases (in, missing strata, string strata,
*    by prefix, pduplicates)
* ---------------------------------------------------------------------------
sysuse auto, clear
gen long __id = _n
set seed 13
sample 10 in 20/60
xcert_ids
local ref `r(ids)'
sysuse auto, clear
gen long __id = _n
set seed 13
xsamplefe 10 in 20/60
assert r(N_frame) == 41 & r(N_outside) == 33
xcert_ids
assert "`ref'" == "`r(ids)'"

webuse nlswork, clear
gen long __id = _n
gen str3 srace = string(race) + "x"
set seed 14
sample 10, by(union)
xcert_ids
local ref `r(ids)'
local ref_state = c(rngstate)
webuse nlswork, clear
gen long __id = _n
gen str3 srace = string(race) + "x"
set seed 14
xsamplefe 10, by(union)
assert r(N_strata) == 3
xcert_ids
assert "`ref'" == "`r(ids)'"
assert c(rngstate) == "`ref_state'"
webuse nlswork, clear
gen long __id = _n
gen str3 srace = string(race) + "x"
set seed 15
sample 10, by(srace year)
xcert_ids
local ref `r(ids)'
webuse nlswork, clear
gen long __id = _n
gen str3 srace = string(race) + "x"
set seed 15
xsamplefe 10, by(srace year)
xcert_ids
assert "`ref'" == "`r(ids)'"

webuse nlswork, clear
gen long __id = _n
sort race, stable
set seed 16
by race: sample 10
xcert_ids
local ref `r(ids)'
webuse nlswork, clear
gen long __id = _n
sort race, stable
set seed 16
by race: xsamplefe 10
xcert_ids
assert "`ref'" == "`r(ids)'"

sysuse auto, clear
gen long __id = _n
set seed 17
sample 10, pduplicates(1e-100)
xcert_ids
local ref `r(ids)'
local ref_state = c(rngstate)
sysuse auto, clear
gen long __id = _n
set seed 17
xsamplefe 10, pduplicates(1e-100)
assert r(n_uniforms) == 7
xcert_ids
assert "`ref'" == "`r(ids)'"
assert c(rngstate) == "`ref_state'"
noi di as text "  sample: in, missing and string strata, by prefix, pduplicates() parity"

* ---------------------------------------------------------------------------
* 6. bsample and splitsample: base-Stata cluster sampling on a 100-cluster panel
* ---------------------------------------------------------------------------
clear
set obs 1000
gen int cl = ceil(_n / 10)
gen byte stratum = mod(cl, 2)
gen double x = rnormal(cl, 1)
bysort cl: gen byte __f = _n == 1

* splitsample, cluster(): 10 percent of the clusters in split 1, whole clusters
splitsample, cluster(cl) split(.1 .9) generate(sp) rseed(18)
assert r(N_clust) == 100
bysort cl: egen byte spmn = min(sp)
bysort cl: egen byte spmx = max(sp)
assert spmn == spmx
quietly count if __f & sp == 1
assert r(N) == 10
set seed 18
xsamplefe 10, unit(cl) generate(g)
assert r(N_units) == 100 & r(N_units_sampled) == 10 & r(N) == 100
splitsample, cluster(cl) balance(stratum) split(.1 .9) generate(spb) rseed(19)
set seed 19
xsamplefe 10, unit(cl) by(stratum) generate(gb)
forvalues s = 0/1 {
    quietly count if __f & spb == 1 & stratum == `s'
    assert r(N) == 5
    quietly count if __f & gb & stratum == `s'
    assert r(N) == 5
}
capture splitsample, cluster(cl) balance(x) split(.1 .9) generate(spx) rseed(19)
assert _rc == 459
capture xsamplefe 10, unit(cl) by(x)
assert _rc == 198
noi di as text "  splitsample: cluster counts, balance() strata and nesting error"

* bsample, cluster(): # clusters with replacement (weights sum to #),
* xsamplefe # , count: # distinct clusters without replacement
gen long w = 1
set seed 20
bsample 10, cluster(cl) weight(w)
assert _N == 1000
bysort cl: egen long wmn = min(w)
bysort cl: egen long wmx = max(w)
assert wmn == wmx
quietly summarize w if __f
assert r(sum) == 10
set seed 20
xsamplefe 10, count unit(cl) generate(gcount)
assert r(N_units_sampled) == 10 & r(N) == 100
quietly count if __f & gcount
assert r(N) == 10
gen long ws = 1
set seed 21
bsample 5, cluster(cl) strata(stratum) weight(ws)
forvalues s = 0/1 {
    quietly summarize ws if __f & stratum == `s'
    assert r(sum) == 5
}
set seed 21
xsamplefe 5, count unit(cl) by(stratum) generate(gs)
forvalues s = 0/1 {
    quietly count if __f & gs & stratum == `s'
    assert r(N) == 5
}
gen long wx = 1
capture bsample 10, cluster(cl) strata(x) weight(wx)
assert _rc == 460
noi di as text "  bsample: cluster integrity, counts per stratum, nesting error"

* ---------------------------------------------------------------------------
* 7. sample under an old user version: float keys and two columns
* ---------------------------------------------------------------------------
local uv = c(stata_version)
version 13, user
assert c(userversion) == 13
sysuse auto, clear
gen long __id = _n
set seed 1
sample 30, pduplicates(1e-100)
xcert_ids
local ref `r(ids)'
local ref_state = c(rngstate)
sysuse auto, clear
gen long __id = _n
set seed 1
xsamplefe 30, pduplicates(1e-100)
assert r(n_uniforms) == 2
xcert_ids
assert "`ref'" == "`r(ids)'"
assert c(rngstate) == "`ref_state'"
* 100,000 rows with a float tie at the cutoff
clear
set obs 100000
gen long __id = _n
set seed 9
sample 8833, count
xcert_ids
local ref `r(ids)'
local ref_state = c(rngstate)
clear
set obs 100000
gen long __id = _n
set seed 9
xsamplefe 8833, count
xcert_ids
assert "`ref'" == "`r(ids)'"
assert c(rngstate) == "`ref_state'"
version `uv', user
assert c(userversion) == `uv'
noi di as text "  sample: parity under version 13, user (float keys, 2 columns)"

* ---------------------------------------------------------------------------
* 8. Unit draws depend on the seed and the set of units only, never on the
*    number of rows: the tie-break may not use the later uniform columns
* ---------------------------------------------------------------------------
local rng "`c(rng_current)'"
set rng kiss32
clear
set obs 1000000
set seed 9
gen double __u1 = runiform()
quietly duplicates report __u1
* kiss32 draws 32-bit uniforms: with a million draws the first key does tie
assert r(N) - r(unique_value) > 0
drop __u1
gen long u = _n
set seed 9
xsamplefe 18703, count unit(u) generate(a) numthreads(1)
expand 2 if u == 1
set seed 9
xsamplefe 18703, count unit(u) generate(b) numthreads(1)
assert a == b
set seed 9
xsamplefe 18703, count unit(u) generate(c8) numthreads(8)
assert a == c8
set rng `rng'
noi di as text "  unit draws: tie-break invariant to the number of rows and to the threads"

noi di as text "xsamplefe compatibility certification passed"
