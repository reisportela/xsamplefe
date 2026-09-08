noi di as text "xsamplefe estimation certification: samples versus full data"

* Does a unit sample drawn by xsamplefe reproduce the full-data regression?
* Whole units keep every spell, so the fixed-effect structure of the sample is
* the one of the population; the sample estimate is then an unbiased draw
* around the full-data estimate, with the precision loss implied by the size
* of the sample. Observation-level sampling of the same number of rows
* destroys that structure (singletons, broken mobility) and is noisier.

* ---------------------------------------------------------------------------
* 1. Synthetic AKM panel with known beta = 1
*    3,000 workers x 8 years, 150 firms, 15 percent yearly mobility, x
*    correlated with both fixed effects
* ---------------------------------------------------------------------------
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
    gen double psi = invnormal((firm - .5) / 150)
    gen double x = .5 * alpha + .4 * psi + rnormal()
    gen double y = x + alpha + psi + .1 * year + rnormal()
end

xcert_akm
reghdfe y x, absorb(worker firm year)
local b_full = _b[x]
local se_full = _se[x]
local N_full = e(N)
assert abs(`b_full' - 1) < 3 * `se_full'
assert e(num_singletons) == 0

* 20 percent of the workers with all their spells: same structure, unbiased
set seed 1
xsamplefe 20, absorb(worker firm year)
assert r(N_units_sampled) == 600 & r(N) == 4800
reghdfe y x, absorb(worker firm year)
local b_unit = _b[x]
local se_unit = _se[x]
assert e(num_singletons) == 0
assert abs(`b_unit' - `b_full') < 3 * `se_unit'
assert abs(`b_unit' - 1) < 3 * `se_unit'
noi di as text "  AKM 20% of workers: b = " %8.5f `b_unit' " (se " %7.5f `se_unit' ")  full: " ///
    %8.5f `b_full' " (se " %7.5f `se_full' ")"

* xhdfe on the same sample reproduces reghdfe (when xhdfe is installed)
capture which xhdfe
if (!c(rc)) {
    xhdfe y x, absorb(worker firm year)
    assert abs(_b[x] - `b_unit') < 1e-8 * max(1, abs(`b_unit'))
    assert abs(_se[x] - `se_unit') < 1e-6 * `se_unit'
    assert e(N) == 4800
    noi di as text "  xhdfe == reghdfe on the sample (b to 1e-8, se to 1e-6)"
}
else noi di as text "  xhdfe not found: reghdfe/xhdfe comparison skipped"

* the same number of rows drawn at the observation level: broken structure
xcert_akm
set seed 1
sample 20
assert _N == 4800
reghdfe y x, absorb(worker firm year)
local b_obs = _b[x]
local se_obs = _se[x]
assert e(num_singletons) > 0
assert e(N) < 4800
assert `se_obs' > `se_unit'
noi di as text "  AKM 20% of rows:    b = " %8.5f `b_obs' " (se " %7.5f `se_obs' ") after " ///
    e(num_singletons) " singletons dropped"

* movers(100) stayers(20): every mover kept, identification of the firm
* effects preserved; estimates still unbiased
xcert_akm
set seed 2
xsamplefe 20, absorb(worker firm year) movers(100) stayers(20) connected
assert r(N_movers_sampled) == r(N_movers_eligible)
reghdfe y x, absorb(worker firm year)
assert abs(_b[x] - `b_full') < 3 * _se[x]
assert _se[x] < `se_unit'
noi di as text "  AKM movers(100) stayers(20) connected: b = " %8.5f _b[x] " (se " %7.5f _se[x] ")"

* ---------------------------------------------------------------------------
* 2. Monte Carlo over 100 seeds: 10 percent worker samples are centred on the
*    full-data estimate and their standard errors are calibrated
* ---------------------------------------------------------------------------
tempname mc
tempfile mcfile
postfile `mc' seed double(b se) using `mcfile'
forvalues s = 1/100 {
    quietly {
        xcert_akm
        set seed `s'
        xsamplefe 10, absorb(worker firm year)
        reghdfe y x, absorb(worker firm year)
        post `mc' (`s') (_b[x]) (_se[x])
    }
}
postclose `mc'
use `mcfile', clear
gen double dev = b - `b_full'
gen byte covered = abs(dev) < 1.96 * se
quietly summarize dev
local bias = r(mean)
local sd = r(sd)
assert abs(`bias') < 3 * `sd' / sqrt(100)
quietly summarize covered
local coverage = r(mean)
assert `coverage' >= .90
quietly summarize se
local se_mean = r(mean)
* the spread of the sample estimates is the one the standard errors announce
* (var of b_s - b_full is se_s^2 - se_full^2 for a nested sample)
assert inrange(`sd' / sqrt(`se_mean'^2 - `se_full'^2), .7, 1.3)
noi di as text "  Monte Carlo (100 x 10% of workers): bias " %8.5f `bias' ///
    "  sd " %7.5f `sd' "  mean se " %7.5f `se_mean' ///
    "  coverage of b_full by b +/- 1.96 se " %5.3f `coverage'

* ---------------------------------------------------------------------------
* 3. Real panel (nlswork): 30 percent of the women, all their years
* ---------------------------------------------------------------------------
webuse nlswork, clear
reghdfe ln_wage tenure age, absorb(idcode year)
local bt_full = _b[tenure]
local ba_full = _b[age]
set seed 3
xsamplefe 30, absorb(idcode year)
reghdfe ln_wage tenure age, absorb(idcode year)
assert abs(_b[tenure] - `bt_full') < 3 * _se[tenure]
assert abs(_b[age] - `ba_full') < 3 * _se[age]
noi di as text "  nlswork 30% of idcode: tenure " %8.5f _b[tenure] " (full " %8.5f `bt_full' ///
    "), age " %8.5f _b[age] " (full " %8.5f `ba_full' ")"

* ---------------------------------------------------------------------------
* 4. AKM variance decomposition: what a sample does and does not reproduce
*    DGP of Bonhomme, Lamadon and Manresa ("The ABC of AKM", JEP 2026):
*    homophily mobility (logit in the squared distance between the worker type
*    and the firm effect) with their calibrated parameters (lambda = .559,
*    rho = .351, sigma = .369, s_alpha = .550, s_psi = .317, 10 worker groups).
*    Sampling is faithful: the *true* decomposition of the sample equals the
*    population's. The AKM *estimator* is not: its upward bias on Var(psi)
*    grows as the movers per firm fall, which is what sampling takes away.
* ---------------------------------------------------------------------------
capture program drop xcert_lamadon
program define xcert_lamadon
    syntax , workers(integer) firms(integer) periods(integer) [burn(integer 15) seed(integer 6344)]
    clear
    set seed `seed'
    set obs `workers'
    gen long worker = _n
    gen int g = ceil(runiform() * 10)
    gen double alpha_g = .550 * invnormal((g - .5) / 10)
    gen double alpha = alpha_g + rnormal(0, .550)
    gen int firm = ceil(runiform() * `firms')
    gen double psi = .317 * invnormal((firm - .5) / `firms')
    local files
    forvalues t = 1/`=`burn' + `periods'' {
        gen int f2 = ceil(runiform() * `firms')
        gen double psi2 = .317 * invnormal((f2 - .5) / `firms')
        gen double pr = .559 / (1 + exp((1 / .351) * ((psi2 - alpha_g)^2 - (psi - alpha_g)^2)))
        replace firm = f2 if firm != f2 & runiform() < pr
        replace psi = .317 * invnormal((firm - .5) / `firms')
        drop f2 psi2 pr
        if (`t' > `burn') {
            preserve
            gen int year = `t' - `burn'
            keep worker firm year alpha psi
            tempfile f`t'
            save `f`t''
            local files `files' `f`t''
            restore
        }
    }
    clear
    foreach f of local files {
        append using `f'
    }
    gen double y = alpha + psi + rnormal(0, .369)
    sort worker year
end

* decomposition of whatever is in memory, on its own connected set (AKM effects
* are only comparable within a component)
capture program drop xcert_vardec
program define xcert_vardec, rclass
    syntax , tag(string)
    quietly {
        xsamplefe 100, unit(worker) mobility(firm) connected connectivity generate(__lcc)
        local mpm = r(movers_per_mob)
        local weak = r(weak_mob_share)
        keep if __lcc
        capture drop a_hat p_hat
        reghdfe y, absorb(a_hat = worker p_hat = firm)
        summarize psi
        local vp = r(Var)
        summarize p_hat
        local vph = r(Var)
        correlate alpha psi, covariance
        local cov = r(cov_12)
        correlate a_hat p_hat, covariance
        local covh = r(cov_12)
    }
    noi di as text "  " %-22s "`tag'" " N " %8.0fc _N " movers/firm " %6.1f `mpm' ///
        "  Var(psi) true " %6.3f `vp' " AKM " %6.3f `vph' " ratio " %5.3f `vph'/`vp' ///
        "  2Cov true " %6.3f 2*`cov' " AKM " %7.3f 2*`covh'
    return scalar vp = `vp'
    return scalar cov2 = 2*`cov'
    return scalar ratio = `vph'/`vp'
    return scalar cov2_hat = 2*`covh'
    return scalar mpm = `mpm'
    return scalar weak = `weak'
end

xcert_lamadon, workers(6000) firms(300) periods(5)
assert _N == 30000
tempfile lam
save `lam'
xcert_vardec, tag("population")
local vp_pop = r(vp)
local cov_pop = r(cov2)
local ratio_pop = r(ratio)
local mpm_pop = r(mpm)
assert `ratio_pop' < 1.15
assert r(weak) == 0

foreach p in 25 10 {
    use `lam', clear
    set seed 1
    quietly xsamplefe `p', absorb(worker firm year) generate(s)
    quietly keep if s
    xcert_vardec, tag("`p'% of workers")
    local ratio`p' = r(ratio)
    local mpm`p' = r(mpm)
    local weak`p' = r(weak)
    * the sample keeps the population parameters: this is the sampling contract
    assert abs(r(vp) / `vp_pop' - 1) < .10
    assert abs(r(cov2) / `cov_pop' - 1) < .10
}
* the estimator degrades with the movers per firm
assert `mpm_pop' > `mpm25' & `mpm25' > `mpm10'
assert `ratio_pop' < `ratio25' & `ratio25' < `ratio10'
assert inrange(`ratio25', 1.05, 1.45) & inrange(`ratio10', 1.35, 2.20)
assert `weak10' > .10

* observation-level sampling of the same size is far worse and even flips the
* sign of the covariance
use `lam', clear
set seed 1
quietly sample 10
xcert_vardec, tag("10% of rows")
assert r(mpm) < `mpm10'
assert r(ratio) > 3 & r(ratio) > `ratio10'
assert r(cov2_hat) < 0

* keeping every mover restores an unbiased decomposition, of a different
* population: the estimand moves with the design
use `lam', clear
set seed 1
quietly xsamplefe 10, absorb(worker firm year) movers(100) stayers(10) generate(s)
quietly keep if s
xcert_vardec, tag("movers(100) stayers(10)")
assert r(ratio) < 1.15
assert abs(r(cov2) / `cov_pop' - 1) > .20
noi di as text "  AKM decomposition: sampling keeps the parameters, the estimator loses precision"

noi di as text "xsamplefe estimation certification passed"
