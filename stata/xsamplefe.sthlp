{smcl}
{* *! version 1.0.0  08sep2026}{...}
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
{synopt :{opth mob:ility(varname)}}dimension across which units move (default: second {opt absorb()} variable, or the {opt individual()}/{opt group()} counterpart){p_end}
{synopt :{opt minm:obility(#)}, {opt maxm:obility(#)}}bounds on the number of distinct {opt mobility()} values per unit{p_end}
{synopt :{opt mov:ers(#)}, {opt stay:ers(#)}}separate sampling rates (or counts) for movers and stayers{p_end}
{synopt :{opt conn:ected}}keep only the largest connected component of the sampled unit-mobility graph{p_end}

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
{p 8 12 2}- mobility structure: bounds on the number of distinct values of a second dimension per unit (firms per worker, inventors per patent, ...), separate rates for movers and stayers, and an optional restriction to the largest connected component;{p_end}
{p 8 12 2}- {cmd:reghdfe, group() individual()} designs (patents-inventors, papers-authors, groups of workers): rows of a group are never separated, whichever unit is sampled.{p_end}

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
{opt time()} or {opt mobility()} values never count as a period or a link.

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
or only when {cmd:all} of them were ({opt grouprule(all)}). The default keeps
the group-level outcome and the full team of every retained group, at the cost
of pulling in individuals that were not drawn; the stored results report both
the drawn and the retained units.

{pstd}
{it:Connected set.} {opt connected} builds the bipartite graph between units
and {opt mobility()} values on the retained frame rows and keeps only its
largest component (measured in rows; ties go to the component containing the
smallest unit value). Rows outside it are dropped after sampling, so the final
sample can be smaller than {it:#} percent; use {helpb xhdfeconnected} for the
leave-one-out connected set of AKM models.


{marker reproducibility}{...}
{title:Reproducibility}

{pstd}
{cmd:xsamplefe} draws its uniform keys with {helpb runiform()}, in the same
order and number as {helpb sample} (one or more {cmd:double} columns over all
observations, see {opt pduplicates()}), and selects the smallest keys within
each stratum. Consequently, after {cmd:set seed} {it:#}:

{p 8 12 2}- {cmd:xsamplefe} {it:#} [{it:if}] [{cmd:, by() count}] retains exactly the observations that {cmd:sample} {it:#} [{it:if}] [{cmd:, by() count}] retains, and leaves the random-number generator in the same state ({cmd:sample 100} and {cmd:count} with {it:#} {ul:>} {cmd:_N} draw nothing in both commands);{p_end}
{p 8 12 2}- unit-level samples depend only on the seed and on the {it:set} of unit values in the frame (the {it:r}-th smallest unit value receives the {it:r}-th draw), so they are invariant to the physical order of the data;{p_end}
{p 8 12 2}- results are invariant to {opt numthreads()}.{p_end}

{pstd}
Note that {cmd:by} {it:varlist}{cmd:, sort:} sorts the data {it:before} the
command runs and Stata's sort orders ties arbitrarily, so neither {cmd:sample}
nor {cmd:xsamplefe} is reproducible under that prefix unless the data were
already sorted ({cmd:sort, stable}) or {opt by()} is used instead.

{pstd}
{cmd:xsamplefe} does not sort the data.


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
allows {it:newvar} to exist.

{phang}{opt seed(#)} runs {cmd:set seed} {it:#} before drawing (the previous
state is returned in {cmd:r(rngstate)}).

{dlgtab:Sampling unit}

{phang}{opth absorb(varlist)} lists the fixed effects of the regression the
sample is meant for, in {cmd:reghdfe} syntax: plain variables, {cmd:i.} prefixes,
{cmd:#} interactions (compacted with {cmd:egen group()}), {it:name}{cmd:=}{it:var}
labels and heterogeneous-slope terms ({cmd:fe#c.x}, whose {cmd:c.} parts are
ignored). The first entry is the default sampling unit and the first other
entry is the default {opt mobility()} dimension.

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
unit.

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

{phang}{opt connected} keeps only the largest connected component of the
unit-mobility graph of the retained rows.

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

{pstd}Same design, sampling inventors and keeping every patent they appear in, teams of 2 to 5 only, stratified by year{p_end}
{phang2}{cmd:. xsamplefe 20, group(patent_id) individual(inventor_id) unit(inventor_id) minmobility(2) maxmobility(5) by(year) generate(s)}{p_end}

{pstd}Worker-firm groups in long format (one row per group member): 10 percent of the firms with all their groups{p_end}
{phang2}{cmd:. xsamplefe 10, absorb(p_ntrab ntrab) group(p_groupid) individual(p_ntrab) unit(ntrab)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:xsamplefe} stores the following in {cmd:r()}:

{synoptset 26 tabbed}{...}
{p2col 5 26 30 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations retained (including rows outside {it:if}/{it:in}){p_end}
{synopt:{cmd:r(N_total)}}observations in the dataset{p_end}
{synopt:{cmd:r(N_frame)}}observations in the sampling frame{p_end}
{synopt:{cmd:r(N_outside)}}observations outside the frame (kept){p_end}
{synopt:{cmd:r(N_ineligible)}}frame observations of ineligible units (dropped){p_end}
{synopt:{cmd:r(N_frame_retained)}}frame observations retained{p_end}
{synopt:{cmd:r(N_connected_dropped)}}observations dropped by {opt connected}{p_end}
{synopt:{cmd:r(n_components)}}connected components found by {opt connected}{p_end}
{synopt:{cmd:r(N_units)}}units in the frame (observations when there is no unit){p_end}
{synopt:{cmd:r(N_units_eligible)}}, {cmd:r(N_units_ineligible)}}eligible / ineligible units{p_end}
{synopt:{cmd:r(N_units_sampled)}}units drawn{p_end}
{synopt:{cmd:r(N_units_retained)}}units with at least one retained row (after group closure and {opt connected}){p_end}
{synopt:{cmd:r(N_movers_eligible)}}, {cmd:r(N_movers_sampled)}, {cmd:r(N_movers_retained)}}movers among eligible / drawn / retained units{p_end}
{synopt:{cmd:r(N_units_split)}}units (or groups) split by {it:if}/{it:in} and resolved by {opt any}/{opt all}{p_end}
{synopt:{cmd:r(N_target)}}total number of units targeted by the rates{p_end}
{synopt:{cmd:r(N_strata)}}, {cmd:r(N_strata_final)}}{opt by()} strata, and non-empty strata after the mover split{p_end}
{synopt:{cmd:r(N_periods)}}distinct {opt time()} values in the frame{p_end}
{synopt:{cmd:r(N_mobility)}}, {cmd:r(N_mobility_retained)}}distinct {opt mobility()} values in the frame / in the sample{p_end}
{synopt:{cmd:r(N_groups)}}, {cmd:r(N_groups_kept)}, {cmd:r(N_groups_retained)}}groups in the frame / kept by the closure rule / with retained rows{p_end}
{synopt:{cmd:r(pct)}} or {cmd:r(count)}}the {it:#} specified{p_end}
{synopt:{cmd:r(n_uniforms)}}number of uniform key columns drawn{p_end}
{synopt:{cmd:r(threads_requested)}}, {cmd:r(threads_effective)}, {cmd:r(threads_used)}, {cmd:r(thread_capacity)}, {cmd:r(openmp_enabled)}}OpenMP diagnostics{p_end}

{p2col 5 26 30 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}{cmd:xsamplefe}{p_end}
{synopt:{cmd:r(unit)}}, {cmd:r(mobility)}, {cmd:r(time)}, {cmd:r(by)}, {cmd:r(group)}, {cmd:r(individual)}, {cmd:r(absorb)}}dimensions used{p_end}
{synopt:{cmd:r(frame_rule)}}, {cmd:r(grouprule)}}{cmd:strict}/{cmd:any}/{cmd:all} and the group closure rule{p_end}
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
