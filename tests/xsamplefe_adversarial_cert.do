* Regression tests for the adversarial audit of 08sep2026.
set varabbrev off

* Wildcards and ranges are lists of effects; only # forms an interaction.
clear
set obs 100
gen long worker_a = ceil(_n / 5)
gen byte worker_b = mod(_n, 5)
gen double x = _n
xsamplefe 50, absorb(worker_a worker_b) seed(17) generate(explicit) numthreads(1)
assert r(N_units) == 20 & r(N_units_sampled) == 10
xsamplefe 50, absorb(worker_*) seed(17) generate(wildcard) numthreads(1)
assert r(N_units) == 20 & "`r(unit)'" == "worker_a"
assert "`r(mobility)'" == "worker_b" & wildcard == explicit
xsamplefe 50, absorb(worker_a-worker_b) seed(17) generate(varrange) numthreads(1)
assert r(N_units) == 20 & varrange == explicit
xsamplefe 50, absorb(worker_a#worker_b) seed(17) generate(interaction) numthreads(1)
assert r(N_units) == 100 & r(N_units_sampled) == 50
foreach bad in "worker_a(x)" "(worker_a worker_b)" "c.x" "worker_*#worker_b" {
    capture xsamplefe 50, absorb(`bad') generate(bad)
    assert _rc == 198
}
foreach bound in minobs(2) maxobs(0) {
    capture xsamplefe 50, `bound' generate(bad)
    assert _rc == 198
}

* Counts beyond signed 64-bit range still saturate, exactly as native sample.
foreach amount in 9223372036854775808 100000000000000000000 {
    preserve
    set seed 37
    sample `amount', count
    local state = c(rngstate)
    assert _N == 100
    restore
    set seed 37
    xsamplefe `amount', count generate(huge_count) replace numthreads(1)
    assert r(count) == `amount' & r(N) == 100 & r(n_uniforms) == 0
    assert huge_count == 1 & c(rngstate) == "`state'"
}

* A failed draw changes neither data nor the caller's RNG, including seed().
gen byte inside = mod(_n, 2)
quietly datasignature
local signature "`r(datasignature)'"
set seed 19
local state = c(rngstate)
capture xsamplefe 50 if inside, unit(worker_a) seed(23) generate(bad)
assert _rc == 198
assert c(rngstate) == "`state'"
capture confirm variable bad
assert _rc == 111
quietly datasignature
assert "`r(datasignature)'" == "`signature'"
capture xsamplefe 50, unit(worker_a) by(worker_b) seed(23) generate(bad)
assert _rc == 198
assert c(rngstate) == "`state'"

* Native sample is the independent oracle for rows and RNG state.
clear
set obs 1200
gen long rowid = _n
gen byte stratum = mod(_n, 7)
replace stratum = .a if mod(_n, 11) == 0
replace stratum = .z if mod(_n, 13) == 0
foreach rng in mt64 kiss32 {
    set rng `rng'
    forvalues seed = 1/5 {
        foreach design in "0" "0.5" "17.5" "100" "0, count" "37, count" "1200, count" {
            gettoken amount options : design, parse(",")
            local options = subinstr("`options'", ",", "", 1)
            foreach strata in "" "by(stratum)" {
                preserve
                set seed `seed'
                sample `amount' if mod(rowid, 3), `options' `strata'
                local state = c(rngstate)
                quietly levelsof rowid, local(ids)
                restore
                set seed `seed'
                quietly xsamplefe `amount' if mod(rowid, 3), `options' `strata' generate(s) replace numthreads(1)
                assert c(rngstate) == "`state'"
                quietly levelsof rowid if s, local(actual)
                assert "`ids'" == "`actual'"
            }
        }
    }
}
set rng mt64

