* xsamplefe_tour.do -- mobility, connectivity, and teams, using artificial data.
* Save any unsaved data before running. Each main example creates its own data.
* Requires xsamplefe and its plugin; no downloads or other packages.
version 14.0
clear
set more off
set varabbrev off
set rng mt64
set seed 20260908

* A worker-firm panel with stayers and workers changing firm after three years.
set obs 6000
generate long worker = ceil(_n / 6)
generate int year = 2000 + mod(_n - 1, 6)
generate byte firm = 1 + mod(worker - 1 + floor((year - 2000) / 3) * (mod(worker, 3) == 0), 20)
bysort worker firm: generate byte first_link = _n == 1 & !missing(firm)
bysort worker: egen int nfirms = total(first_link)
egen byte first_worker = tag(worker)
tabulate nfirms if first_worker

* Compare the eligible population's network with a simple worker sample.
xsamplefe 10, absorb(worker firm year) connectivity seed(321) generate(simple)
display "Frame components: " r(N_components_frame) "; sample components: " r(N_components)
display "Largest component shares: " r(lcc_share_frame) " -> " r(lcc_share)
display "Movers per firm: " r(movers_per_mob_frame) " -> " r(movers_per_mob)

* mobstrata allocates separately to each mobility class, with integer rounding.
xsamplefe 10, absorb(worker firm year) mobstrata seed(321) generate(proportional)
tabulate nfirms proportional if first_worker

* Keep all movers and ten percent of stayers: a different sample composition.
xsamplefe 10, absorb(worker firm year) movers(100) stayers(10) seed(321) generate(movers_first)
assert r(N_movers_sampled) == r(N_movers_eligible)
tabulate nfirms movers_first if first_worker

* connected removes sampled units outside the largest component.
xsamplefe 10, absorb(worker firm year) connected seed(321) generate(component)
display "Rows removed by connected: " r(N_connected_dropped)
assert component <= simple

* reconnect grows the sample. The requested share can be unattainable.
* gain prioritises the number of rows joined; key orders the frontier by its draw.
xsamplefe 10, absorb(worker firm year) reconrule(gain) seed(321) generate(rejoined)
display "Units added: " r(N_units_reconnected) "; final largest share: " r(lcc_share)
assert rejoined >= simple
xsamplefe 10, absorb(worker firm year) reconrule(key) seed(321) generate(random_frontier)
assert random_frontier >= simple

* minmovers() prunes whole units until every retained firm meets the threshold.
* It can empty a sample; it does not correct limited mobility bias.
xsamplefe 10, absorb(worker firm year) minmovers(2) seed(321) generate(stronger_links)
display "Units removed: " r(N_units_minmovers_dropped)
display "Pruning passes: " r(minmovers_iterations)
assert stronger_links <= simple

* Missing mobility values are not links, but their rows stay with the worker.
preserve
replace firm = . if year == 2005
xsamplefe 10, unit(worker) mobility(firm) seed(321) generate(with_missing)
assert with_missing == simple
restore

* Teams: ninety patents, two to four inventors each, in long format.
clear
set obs 90
generate long patent = _n
generate byte team_size = 2 + mod(patent, 3)
expand team_size
bysort patent: generate long inventor = 1 + mod(2 * patent + _n, 40)
isid patent inventor
egen byte first_patent = tag(patent)

* group() is the default sampling unit, so every retained patent has its full team.
xsamplefe 20, group(patent) individual(inventor) seed(123) generate(patents)
assert r(N_units_sampled) == 18
bysort patent: assert patents == patents[1]
tabulate team_size patents if first_patent

* Sampling inventors and applying group closure changes the final inclusion rule.
* any retains every patent touched by a drawn inventor; all requires all its inventors.
* Patents remain complete, but an inventor can retain only part of their patents.
xsamplefe 20, group(patent) individual(inventor) unit(inventor) seed(123) generate(touched)
display "Inventors drawn / retained / partial: " r(N_units_sampled) " / " r(N_units_retained) " / " r(N_units_partial)
xsamplefe 20, group(patent) individual(inventor) unit(inventor) grouprule(all) seed(123) generate(all_members)
bysort patent: assert touched == touched[1] & all_members == all_members[1]
assert all_members <= touched
tabulate touched all_members if first_patent

display as result "xsamplefe_tour.do complete"
