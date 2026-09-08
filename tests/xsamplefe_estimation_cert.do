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

noi di as text "xsamplefe estimation certification passed"
