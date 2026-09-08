* xsamplefe_basics.do -- a first course with an artificial labour panel.
* Save any unsaved data before running: this example starts with clear.
* Requires xsamplefe and its plugin; no downloads or other packages.
version 14.0
clear
set more off
set varabbrev off
set rng mt64
set seed 20260908

* Two hundred workers, six years, twenty firms, three regions.
set obs 1200
generate long worker = ceil(_n / 6)
generate int year = 2000 + mod(_n - 1, 6)
generate byte region = 1 + mod(worker, 3)
generate byte firm = 1 + mod(worker - 1 + floor((year - 2000) / 3) * (mod(worker, 3) == 0), 20)
generate byte tenure = 1 + mod(worker + 2 * year, 8)
generate double ln_wage = 1.5 + .04 * tenure + .02 * mod(worker, 11) + .01 * (year - 2000) + rnormal(0, .1)
label data "Artificial worker panel for xsamplefe; no real people"
isid worker year
xtset worker year
egen byte first_worker = tag(worker)

* A row sample: ten percent of observations, with an indicator to inspect it.
xsamplefe 10, seed(123) generate(rows)
tabulate rows
list worker year rows in 1/18, sepby(worker)

* A worker sample: ten percent of workers, keeping each complete history.
xsamplefe 10, unit(worker) seed(123) generate(workers)
assert r(N_units_sampled) == 20 & r(N_frame_retained) == 120
bysort worker: assert workers == workers[1]
tabulate workers if first_worker
list worker year firm if workers in 1/60, sepby(worker)

* absorb() chooses its first effect as the unit: here this is the same draw.
xsamplefe 10, absorb(worker firm year) seed(123) generate(same_workers)
assert workers == same_workers

* count is a number of units per stratum. Regions must be constant per worker.
xsamplefe 5, count unit(worker) by(region) seed(456) generate(stratified)
assert r(N_units_sampled) == 15
tabulate region stratified if first_worker

* if samples inside its condition and keeps everything outside it.
* Use the condition with the indicator to restrict a later analysis to that frame.
xsamplefe 20 if region == 1, unit(worker) seed(123) generate(regional)
assert regional == 1 if region != 1
summarize ln_wage if regional & region == 1

* A time restriction splits workers. any includes their full histories;
* all excludes split workers from the frame and leaves their rows untouched.
xsamplefe 20 if year >= 2003, unit(worker) any seed(123) generate(any_year)
xsamplefe 20 if year >= 2003, unit(worker) all seed(123) generate(all_year)
assert all_year == 1

* Balance means coverage of every observed frame period, not unique keys.
preserve
drop if year == 2005 & mod(worker, 7) == 0
xsamplefe 25, unit(worker) time(year) balanced seed(123) generate(balanced_sample)
assert r(N_units_ineligible) == 28
tabulate year if balanced_sample
restore

* Estimate on the indicator without deleting the full data.
areg ln_wage tenure i.year if workers, absorb(worker) vce(cluster worker)
* With the corresponding estimator installed, the same selection is usable as:
* reghdfe ln_wage tenure if workers, absorb(worker firm year) vce(cluster worker)
* xhdfe   ln_wage tenure if workers, absorb(worker firm year) vce(cluster worker)

* Without generate(), xsamplefe deletes unretained observations in memory.
* preserve/restore makes this demonstration reversible.
preserve
xsamplefe 10, unit(worker) seed(123)
assert _N == 120
summarize ln_wage tenure
restore
assert _N == 1200

display as result "xsamplefe_basics.do complete"
display as text "Next: xsamplefe_tour.do covers mobility, connectivity, and groups."
