* A short installation check using artificial data; no other packages needed.
* Restores the data, RNG, and display/abbreviation settings that were in use.
version 14.0
local old_rng = c(rngstate)
local old_more = c(more)
local old_abbrev = c(varabbrev)
preserve
capture noisily {
    set more off
    set varabbrev off
    which xsamplefe
    display "Stata: " c(stata_version) "; OS: " c(os) "; machine: " c(machine_type)
    clear
    set obs 1200
    generate long rowid = _n
    generate long worker = ceil(_n / 4)
    generate byte period = mod(_n - 1, 4) + 1
    generate byte firm = mod(worker + period, 17)
    generate byte stratum = mod(worker, 3)
    replace stratum = .a if mod(worker, 13) == 0

    xsamplefe 25, unit(worker) mobility(firm) time(period) seed(321) generate(one) numthreads(1)
    assert r(N_units_sampled) == 75 & r(N) == 300
    assert r(openmp_enabled) == 1 & r(threads_used) == 1
    xsamplefe 25, unit(worker) mobility(firm) time(period) seed(321) generate(eight) numthreads(8)
    assert r(threads_used) == min(8, r(thread_capacity))
    assert one == eight
    bysort worker: assert one == one[1]
    gsort -rowid
    xsamplefe 25, unit(worker) mobility(firm) time(period) seed(321) generate(reordered) numthreads(1)
    assert one == reordered

    generate long team = ceil(worker / 3)
    xsamplefe 25, unit(worker) group(team) seed(321) generate(teams) numthreads(1)
    bysort team: assert teams == teams[1]

    xsamplefe 17.5, by(stratum) seed(654) generate(rows) numthreads(1)
    local retained = r(N)
    local after_draw = c(rngstate)
    set seed 654
    sample 17.5, by(stratum)
    assert rows == 1 & _N == `retained'
    assert c(rngstate) == "`after_draw'"
}
local check_rc = _rc
restore
quietly set rngstate `old_rng'
set more `old_more'
set varabbrev `old_abbrev'
if (`check_rc') exit `check_rc'
display as result "XSAMPLEFE RESEARCHER CHECK PASSED"
