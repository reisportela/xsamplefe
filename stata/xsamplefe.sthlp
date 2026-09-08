{smcl}
{* *! version 1.2.0  08sep2026}{...}
{vieweralsosee "[D] sample" "help sample"}{...}
{vieweralsosee "[R] bsample" "help bsample"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "reghdfe" "help reghdfe"}{...}
{vieweralsosee "xhdfe" "help xhdfe"}{...}
{vieweralsosee "xhdfeconnected" "help xhdfeconnected"}{...}
{viewerjumpto "Syntax" "xsamplefe##syntax"}{...}
{viewerjumpto "Description" "xsamplefe##description"}{...}
{viewerjumpto "Sampling units" "xsamplefe##units"}{...}
{viewerjumpto "Reproducibility" "xsamplefe##reproducibility"}{...}
{viewerjumpto "Mobility fidelity" "xsamplefe##mobility"}{...}
{viewerjumpto "Connectivity" "xsamplefe##connectivity"}{...}
{viewerjumpto "Limited mobility bias" "xsamplefe##bias"}{...}
{viewerjumpto "Options" "xsamplefe##options"}{...}
{viewerjumpto "Examples" "xsamplefe##examples"}{...}
{viewerjumpto "Stored results" "xsamplefe##results"}{...}
{viewerjumpto "Author" "xsamplefe##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :{cmd:xsamplefe} {hline 2}}Random samples of panel / fixed-effect data for {helpb reghdfe} and {helpb xhdfe}{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:xsamplefe} {it:#} {ifin} [{cmd:,} {it:options}]

{p 8 15 2}
{cmd:by} {varlist}{cmd::} {cmd:xsamplefe} {it:#} [{cmd:,} {it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt :{opt c:ount}}{it:#} is the number of observations (or units) to draw per stratum, not a percentage{p_end}
{synopt :{opth by(varlist)}}draw a {it:#} percent (or {it:#} unit) sample within each stratum{p_end}
{synopt :{opth gen:erate(newvar)}}save a 0/1 indicator instead of deleting observations; {opt keep(newvar)} is a synonym ({helpb sample2})
{p_end}
{synopt :{opt replace}}overwrite an existing {opt generate()} variable{p_end}
{synopt :{opt seed(#)}}set the random-number seed before drawing{p_end}

{syntab:Sampling unit (reghdfe alignment)}
{synopt :{opth abs:orb(varlist)}}fixed effects of the intended regression; the first one is the default sampling unit{p_end}
{synopt :{opth group(varname)}}group variable of {cmd:reghdfe, group()}; rows of a group are never separated{p_end}
{synopt :{opth ind:ividual(varname)}}individual variable of {cmd:reghdfe, individual()}; requires {opt group()}{p_end}
{synopt :{opth unit(varname)}}explicit sampling unit (whole units are kept or dropped){p_end}

{syntab:Panel structure}
{synopt :{opth time(varname)}}time variable (default: the {helpb xtset} time variable when needed){p_end}
{synopt :{opt bal:anced}}only units observed in every period of the frame are eligible{p_end}
{synopt :{opt minp:eriods(#)}, {opt maxp:eriods(#)}}bounds on the number of distinct periods per unit{p_end}
{synopt :{opt mino:bs(#)}, {opt maxo:bs(#)}}bounds on the number of observations per unit{p_end}

{syntab:Mobility structure}
{synopt :{opth mob:ility(varname)}}dimension across which units move (default: second {opt absorb()} variable, or the
{opt individual()}/{opt group()} counterpart){p_end}
{synopt :{opt minm:obility(#)}, {opt maxm:obility(#)}}bounds on the number of distinct {opt mobility()} values per unit{p_end}
{synopt :{opt mov:ers(#)}, {opt stay:ers(#)}}separate sampling rates (or counts) for movers and stayers{p_end}
{synopt :{opt mobstr:ata}}add the number of distinct {opt mobility()} values per unit to the {opt by()} strata{p_end}
{synopt :{opt connectiv:ity}}report the components of the unit-mobility graph on the frame and on the sample{p_end}
{synopt :{opt conn:ected}}keep only the largest connected component of the sampled unit-mobility graph{p_end}
{synopt :{opt minmov:ers(#)}}drop the {opt mobility()} values with fewer than {it:#} movers, and the units linked to them{p_end}
{synopt :{opt recon:nect}}add unsampled units until the largest component reaches the share it has in the frame{p_end}
{synopt :{opt recont:arget(#)}}same, with an explicit target share (percent of the sample rows); implies {opt reconnect}{p_end}
{synopt :{opt reconr:ule(gain|key)}}order in which {opt reconnect} takes the frontier: largest gain (default) or smallest uniform key{p_end}

{syntab:if/in and groups}
{synopt :{opt any}}a unit (or group) with at least one row selected by {it:if}/{it:in} belongs to the frame, with all its rows{p_end}
{synopt :{opt all}}a unit (or group) belongs to the frame only if all its rows are selected by {it:if}/{it:in}{p_end}
{synopt :{opt groupr:ule(any|all)}}when the unit differs from {opt group()}: keep a group if {cmd:any} (default) or {cmd:all} of its units were drawn{p_end}

{syntab:Performance}
{synopt :{opt numt:hreads(#)}}OpenMP threads (0 = runtime default){p_end}
{synopt :{opt verb:ose}}print per-phase timings of the plugin{p_end}
{synopt :{opt pdup:licates(#)}}as in {helpb sample}; controls the number of uniform key columns (default 1e-4){p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{it:#} is a percentage between 0 and 100 unless {opt count} is specified.
{cmd:by} is allowed as a prefix (equivalent to {opt by()}); see {manhelp by D}.
Observations not meeting the optional {it:if}/{it:in} criteria are kept (sampled at 100 percent), as in {helpb sample}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:xsamplefe} draws a pseudo-random sample without replacement from data in
memory and, by default, deletes the observations that were not drawn. It is a
superset of Stata's {helpb sample} and of Weesie's {helpb sample2}
(STB-37 dm46), and it is designed for panel and network data that will be
estimated with {helpb reghdfe} or {helpb xhdfe}: instead of drawing
observations, it draws whole {it:units} (workers, firms, patents, ...) so that
the fixed-effect structure of the sample stays estimable.

{pstd}
Without {opt absorb()}, {opt group()} or {opt unit()}, {cmd:xsamplefe} samples
observations exactly like {helpb sample}: the same {it:#}/{opt count}/{opt by()}
semantics, the same rounding ({cmd:int(N*#/100+.5)} per stratum), and, under the
same seed and data order, the {it:same drawn observations} (see
{help xsamplefe##reproducibility:Reproducibility}). With a sampling unit it
behaves like {cmd:sample2, cluster()}: units are the clusters, {opt any}/{opt all}
resolve units split by {it:if}/{it:in}, and {opt generate()} (alias
{opt keep()}) returns an indicator instead of deleting rows.

{pstd}
On top of that, {cmd:xsamplefe} adds

{p 8 12 2}- stratified samples ({opt by()}) whose strata must be constant within units;{p_end}
{p 8 12 2}- panel eligibility filters: balanced panels, minimum/maximum number of periods or observations per unit;{p_end}
{p 8 12 2}- mobility structure: bounds on the number of distinct values of a second dimension per unit (firms per
worker, inventors per patent, ...), separate rates for movers and stayers, and an optional restriction to the largest
connected component;{p_end}
{p 8 12 2}- {cmd:reghdfe, group() individual()} designs (patents-inventors, papers-authors, groups of workers): rows of
a group are never separated, whichever unit is sampled.{p_end}

{pstd}
All the work is done by a C++ plugin ({cmd:xsamplefe.plugin}) that uses
OpenMP and has no external dependencies (no DLL or shared library besides the
compiler runtime). The result never depends on the number of threads.


{marker units}{...}
{title:Sampling units and eligibility}

{pstd}
The {it:sampling unit} is determined in this order: {opt unit()} if specified;
otherwise the {opt group()} variable; otherwise the first {opt absorb()}
variable; otherwise single observations. Units are the clusters that are kept
or dropped as a whole. For an AKM-style regression,
{cmd:absorb(worker firm year)} samples workers with all their spells; with
{cmd:unit(firm)} it samples firms with all their observations.

{pstd}
{it:Frame.} Rows selected by {it:if}/{it:in} with a non-missing unit form the
sampling frame. By default (strict), a unit with rows both inside and outside
the frame is an error (as in {cmd:sample2}); {opt any} pulls such units entirely
into the frame and {opt all} pushes them entirely out (their rows are then
kept, unsampled). When {opt group()} is specified and differs from the unit,
these rules apply to groups.

{pstd}
{it:Eligibility.} Among the units in the frame, only those meeting
{opt balanced}, {opt minperiods()}, {opt maxperiods()}, {opt minobs()},
{opt maxobs()}, {opt minmobility()} and {opt maxmobility()} are eligible.
Ineligible units are {it:dropped} (they are not part of the population being
sampled); their count is reported and stored. Per-unit statistics are computed
on the frame rows of the unit: number of rows, number of distinct
{opt time()} values, number of distinct {opt mobility()} values. Missing
{opt time()} or {opt mobility()} values never count as a period or a link, and
they never remove the row or the unit from the frame; only a missing
{opt unit()} or {opt group()} value does.

{pstd}
{opt balanced} compares the number of {it:distinct} periods of the unit with
the number of distinct periods of the frame: it does not require one row per
period (a repeated {it:(unit, time)} pair is allowed and is kept) and it does
not check {cmd:isid}. A unit with no non-missing {opt time()} value is not
balanced, so when the frame has no period at all ({cmd:r(N_periods)} is 0) no
unit is eligible and a note says so.

{pstd}
{it:Strata.} The stratum of a unit is the (possibly missing) value of the
{opt by()} variables, which must be constant within units. Within each stratum
{cmd:int(n*#/100+.5)} units are drawn ({opt count}: {cmd:min(#,n)}), where
{it:n} is the number of eligible units in the stratum. With {opt movers()} or
{opt stayers()} every stratum is further split into movers (two or more
distinct {opt mobility()} values) and stayers, and each class uses its own rate;
a class without an explicit rate uses {it:#}.

{pstd}
{it:Group closure.} With {opt group()} and a different sampling unit (for
instance {cmd:group(patent) individual(inventor) unit(inventor)}), a group is
retained with {it:all} its rows when {cmd:any} of its units was drawn (default)
or only when {cmd:all} of them were ({opt grouprule(all)}). Groups are the
indivisible blocks, so the closure overrides the unit-level decisions and has
three consequences that are reported rather than prevented:

{p 8 12 2}- a unit that was {it:not} drawn keeps every row it has in a retained group, and an {it:ineligible} unit (one
the filters had dropped) comes back the same way: {cmd:r(N_units_ineligible_retained)} counts them;{p_end}
{p 8 12 2}- a unit that {it:was} drawn can end up with only part of its rows, because some of its groups were not kept
(this is the normal outcome of {opt grouprule(all)}): {cmd:r(N_units_partial)} counts the units whose retained rows are
fewer than their frame rows;{p_end}
{p 8 12 2}- {cmd:r(N_movers_retained)} classifies a retained unit as a mover using the mobility it has
{it:in the frame}, not the mobility left in the sample after the closure.{p_end}

{pstd}
{cmd:reconnect} may not be combined with a group closure.

{pstd}
{it:Connected set.} {opt connected} builds the bipartite graph between units
and {opt mobility()} values on the retained frame rows and keeps only its
largest component (measured in rows; ties go to the component containing the
smallest unit value). Units that share a {opt group()} are one block of that
graph, so the cut never splits a group. Rows outside the largest component are
dropped after sampling, so the final sample can be smaller than {it:#} percent;
use {helpb xhdfeconnected} for the leave-one-out connected set of AKM models.
See {help xsamplefe##connectivity:Connectivity} for the diagnostics reported
with {opt connectivity} (implied by {opt connected} and {opt reconnect}) and
for {opt reconnect}.


{marker reproducibility}{...}
{title:Reproducibility}

{pstd}
{cmd:xsamplefe} draws its uniform keys with {helpb runiform()}, in the same
order and number as {helpb sample} (one or more columns over all observations,
see {opt pduplicates()}; {cmd:double} columns, or the two {cmd:float} columns
{cmd:sample} uses when {cmd:c(userversion)} is below 14 and the dataset has
fewer than 2^31 observations), and selects the smallest keys within each
stratum. Consequently, after {cmd:set seed} {it:#}:

{p 8 12 2}- {cmd:xsamplefe} {it:#} [{it:if}] [{cmd:, by() count}] retains exactly the observations that {cmd:sample}
{it:#} [{it:if}] [{cmd:, by() count}] retains, and leaves the random-number generator in the same state
({cmd:sample 100} and {cmd:count} with {it:#} {ul:>} {cmd:_N} draw nothing in both commands);{p_end}
{p 8 12 2}- unit-level samples depend only on the seed and on the {it:set} of unit values in the frame (the {it:r}-th
smallest unit value receives the {it:r}-th draw), so they are invariant to the physical order of the data and to the
number of rows each unit has;{p_end}
{p 8 12 2}- results are invariant to {opt numthreads()}.{p_end}

{pstd}
The second and further uniform columns start at draw {cmd:_N}+1, so unit-level
sampling cannot use them to break a tie in the first key without making the
draw depend on the number of rows. When two units tie on the first key (a real
possibility under {cmd:set rng kiss32}, which draws 32-bit uniforms, and
essentially impossible under {cmd:mt64}), the tie is broken by a hash of that
first key and of the unit's rank, and finally by the rank itself. Observation-
level sampling keeps {cmd:sample}'s own rule (the further columns, then the row
order), which is what bit-identity with {cmd:sample} requires.

{pstd}
Note that {cmd:by} {it:varlist}{cmd:, sort:} sorts the data {it:before} the
command runs and Stata's sort orders ties arbitrarily, so neither {cmd:sample}
nor {cmd:xsamplefe} is reproducible under that prefix unless the data were
already sorted ({cmd:sort, stable}) or {opt by()} is used instead.

{pstd}
{cmd:xsamplefe} leaves the data in the order it found them (the internal steps
use {help sortpreserve:sortpreserve}, and the plugin never reorders rows). For
that reason, and unlike {cmd:sample}, {it:in} may be combined with {opt by()}:
the range refers to the current order of the data and the rows outside it are
kept.

{pstd}
{it:Options without an effect.} {opt any} and {opt all} need a sampling unit
and are ignored, with a note, without one; {opt replace} does nothing unless
{opt generate()} or {opt keep()} is specified; anything after a comma inside
{opt absorb()} (for instance {cmd:absorb(id1 id2, savefe)}) is discarded, so
that a {cmd:reghdfe} call can be pasted unchanged.


{marker mobility}{...}
{title:Mobility fidelity}

{pstd}
Whole-unit sampling keeps every spell of a drawn unit, so the mobility of each
retained unit (distinct {opt mobility()} values, transitions) is exactly the
one in the population, and the shares of movers and of the mobility classes in
the sample are unbiased. It does {it:not} guarantee the exact composition of
the sample, nor that the sample stays connected (see
{help xsamplefe##connectivity:Connectivity}). To hold the mobility classes
close to the population, stratify by the number of distinct mobility values
per unit, either with {opt mobstrata} or by building the class by hand:

{phang2}{cmd:. xsamplefe 10, absorb(worker firm year) mobstrata}{p_end}

{phang2}{cmd:. bysort worker firm: gen byte first = _n == 1 & !missing(firm)}{p_end}
{phang2}{cmd:. bysort worker: egen int nfirms = total(first)}{p_end}
{phang2}{cmd:. xsamplefe 10, absorb(worker firm year) by(nfirms)}{p_end}

{pstd}
The two are the same draw ({opt mobstrata} uses the count the plugin already
computes, with the same missing-value rule: a missing {opt mobility()} value is
not a link). Either way the allocation is proportional {it:with the rounding of}
{cmd:sample}: each class keeps {cmd:int(n*#/100+.5)} units, so a class with few
units can be rounded down to zero. The shares are reproduced closely, not
exactly.

{pstd}
{cmd:movers(100) stayers(}{it:#}{cmd:)} keeps every mover and over-represents
them by design; {opt connected} keeps the largest connected component and
reports what was dropped. Observation-level sampling ({cmd:sample}) and sampling
of the other dimension ({cmd:unit(firm)}) destroy the mobility structure;
{cmd:unit(firm) group(worker)} restores the full histories of every worker
touched by a sampled firm, over-representing movers.


{marker connectivity}{...}
{title:Connectivity}

{pstd}
{opt connectivity} reports the components of the bipartite unit x
{opt mobility()} graph twice: on the {it:eligible frame} (the population being
sampled, before the draw) and on the {it:final sample}.
{cmd:r(N_components_frame)} and {cmd:r(lcc_share_frame)} describe the first,
{cmd:r(N_components)}, {cmd:r(lcc_share)}, {cmd:r(lcc_units_share)} and
{cmd:r(lcc_mobility_share)} the second, and {cmd:r(N_units_lcc_kept)} counts
the retained units that were in the frame's largest component and are still in
the sample's largest one. {opt connected} and {opt reconnect} need the same
graphs and report them too; without one of the three the seven results are
missing and no graph is built, because each one costs a serial union-find over
every frame row.

{pstd}
This matters because keeping whole units preserves the mobility of each unit
without preserving the {it:network}. On a dense graph the sample stays
connected; on a sparse one it shatters. On the {cmd:patents} benchmark
(500,008 rows) the largest component covers 76.0 percent of the frame rows and
only 0.8 percent of the rows of a 10 percent worker sample; on
{cmd:synthetic-assortative}, 69.0 percent against 0.1 percent. Two-way
fixed-effect estimates are only comparable within a component, so a design that
needs the network must say so.

{pstd}
{opt reconnect} does that explicitly. After the draw it adds eligible units
that were {it:not} drawn and that share a mobility value with the current largest
component, one at a time, until the largest component reaches
{cmd:r(lcc_share_frame)} (or the share given in {opt recontarget(#)}), or until
no such unit is left. Each added unit enters with all its rows. The order is
deterministic and does not depend on the row order or on {opt numthreads()}.
{opt reconrule(gain)}, the default, takes the unit that joins the most rows
first, ties broken by the unit's own uniform key and then by its rank;
{opt reconrule(key)} takes the frontier in the order of that key alone, that is
in random order. {cmd:r(N_units_reconnected)} and {cmd:r(N_reconnected)} report
what was added. On the two benchmarks above, {opt reconnect} restores 76.0 and
69.0 percent by adding 5,334 and 7,116 units under {cmd:gain}.

{pstd}
{it:The price is size and composition, and it is large.} The gain rule prefers,
by construction, the units that join the most rows, that is the hubs; the added
units are movers by construction; and there is no bound on how many are needed.
Measured on a 10 percent unit draw ({cmd:absorb(id1 id2)}, {cmd:set seed 1}):

{p2colset 9 42 44 2}{...}
{p2col :{it:patents} (500,008 rows, 101,837 units)}{p_end}
{p2col :  10 percent draw}50,241 rows, 10,184 units, 4.93 mobility values per unit, 92.0 percent movers, largest component 0.8 percent{p_end}
{p2col :  after {cmd:reconnect}}106,639 rows, 15,518 units, 6.87 per unit, 94.7 percent movers, largest component 76.0 percent{p_end}
{p2col :{it:synthetic-assortative} (499,155 rows)}{p_end}
{p2col :  10 percent draw}49,446 rows, 12,610 units, 1.55 per unit, 39.9 percent movers, largest component 0.1 percent{p_end}
{p2col :  after {cmd:reconnect}}101,386 rows, 19,726 units, 1.98 per unit, 60.1 percent movers, largest component 69.0 percent{p_end}
{p2col :{it:enron} (367,662 rows)}{p_end}
{p2col :  10 percent draw}37,595 rows, 3,669 units, 10.25 per unit, largest component 96.2 percent{p_end}
{p2col :  after {cmd:reconnect}}63,462 rows, 3,704 units, 17.13 per unit, largest component 98.4 percent{p_end}
{p2colreset}{...}

{pstd}
In other words, a {it:#} percent request can come back at roughly twice
{it:#} percent of the rows (2.1x on {cmd:patents} and
{cmd:synthetic-assortative}, 1.7x on {cmd:enron} with only 35 units added,
because those 35 are hubs), with a visibly higher mean mobility and mover
share. The population shares of the mobility classes are {it:not} preserved.
{opt recontarget(#)} is the lever: a target below
{cmd:r(lcc_share_frame)} stops the growth earlier and costs less.

{pstd}
{opt reconrule(key)} trades size for composition. Both rules reach the same
target; taking the frontier in key order adds more units, and smaller ones, so
the sample is larger and slower to build but its mean number of mobility values
per unit is much closer to the population. Same three datasets, same 10 percent
draw and the frame share as the target ({cmd:absorb(id1 id2)},
{cmd:set seed 1}, 16 threads):

{p2colset 9 32 34 2}{...}
{p2col :{it:patents} (population 4.910 mobility values per unit, 91.8 percent movers; the 10 percent draw has 50,241 rows, 4.933 and 92.0 percent)}{p_end}
{p2col :  {cmd:reconrule(gain)}}106,639 rows, 15,518 units (+5,334), 6.872 per unit, 94.7 percent movers, 10.5 s{p_end}
{p2col :  {cmd:reconrule(key)}}124,331 rows, 22,304 units (+12,120), 5.574 per unit, 95.1 percent movers, 16.0 s{p_end}
{p2col :{it:synthetic-assortative} (population 1.556 and 40.3 percent; draw 49,446 rows, 1.549 and 39.9 percent)}{p_end}
{p2col :  {cmd:reconrule(gain)}}101,386 rows, 19,726 units (+7,116), 1.981 per unit, 60.1 percent movers, 2.0 s{p_end}
{p2col :  {cmd:reconrule(key)}}114,629 rows, 26,863 units (+14,253), 1.802 per unit, 54.2 percent movers, 4.1 s{p_end}
{p2col :{it:enron} (population 10.020 and 69.4 percent; draw 37,595 rows, 10.247 and 69.0 percent)}{p_end}
{p2col :  {cmd:reconrule(gain)}}63,462 rows, 3,704 units (+35), 17.133 per unit, 69.3 percent movers, 0.2 s{p_end}
{p2col :  {cmd:reconrule(key)}}66,517 rows, 6,241 units (+2,572), 10.658 per unit, 71.1 percent movers, 4.2 s{p_end}
{p2colreset}{...}

{pstd}
{cmd:key} wins on the mean number of mobility values per unit on all three
(most visibly on {cmd:enron}: 10.7 against 17.1, with a population of 10.0) and
on the mover share of {cmd:synthetic-assortative}; {cmd:gain} wins on size
(5 to 17 percent fewer rows), on time (up to 20x on {cmd:enron}) and, slightly,
on the mover share of {cmd:patents} and {cmd:enron}. Because neither dominates,
{cmd:gain} remains the default; choose {cmd:key} when the composition of the
sample matters more than its size.

{pstd}
{opt reconnect} ignores the {opt by()} strata: the frontier is not restricted
to the stratum of the fragment being joined, so after {opt reconnect} the
number of units retained per stratum is no longer {cmd:int(n*#/100+.5)}, and
{cmd:r(N_units_reconnected)} and {cmd:r(N_reconnected)} are totals that are
{it:not} broken down by stratum. The strata themselves are still reported
({cmd:r(N_strata)}, {cmd:r(N_strata_final)}) and the initial draw is still
stratified. {opt connected} is applied after {opt reconnect}, and
{opt reconnect} may not be combined with a {opt group()} closure (groups are
indivisible; adding a unit could split one).


{marker bias}{...}
{title:Limited mobility bias}

{pstd}
Whole-unit sampling keeps the {it:parameters} of the population: the true
variance decomposition of the sample is the population's. It does not keep the
{it:precision} of a two-way fixed-effect estimator. AKM firm effects are
unbiased one by one, but each is estimated with noise, and that noise inflates
{cmd:Var(psi_hat)} and depresses {cmd:Cov(alpha_hat, psi_hat)}: the classic
limited mobility bias (Bonhomme, Lamadon and Manresa, "The ABC of AKM",
{it:Journal of Economic Perspectives}, 2026). Its size is governed by the
number of {it:movers per mobility value}, which is exactly what a sample takes
away, so {opt connectivity} reports that number too:
{cmd:r(movers_per_mob_frame)} and {cmd:r(movers_per_mob)} give the mean over
the mobility values present in the frame and in the sample, and
{cmd:r(weak_mob_share_frame)} and {cmd:r(weak_mob_share)} the share of them
linked to at most one mover. They cost one more pass over the frame rows, so
{opt connected} and {opt reconnect}, which need only the components, do not
compute them; {opt connectivity} and {opt minmovers()} do.

{pstd}
Measured on the calibrated panel of that article (6,000 workers, 300 firms,
5 periods, 30,000 rows), each design estimated on its own connected set:

{p2colset 9 36 38 2}{...}
{p2col :{it:design}}{it:rows, movers per firm, Var(psi) true -> AKM, 2Cov true -> AKM}{p_end}
{p2col :population}30,000 rows, 30.3 movers/firm, Var(psi) 0.096 -> 0.101, 2Cov 0.190 -> 0.182{p_end}
{p2col :25 percent of workers}7,500 rows, 7.7 movers/firm, Var(psi) 0.097 -> 0.116, 2Cov 0.190 -> 0.157{p_end}
{p2col :10 percent of workers}2,925 rows, 3.2 movers/firm, Var(psi) 0.098 -> 0.166, 2Cov 0.196 -> 0.109{p_end}
{p2col :10 percent of rows}1,738 rows, 2.1 movers/firm, Var(psi) 0.087 -> 0.440, 2Cov 0.177 -> -0.338{p_end}
{p2col :{cmd:movers(100) stayers(10)}}19,735 rows, 30.3 movers/firm, Var(psi) 0.089 -> 0.093, 2Cov 0.139 -> 0.133{p_end}
{p2colreset}{...}

{pstd}
Read the table as follows. The {it:true} columns barely move across the unit
designs: the draw is faithful. The {it:AKM} columns do move: the estimated
{cmd:Var(psi)} is 5 percent above the truth on the full data, 20 percent at a
quarter of the workers and 70 percent at a tenth, and drawing the same number
of {it:rows} instead of units multiplies it by five and turns the covariance
negative. Practical consequences:

{p 8 12 2}- for coefficients on covariates, a unit sample is unbiased and only
loses precision (see the Monte Carlo in {cmd:tests/xsamplefe_estimation_cert.do});{p_end}
{p 8 12 2}- for a {it:variance decomposition} meant to be compared with the
full data, sample the movers in full: {cmd:movers(100) stayers(#)} restores the
full-data movers per firm and an essentially unbiased decomposition, of a
{it:different} population (its own {cmd:2Cov} is 0.139 against 0.190);{p_end}
{p 8 12 2}- {opt minmovers(#)} removes the mobility values that carry the most
noise, but it does not remove the bias: on the same panel it takes the share of
firms with at most one mover from 17 percent to zero and leaves the ratio
essentially where it was.{p_end}

{pstd}
{opt minmovers(#)} keeps only the mobility values linked to {it:#} or more
movers. Units are indivisible, so a value that is too weak is removed by
dropping {it:every unit linked to it}, which can turn other units into stayers
and other values weak: the rule is iterated to a fixed point (jointly with
{opt connected} when both are given). {cmd:r(N_units_minmovers_dropped)},
{cmd:r(N_minmovers_dropped)} and {cmd:r(minmovers_iterations)} report the cost.
The pruning {it:cascades}: on a 10 percent unit draw of that panel
{cmd:minmovers(2)} drops 46 of 300 units, while {cmd:minmovers(3)} empties the
sample and says so. Try a small {it:#} first, and prefer
{cmd:movers(100) stayers(#)} when what you need is precision.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}{opt count} specifies that {it:#} is the number of observations (or units)
to draw in each stratum rather than a percentage. Strata with fewer eligible
units are kept in full.

{phang}{opth by(varlist)} draws the sample within each set of values of
{it:varlist} (missing values form their own stratum). With a sampling unit the
variables must be constant within units. {cmd:by} {it:varlist}{cmd::} may be
used instead.

{phang}{opth generate(newvar)} saves a {cmd:byte} indicator equal to 1 for
retained observations (including rows outside {it:if}/{it:in}) and 0 for the
others, without deleting anything. {opt keep(newvar)} is a synonym. {opt replace}
allows {it:newvar} to exist. The name is matched exactly and reserved names
({cmd:_all}, {cmd:_n}, {cmd:_N}, {cmd:_b}, {cmd:_se}, {cmd:_cons}, ...) are
refused: a new name that happens to abbreviate an existing variable creates a
new variable and leaves the existing one alone, and the old variable is only
dropped once the new indicator exists. When the frame is empty (no row selected
by {it:if}/{it:in}, or every {opt unit()} value missing) the indicator is
created all the same, equal to 1 everywhere, and the stored results are
returned with zero counts.

{phang}{opt seed(#)} runs {cmd:set seed} {it:#} before drawing (the previous
state is returned in {cmd:r(rngstate)}).

{dlgtab:Sampling unit}

{phang}{opth absorb(varlist)} lists the fixed effects of the regression the
sample is meant for, in {cmd:reghdfe} syntax: plain variables, {cmd:i.} prefixes,
{cmd:#} interactions (compacted with {cmd:egen group()}), {it:name}{cmd:=}{it:var}
labels and heterogeneous-slope terms ({cmd:fe#c.x}, {cmd:fe##c.(x z)},
{cmd:fe##(c.x c.z)}, whose continuous parts are ignored). Names are expanded to
their full spelling, so an abbreviation picks the same dimensions as the full
name. Anything after a comma is discarded. The first entry is the default
sampling unit and the first other entry, excluding the {opt time()} variable,
is the default {opt mobility()} dimension.

{phang}{opth group(varname)} and {opth individual(varname)} declare a
{cmd:reghdfe, group() individual()} design. {opt group()} becomes the sampling
unit unless {opt unit()} is specified, and its rows are never separated. With
{opt individual()} the mobility dimension defaults to the individual (so
"movers" are groups with two or more members) or, when {cmd:unit(}{it:individual}{cmd:)}
is used, to the group (individuals with two or more groups). {opt i()} is a
synonym of {opt individual()}.

{phang}{opth unit(varname)} sets the sampling unit explicitly. String
identifiers are compacted with {cmd:egen group()} first.

{dlgtab:Panel structure}

{phang}{opth time(varname)} is the period variable used by {opt balanced},
{opt minperiods()} and {opt maxperiods()}; when omitted and needed, the
{helpb xtset} time variable is used.

{phang}{opt balanced} makes only units observed in every distinct period of the
frame eligible; the sample is then a balanced panel.

{phang}{opt minperiods(#)}, {opt maxperiods(#)}, {opt minobs(#)} and
{opt maxobs(#)} bound the number of distinct periods and the number of rows per
unit. {it:#} must be a nonnegative integer; an omitted option is no bound.

{dlgtab:Mobility structure}

{phang}{opth mobility(varname)} is the dimension across which mobility is
measured; a unit is a {it:mover} when it is linked to two or more distinct
values (a worker with two firms, a patent with two inventors).

{phang}{opt minmobility(#)} and {opt maxmobility(#)} bound the number of distinct
{opt mobility()} values per unit: {cmd:minmobility(2)} keeps movers only,
{cmd:minmobility(2) maxmobility(4)} keeps teams of two to four.

{phang}{opt movers(#)} and {opt stayers(#)} set separate percentages (or counts
with {opt count}) for movers and stayers; with {cmd:movers(100) stayers(5)} all
movers and 5 percent of the stayers are drawn.

{phang}{opt connectivity} computes and stores the components of the
unit-mobility graph on the eligible frame and on the final sample, and the
movers per {opt mobility()} value on both; see
{help xsamplefe##connectivity:Connectivity} and
{help xsamplefe##bias:Limited mobility bias}. It is off by default because each
graph costs a serial union-find over every frame row; {opt connected} and
{opt reconnect} build the same graphs and report the components without the
option, but not the movers per value, which cost one further pass.

{phang}{opt mobstrata} adds the number of distinct {opt mobility()} values of
the unit (its mobility class) to the {opt by()} strata, so that the classes are
sampled proportionally; {cmd:r(N_strata_final)} reports the resulting number of
strata. It is the option form of the {cmd:by(nfirms)} recipe in
{help xsamplefe##mobility:Mobility fidelity}.

{phang}{opt connected} keeps only the largest connected component of the
unit-mobility graph of the retained rows.

{phang}{opt minmovers(#)} drops, after the draw, every {opt mobility()} value
linked to fewer than {it:#} movers together with the units linked to it, and
iterates until no such value is left (jointly with {opt connected} when both
are given). It never splits a unit, so the pruning cascades and can empty the
sample; the counts are in {cmd:r(N_units_minmovers_dropped)},
{cmd:r(N_minmovers_dropped)} and {cmd:r(minmovers_iterations)}. It implies the
{opt connectivity} diagnostics and may not be combined with {opt reconnect}
(which grows what it prunes) or with a {opt group()} closure. See
{help xsamplefe##bias:Limited mobility bias}.

{phang}{opt reconnect} and {opt recontarget(#)} add eligible units that were not
drawn until the largest component of the sample covers the share of rows it
covers in the frame, or {it:#} percent of the sample rows with
{opt recontarget(#)} (which implies {opt reconnect}). The retained sample can
end up much larger than {it:#} percent — about twice as large on the
benchmarks — and its mobility composition is not the population's.
{opt reconnect} also {it:ignores the} {opt by()} {it:strata}: the units it adds
are chosen from the whole frontier, whatever their stratum, so the per-stratum
counts stop being {cmd:int(n*#/100+.5)}, and {cmd:r(N_units_reconnected)} and
{cmd:r(N_reconnected)} are totals, not broken down by stratum. See
{help xsamplefe##connectivity:Connectivity} for the rule, the guarantees and
the cost.

{phang}{opt reconrule(gain|key)} chooses which frontier unit {opt reconnect}
adds next: {cmd:gain} (default) the one that joins the most rows to the largest
component, {cmd:key} the one with the smallest uniform key, that is in random
order. {cmd:key} stays closer to the population composition and costs more rows
and more time; see {help xsamplefe##connectivity:Connectivity} for the measured
trade-off. Ties are broken the same way in both cases (the key, then the unit's
rank), so both are deterministic and invariant to {opt numthreads()} and to the
row order. Specifying it implies {opt reconnect}.

{dlgtab:if/in and groups}

{phang}{opt any} and {opt all} resolve units (or groups) that are only partially
selected by {it:if}/{it:in}, as in {cmd:sample2}. Without them such units are
an error.

{phang}{opt grouprule(any|all)} chooses the closure rule of {opt group()} when the
sampling unit is not the group (default {cmd:any}).

{dlgtab:Performance}

{phang}{opt numthreads(#)} requests an OpenMP team of {it:#} threads (capped by
the logical processors visible to the process); 0 uses the runtime default.
{cmd:r(threads_used)} reports the largest team actually formed.

{phang}{opt verbose} prints the elapsed time of every plugin phase.

{phang}{opt pduplicates(#)} is passed to the same rule {helpb sample} uses to
decide how many uniform columns are generated; the default gives two columns
for any realistic sample size under the {cmd:mt64} generator.


{marker examples}{...}
{title:Examples}

{pstd}Same draws as {cmd:sample}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. set seed 1}{p_end}
{phang2}{cmd:. xsamplefe 10, by(foreign)}{p_end}

{pstd}10 percent of the workers, with all their spells, for an AKM regression{p_end}
{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. set seed 1}{p_end}
{phang2}{cmd:. xsamplefe 10, absorb(idcode ind_code year)}{p_end}
{phang2}{cmd:. reghdfe ln_wage tenure, absorb(idcode ind_code year)}{p_end}

{pstd}Balanced panel: 50 percent of the workers observed in every year{p_end}
{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. xsamplefe 50, absorb(idcode year) time(year) balanced generate(insample)}{p_end}

{pstd}All movers and 5 percent of the stayers, restricted to the largest connected component{p_end}
{phang2}{cmd:. xsamplefe 5, absorb(idcode ind_code year) movers(100) stayers(5) connected}{p_end}

{pstd}Patents with several inventors ({cmd:reghdfe, group() individual()}): 20 percent of the patents, whole teams{p_end}
{phang2}{cmd:. use toy-patents-long, clear}{p_end}
{phang2}{cmd:. xsamplefe 20, absorb(inventor_id) group(patent_id) individual(inventor_id)}{p_end}
{phang2}{cmd:. reghdfe citations funding, absorb(inventor_id) group(patent_id) individual(inventor_id)}{p_end}

{pstd}Same design, sampling inventors and keeping every patent they appear in; here the unit is the inventor, so
{opt minmobility()}/{opt maxmobility()} bound the number of {it:patents per inventor}, not the team size (for teams of
2 to 5 sample the patents: {cmd:unit(patent_id) minmobility(2) maxmobility(5)}){p_end}
{phang2}{cmd:. xsamplefe 20, group(patent_id) individual(inventor_id) unit(inventor_id) minmobility(2) maxmobility(5) generate(s)}{p_end}

{pstd}How connected the population is, and how connected a 10 percent worker sample would be{p_end}
{phang2}{cmd:. xsamplefe 10, absorb(worker firm year) connectivity generate(s)}{p_end}

{pstd}A 10 percent worker sample that keeps the largest component as large, in share of its rows, as it is in the
population (and can therefore be much larger than 10 percent){p_end}
{phang2}{cmd:. xsamplefe 10, absorb(worker firm year) reconnect}{p_end}
{phang2}{cmd:. display r(lcc_share_frame), r(lcc_share), r(N_units_reconnected)}{p_end}

{pstd}Worker-firm groups in long format (one row per group member): 10 percent of the firms with all their groups{p_end}
{phang2}{cmd:. xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(ntrab)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:xsamplefe} stores the following in {cmd:r()}:

{synoptset 26 tabbed}{...}
{p2col 5 26 30 2: Scalars}{p_end}
{synopt:{cmd:r(N)}, {cmd:r(N_retained)}}observations retained (including rows outside {it:if}/{it:in}); the two are the same number{p_end}
{synopt:{cmd:r(N_total)}}observations in the dataset{p_end}
{synopt:{cmd:r(N_frame)}}observations in the sampling frame{p_end}
{synopt:{cmd:r(N_outside)}}observations outside the frame (kept){p_end}
{synopt:{cmd:r(N_ineligible)}}frame observations of ineligible units (dropped){p_end}
{synopt:{cmd:r(N_frame_retained)}}frame observations retained{p_end}
{synopt:{cmd:r(N_connected_dropped)}}observations dropped by {opt connected}{p_end}
{synopt:{cmd:r(n_components)}}connected components found by {opt connected}{p_end}
{synopt:{cmd:r(N_units)}}units in the frame (observations when there is no unit){p_end}
{synopt:{cmd:r(N_units_eligible)}, {cmd:r(N_units_ineligible)}}eligible / ineligible units{p_end}
{synopt:{cmd:r(N_units_sampled)}}units drawn{p_end}
{synopt:{cmd:r(N_units_retained)}}units of the frame with at least one retained row (after group closure,
{opt reconnect} and {opt connected}); rows outside {it:if}/{it:in} are kept but their units are not in the frame and
are not counted{p_end}
{synopt:{cmd:r(N_units_partial)}}units with some, but not all, of their frame rows retained (only the group closure can produce these){p_end}
{synopt:{cmd:r(N_units_ineligible_retained)}}ineligible units brought back by the group closure{p_end}
{synopt:{cmd:r(N_movers_eligible)}, {cmd:r(N_movers_sampled)}, {cmd:r(N_movers_retained)}}movers among eligible / drawn / retained units{p_end}
{synopt:{cmd:r(N_units_split)}}units (or groups) split by {it:if}/{it:in} and resolved by {opt any}/{opt all}{p_end}
{synopt:{cmd:r(N_target)}}total number of units targeted by the rates{p_end}
{synopt:{cmd:r(N_strata)}, {cmd:r(N_strata_final)}}{opt by()} strata, and non-empty strata after the mover split{p_end}
{synopt:{cmd:r(N_periods)}}distinct {opt time()} values in the frame{p_end}
{synopt:{cmd:r(N_mobility)}, {cmd:r(N_mobility_retained)}}distinct {opt mobility()} values in the frame / in the retained frame rows{p_end}
{synopt:{cmd:r(N_groups)}, {cmd:r(N_groups_kept)}, {cmd:r(N_groups_retained)}}groups in the frame / kept by the closure rule / with retained rows{p_end}
{synopt:{cmd:r(N_components_frame)}, {cmd:r(lcc_share_frame)}}with {opt connectivity}, {opt connected},
{opt reconnect} or {opt minmovers()}: components of the unit-mobility graph on the eligible frame, and the share of its
rows in the largest one{p_end}
{synopt:{cmd:r(N_components)}, {cmd:r(lcc_share)}}the same on the final sample{p_end}
{synopt:{cmd:r(lcc_units_share)}, {cmd:r(lcc_mobility_share)}}share of the sample's units / {opt mobility()} values in its largest component{p_end}
{synopt:{cmd:r(N_units_lcc_kept)}}retained units that were in the frame's largest component and are in the sample's largest one{p_end}
{synopt:{cmd:r(movers_per_mob_frame)}, {cmd:r(movers_per_mob)}}with {opt connectivity} or {opt minmovers()}: mean number
of movers per {opt mobility()} value, in the frame and in the sample{p_end}
{synopt:{cmd:r(weak_mob_share_frame)}, {cmd:r(weak_mob_share)}}the same for the share of {opt mobility()} values linked
to at most one mover{p_end}
{synopt:{cmd:r(N_units_reconnected)}, {cmd:r(N_reconnected)}}units and observations added by {opt reconnect} (totals,
not broken down by {opt by()} stratum){p_end}
{synopt:{cmd:r(N_units_minmovers_dropped)}, {cmd:r(N_minmovers_dropped)}, {cmd:r(minmovers_iterations)}}units and
observations dropped by {opt minmovers(#)}, and the number of passes it took{p_end}
{synopt:{cmd:r(pct)} or {cmd:r(count)}}the {it:#} specified{p_end}
{synopt:{cmd:r(n_uniforms)}}number of uniform key columns drawn{p_end}
{synopt:{cmd:r(threads_requested)}, {cmd:r(threads_effective)}, {cmd:r(threads_used)}, {cmd:r(thread_capacity)}, {cmd:r(openmp_enabled)}}OpenMP
diagnostics{p_end}

{pstd}
Results that do not apply are missing ({cmd:.}): {cmd:r(N_periods)} without
{opt time()}, the mobility results without a mobility dimension,
{cmd:r(N_groups*)} without {opt group()}, the {opt reconnect} counts without
{opt reconnect}, the {opt minmovers()} counts without {opt minmovers()}, and
the eleven connectivity results ({cmd:r(N_components_frame)},
{cmd:r(lcc_share_frame)}, {cmd:r(N_components)}, {cmd:r(lcc_share)},
{cmd:r(lcc_units_share)}, {cmd:r(lcc_mobility_share)},
{cmd:r(N_units_lcc_kept)}) unless {opt connectivity}, {opt connected},
{opt reconnect} or {opt minmovers()} was specified, and the four
movers-per-value results ({cmd:r(movers_per_mob_frame)},
{cmd:r(movers_per_mob)}, {cmd:r(weak_mob_share_frame)},
{cmd:r(weak_mob_share)}) unless {opt connectivity} or {opt minmovers()} was. Zero
means zero. {cmd:r(n_components)} keeps its own meaning: the components found
by {opt connected}, missing without it.

{p2col 5 26 30 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}{cmd:xsamplefe}{p_end}
{synopt:{cmd:r(unit)}, {cmd:r(mobility)}, {cmd:r(time)}, {cmd:r(by)}, {cmd:r(group)}, {cmd:r(individual)}, {cmd:r(absorb)}}dimensions used{p_end}
{synopt:{cmd:r(frame_rule)}, {cmd:r(grouprule)}, {cmd:r(reconrule)}}{cmd:strict}/{cmd:any}/{cmd:all}, the group closure
rule and the {opt reconnect} frontier rule{p_end}
{synopt:{cmd:r(generate)}}indicator variable, if any{p_end}
{synopt:{cmd:r(rngstate)}}random-number state before drawing{p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}
Miguel Portela, Universidade do Minho / NIPE. Companion of the {helpb xhdfe}
package. Report issues at {browse "https://github.com/reisportela/xsamplefe/issues"}.

{pstd}
{cmd:sample2} is by Jeroen Weesie (STB-37 dm46, 1996); the observation-level
semantics follow StataCorp's {cmd:sample}.