* Whole units, strings, missing dimensions, row order, and real OpenMP teams.
clear
set obs 12000
gen long rowid = _n
gen long worker = ceil(_n / 6)
gen int year = mod(_n - 1, 6) + 2000
gen int firm = mod(worker + year, 37)
gen str12 worker_text = string(worker, "%08.0f")
replace year = . if mod(worker, 17) == 0
replace firm = . if mod(worker, 19) == 0
foreach threads in 1 8 48 {
    xsamplefe 25, unit(worker_text) time(year) mobility(firm) seed(29) generate(s`threads') numthreads(`threads')
    assert r(N_units) == 2000 & r(N_units_sampled) == 500
    assert r(openmp_enabled) == 1
    assert r(threads_used) == min(`threads', r(thread_capacity))
}
assert s1 == s8 & s1 == s48
sort worker rowid
by worker: assert s1 == s1[1]
gsort -rowid
xsamplefe 25, unit(worker_text) time(year) mobility(firm) seed(29) generate(shuffled) numthreads(8)
assert shuffled == s1
assert rowid == 12001 - _n

* A frontier can consist entirely of stayers; reconnect is not a bias correction.
clear
set obs 10
gen long worker = _n
gen byte firm = cond(worker == 10, 2, 1)
local chosen 0
forvalues seed = 1/100 {
    quietly xsamplefe 2, count unit(worker) mobility(firm) seed(`seed') generate(s) replace numthreads(1)
    if (s[10] & `chosen' == 0) local chosen `seed'
}
assert `chosen' > 0
xsamplefe 2, count unit(worker) mobility(firm) seed(`chosen') recontarget(95) generate(t) numthreads(1)
assert r(N_movers_eligible) == 0 & r(N_units_reconnected) == 8
assert abs(r(lcc_share) - .9) < 1e-12

* The xtset time variable is read without sorting: in refers to the caller's
* order, and the data keep it.
clear
set obs 60
gen long w = ceil(_n / 3)
gen int t = mod(_n - 1, 3) + 1
xtset w t
set seed 99
gen double sh = runiform()
sort sh
gen long order0 = _n
xsamplefe 50 in 1/30, unit(w) balanced any seed(1) generate(implicit)
assert order0 == _n
xsamplefe 50 in 1/30, unit(w) time(t) balanced any seed(1) generate(explicit)
assert implicit == explicit

* Observation mode with ties on the first keys, against Stata's own sort:
* the order is (u1, u2, u3, row) within every stratum. The plugin is called
* directly with constructed keys; a large stratum takes the bucket path.
quietly findfile xsamplefe.ado
local xk_plugin = subinstr("`r(fn)'", "xsamplefe.ado", "xsamplefe.plugin", 1)
capture program drop xcert_plugin
program xcert_plugin, plugin using("`xk_plugin'")
capture program drop xcert_keys
program define xcert_keys
    args pct nby threads
    tempvar out ref n k
    quietly gen byte `out' = 0
    local byvar = cond(`nby', "s", "")
    plugin call xcert_plugin touse `byvar' u1 u2 u3 `out', ///
        "cfg=is_count=0;pct=`pct';has_unit=0;nby=`nby';has_time=0;has_mob=0;has_group=0;nu=3;num_threads=`threads';s_prefix=xk_;all_rows=1;out_zero=1"
    sort `byvar' u1 u2 u3 rowid
    if (`nby') by s: gen long `k' = _n
    else gen long `k' = _n
    if (`nby') by s: gen long `n' = _N
    else gen long `n' = _N
    gen byte `ref' = `k' <= int(`n' * `pct' / 100 + .5)
    assert `out' == `ref'
    sort rowid
end
clear
set obs 400000
gen long rowid = _n
gen byte touse = 1
gen int s = mod(_n, 40)
set seed 7
gen double u1 = round(runiform(), .01)
gen double u2 = round(runiform(), .1)
gen double u3 = runiform()
foreach threads in 1 8 {
    xcert_keys 37 1 `threads'
    xcert_keys 37 0 `threads'
}

* The draw depends on the order of the unit values only: dense integers,
* sparse integers, non-integers and shifted integers rank the same units.
clear
set obs 30000
gen long w = ceil(_n / 3)
gen double w_sparse = w * 1e9 + 12345
gen double w_half = w + .5
gen double w_shift = w - 1e15
gen int f = mod(w * 7 + _n, 97)
foreach v in w w_sparse w_half w_shift {
    xsamplefe 20, unit(`v') mobility(f) connectivity seed(3) generate(d_`v') numthreads(8)
}
assert d_w == d_w_sparse & d_w == d_w_half & d_w == d_w_shift

* Without if/in the plugin takes the frame from the missing unit and group
* values; with if 1 it reads the marked sample. Both must agree.
clear
set obs 20000
gen long w = ceil(_n / 5)
gen int f = mod(_n * 7, 101)
gen int t = mod(_n, 4)
replace w = .a if mod(_n, 211) == 0
replace t = . if mod(_n, 13) == 0
gen byte g5 = mod(w, 5)
foreach design in "unit(f) group(w)" "unit(f) group(w) grouprule(all) mobility(t) connectivity" ///
    "unit(w) mobility(f) time(t) minperiods(2)" "unit(w) by(g5)" "by(t)" "" {
    xsamplefe 25, `design' seed(5) generate(plain) numthreads(8)
    local nf = r(N_frame)
    xsamplefe 25 if 1, `design' seed(5) generate(marked) numthreads(8)
    assert r(N_frame) == `nf'
    assert plain == marked
    drop plain marked
}

* Two by() columns with missing categories, against native sample.
clear
set obs 5000
gen long rowid = _n
gen byte a = mod(_n, 5)
replace a = .a if mod(_n, 17) == 0
gen double b = mod(_n, 3) + .5
replace b = . if mod(_n, 11) == 0
preserve
set seed 41
sample 23, by(a b)
quietly levelsof rowid, local(ids)
local state = c(rngstate)
restore
set seed 41
xsamplefe 23, by(a b) generate(sb) numthreads(8)
quietly levelsof rowid if sb, local(actual)
assert "`ids'" == "`actual'"
assert c(rngstate) == "`state'"

* reconnect follows its documented rule: when a pick merges a component into
* the largest one, the units linked to that component's values join the
* frontier at once. Documented greedy at 61%: M1 (gain 5), then M2 (gain 10,
* through the value E of the merged component) -> 25 of 27 rows.
clear
input byte(w f s n)
1 1 1 10
2 2 2 2
2 5 2 1
3 3 3 8
4 4 4 1
5 6 5 1
6 1 5 1
6 2 5 1
7 5 5 1
7 3 5 1
8 1 5 1
8 4 5 1
end
expand n
drop n
local chosen 0
forvalues seed = 1/200 {
    quietly xsamplefe 1, count by(s) unit(w) mobility(f) seed(`seed') generate(g) replace numthreads(1)
    quietly count if g & w >= 6
    local nm = r(N)
    quietly count if g & w == 5
    if (`nm' == 0 & r(N) > 0 & `chosen' == 0) local chosen `seed'
}
assert `chosen' > 0
xsamplefe 1, count by(s) unit(w) mobility(f) seed(`chosen') recontarget(61) generate(r) numthreads(1)
assert r(N_units_reconnected) == 2 & abs(r(lcc_share) - 25 / 27) < 1e-12
assert r == 1 if inlist(w, 6, 7)
assert r == 0 if w == 8

noi di as result "XSAMPLEFE ADVERSARIAL CERTIFICATION PASSED"
