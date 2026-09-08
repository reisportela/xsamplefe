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

noi di as result "XSAMPLEFE ADVERSARIAL CERTIFICATION PASSED"
