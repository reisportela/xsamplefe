*! version 1.1.0  08sep2026
*! xsamplefe: panel / fixed-effect aware random sampling for reghdfe and xhdfe
*! - sample / sample2 semantics for the simple cases (drawn rows are
*!   bit-identical to sample under the same seed and data order)
*! - whole-unit sampling aligned with absorb(), group() and individual()
*! - strata, balanced panels, mobility structure and connected sets
*! - connectivity diagnostics (connectivity) and reconnect for the largest
*!   component of the unit-mobility graph
*! - OpenMP C++ plugin (xsamplefe.plugin) with no external dependencies

program define xsamplefe, rclass byable(onecall)
    version 14.0

    local 0 `"=`0'"'
    syntax =/exp [if] [in] [, ///
        Count ///
        BY(varlist) ///
        ABSorb(string asis) ///
        GROUP(varname) ///
        INDividual(varname) I(varname) ///
        UNIT(varname) ///
        MOBility(varname) ///
        TIME(varname) ///
        BALanced ///
        MINObs(numlist max=1 integer >=0) MAXObs(numlist max=1 integer >=0) ///
        MINPeriods(numlist max=1 integer >=0) MAXPeriods(numlist max=1 integer >=0) ///
        MINMobility(numlist max=1 integer >=0) MAXMobility(numlist max=1 integer >=0) ///
        MOVers(numlist max=1 >=0) STAYers(numlist max=1 >=0) ///
        MOBSTRata ///
        ANY ALL GROUPRule(string) ///
        CONNECTIVity CONNected RECONnect RECONTarget(numlist max=1 >=0 <=100) ///
        RECONRule(string) ///
        GENerate(name) KEEP(name) REPLACE ///
        SEED(string) ///
        NUMThreads(integer 0) ///
        PDUPlicates(real 1e-4) ///
        VERBose ]

    if (_by()) {
        if ("`by'" != "") {
            di as err "by varlist: and by() option may not be combined"
            exit 190
        }
        local by `_byvars'
    }

    // an empty numlist limit means "no bound"; -1 is the internal sentinel
    foreach lim in minobs maxobs minperiods maxperiods minmobility maxmobility {
        if ("``lim''" == "") local `lim' -1
    }

    // ---- # : percent (default) or count ------------------------------------
    local exp = strtrim(`"`exp'"')
    confirm number `exp'
    local is_count = ("`count'" != "")
    if (!`is_count') {
        if (`exp' < 0 | `exp' > 100) {
            di as err "{p 0 4}`exp': # must be between 0 and 100 and is interpreted as a percent unless option count is specified, in which case # is the number of observations (or units) to draw{p_end}"
            exit 198
        }
    }
    else {
        confirm integer number `exp'
        if (`exp' < 0) {
            di as err "{p 0 4}`exp': # must be 0 or positive; with option count it is the number of observations (or units) to draw{p_end}"
            exit 198
        }
    }
    if (_N >= 2147483647) {
        di as err "xsamplefe: datasets with 2,147,483,647 or more observations are not supported by the plugin"
        exit 198
    }
    if (`numthreads' < 0) {
        di as err "numthreads() must be >= 0"
        exit 198
    }
    if ("`any'" != "" & "`all'" != "") {
        di as err "options any and all may not be combined"
        exit 198
    }

    // ---- generate()/keep(): reserved names, exact match, no data loss -------
    if ("`generate'" != "" & "`keep'" != "") {
        di as err "specify either generate() or keep(), not both"
        exit 198
    }
    if ("`keep'" != "") local generate `keep'
    local gen_exists 0
    if ("`generate'" != "") {
        capture confirm name `generate'
        if (_rc | inlist("`generate'", "_all", "_se", "_cons", "_skip")) {
            di as err "`generate' is not a valid new variable name"
            exit 198
        }
        capture confirm variable `generate', exact
        local gen_exists = (_rc == 0)
        if (`gen_exists' & "`replace'" == "") {
            di as err "variable `generate' already defined"
            exit 110
        }
    }
    else if ("`replace'" != "") {
        di as txt "note: option replace has no effect without generate() or keep()"
    }

    if ("`i'" != "") {
        if ("`individual'" != "") {
            di as err "specify either i() or individual(), not both"
            exit 198
        }
        local individual `i'
    }
    if ("`individual'" != "" & "`group'" == "") {
        di as err "option individual() requires option group()"
        exit 198
    }
    if ("`individual'" != "" & "`individual'" == "`group'") {
        di as err "group() and individual() must be different variables"
        exit 198
    }
    if ("`grouprule'" != "") {
        local grouprule = lower(strtrim("`grouprule'"))
        if (!inlist("`grouprule'", "any", "all")) {
            di as err "grouprule() must be any or all"
            exit 198
        }
    }
    else local grouprule any
    foreach r in movers stayers {
        if ("``r''" == "") continue
        if (!`is_count' & ``r'' > 100) {
            di as err "`r'() must be a percentage between 0 and 100"
            exit 198
        }
        if (`is_count' & (``r'' != int(``r'') | ``r'' > 2147483647)) {
            di as err "`r'() must be an integer between 0 and 2,147,483,647 when option count is specified"
            exit 198
        }
    }
    if ("`recontarget'" != "" | "`reconrule'" != "") local reconnect reconnect
    if ("`reconrule'" != "") {
        local reconrule = lower(strtrim("`reconrule'"))
        if (!inlist("`reconrule'", "gain", "key")) {
            di as err "reconrule() must be gain or key"
            exit 198
        }
    }
    else local reconrule gain

    // ---- absorb(): reghdfe-style absvars -> plain sampling dimensions -------
    // Terms are split at blanks outside parentheses, so c.(x z) stays together;
    // parenthesised groups and c. parts are continuous slopes and are ignored.
    local absvars
    local absvars_display
    if (`"`absorb'"' != "") {
        local absorb_raw = strtrim(subinstr(`"`absorb'"', char(9), " ", .))
        gettoken absorb_raw absorb_opts : absorb_raw, parse(",")
        local nterm 0
        local depth 0
        local cur
        forvalues j = 1/`=length("`absorb_raw'")' {
            local ch = substr("`absorb_raw'", `j', 1)
            if ("`ch'" == "(") local ++depth
            if ("`ch'" == ")") local --depth
            if ("`ch'" == " " & `depth' == 0) {
                if ("`cur'" != "") {
                    local ++nterm
                    local term`nterm' `cur'
                }
                local cur
            }
            else local cur `cur'`ch'
        }
        if ("`cur'" != "") {
            local ++nterm
            local term`nterm' `cur'
        }
        forvalues t = 1/`nterm' {
            local tok `term`t''
            if (strpos("`tok'", "=")) {
                gettoken lhs tok : tok, parse("=")
                local tok = subinstr("`tok'", "=", "", 1)
            }
            while (strpos("`tok'", "(")) {
                local p = strpos("`tok'", "(")
                local q = strpos("`tok'", ")")
                if (`q' < `p') {
                    di as err "absorb(): unbalanced parentheses in `term`t''"
                    exit 198
                }
                local tok = substr("`tok'", 1, `p' - 1) + substr("`tok'", `q' + 1, .)
            }
            local tok = subinstr("`tok'", "i.", "", .)
            local tok = subinstr("`tok'", "##", "#", .)
            local parts = subinstr("`tok'", "#", " ", .)
            local fevars
            foreach p of local parts {
                if (substr("`p'", 1, 2) == "c.") continue
                unab p : `p'
                local fevars `fevars' `p'
            }
            local nfev : word count `fevars'
            if (`nfev' == 0) continue
            if (`nfev' == 1) {
                local absvars `absvars' `fevars'
                local absvars_display `absvars_display' `fevars'
            }
            else {
                tempvar iv
                quietly egen long `iv' = group(`fevars')
                local absvars `absvars' `iv'
                local dsp : subinstr local fevars " " "#", all
                local absvars_display `absvars_display' `dsp'
            }
        }
    }

    // ---- sampling unit and inseparable block --------------------------------
    local unit_display
    if ("`unit'" != "") {
        local unit_display `unit'
    }
    else if ("`group'" != "") {
        local unit `group'
        local unit_display `group'
    }
    else if ("`absvars'" != "") {
        local unit : word 1 of `absvars'
        local unit_display : word 1 of `absvars_display'
    }
    local has_unit = ("`unit'" != "")

    local block
    if ("`group'" != "" & "`group'" != "`unit'") local block `group'
    local has_block = ("`block'" != "")

    // ---- time (resolved before the mobility default) ------------------------
    local need_time = ("`balanced'" != "" | `minperiods' >= 0 | `maxperiods' >= 0)
    if ("`time'" == "" & `need_time') {
        capture quietly xtset
        if (!_rc) local time `r(timevar)'
        if ("`time'" == "") {
            di as err "balanced, minperiods() and maxperiods() require time() or an xtset time variable"
            exit 198
        }
    }
    if ("`time'" != "" & !`has_unit') {
        di as err "time() requires a sampling unit: specify unit(), absorb() or group()"
        exit 198
    }
    local has_time = ("`time'" != "")

    // ---- mobility dimension (never the time variable) -----------------------
    if ("`mobility'" == "" & `has_unit') {
        if ("`group'" != "" & "`individual'" != "") {
            if ("`unit'" == "`group'") local mobility `individual'
            else if ("`unit'" == "`individual'") local mobility `group'
        }
        if ("`mobility'" == "") {
            local k 0
            foreach v of local absvars {
                local ++k
                if ("`v'" != "`unit'" & "`v'" != "`time'" & "`mobility'" == "") {
                    local mobility `v'
                    local mobility_display : word `k' of `absvars_display'
                }
            }
        }
        if ("`mobility'" == "" & "`group'" != "" & "`individual'" != "") local mobility `individual'
    }
    if ("`mobility_display'" == "") local mobility_display `mobility'
    if ("`mobility'" != "" & !`has_unit') {
        di as err "mobility() requires a sampling unit: specify unit(), absorb() or group()"
        exit 198
    }
    if ("`mobility'" != "" & "`mobility'" == "`unit'") {
        di as err "mobility() must differ from the sampling unit (`unit_display')"
        exit 198
    }
    local has_mob = ("`mobility'" != "")
    if (!`has_mob' & (`minmobility' >= 0 | `maxmobility' >= 0 | "`movers'" != "" | ///
                       "`stayers'" != "" | "`connected'" != "" | "`reconnect'" != "" | ///
                       "`mobstrata'" != "" | "`connectivity'" != "")) {
        di as err "{p 0 4}minmobility(), maxmobility(), movers(), stayers(), mobstrata, connectivity, connected and reconnect require a mobility dimension: specify mobility(), a second absorb() variable, or group() with individual(){p_end}"
        exit 198
    }
    if ("`reconnect'" != "" & `has_block') {
        di as err "{p 0 4}reconnect may not be combined with a group() closure (group() different from the sampling unit): groups are indivisible and reconnect adds whole units{p_end}"
        exit 198
    }
    local recon_target -1
    if ("`recontarget'" != "") local recon_target `recontarget'
    // the connectivity diagnostics cost a union-find over the frame rows: they
    // are computed only when asked for, or when an option needs them
    local has_diag = ("`connectivity'`connected'`reconnect'" != "" & `has_mob')

    local frame_rule strict
    if ("`any'`all'" != "") {
        if (!`has_unit') {
            di as txt "note: option `any'`all' ignored (no sampling unit)"
        }
        else local frame_rule `any'`all'
    }

    // ---- string identifiers -> compact numeric codes -------------------------
    foreach m in unit time mobility block {
        local `m'_use ``m''
        if ("``m''" == "") continue
        capture confirm numeric variable ``m''
        if (_rc) {
            tempvar num_`m'
            quietly egen long `num_`m'' = group(``m'')
            local `m'_use `num_`m''
        }
    }
    local by_use
    foreach v of local by {
        capture confirm numeric variable `v'
        if (_rc) {
            tempvar nb
            quietly egen long `nb' = group(`v')
            local by_use `by_use' `nb'
        }
        else local by_use `by_use' `v'
    }
    local nby : word count `by_use'

    // ---- sampling frame ------------------------------------------------------
    marksample touse
    markout `touse' `unit_use' `block_use'
    quietly count if `touse'
    local N_frame = r(N)

    // ---- uniform keys: same draws (order and count) as sample ---------------
    local rngstate = c(rngstate)
    if ("`seed'" != "") set seed `seed'
    local draw 1
    if (`N_frame' == 0) local draw 0
    else if ("`movers'" == "" & "`stayers'" == "") {
        if (!`is_count' & `exp' == 100) local draw 0
        if (`is_count' & `exp' >= _N) local draw 0
    }
    local nu 0
    local ulist
    if (`draw') {
        if (!`is_count') local nobs = int(`N_frame' * (`exp') / 100 + .5)
        else local nobs = `exp'
        local utype double
        if (!`has_unit' & c(userversion) < 14 & _N < 2^31) {
            // sample uses two float columns under user version < 14
            local nu 2
            local utype float
        }
        else {
            local d1 32
            if ("`c(rng_current)'" == "mt64") local d1 52
            local d = log(-log1m(`pduplicates'))
            local d = ceil((2 * log(`nobs') - `d') / log(2) - 1)
            local d = ceil(`d' / `d1')
            local nu = max(2, `d')
        }
        forvalues c = 1/`nu' {
            tempvar u`c'
            quietly gen `utype' `u`c'' = runiform()
            local ulist `ulist' `u`c''
        }
    }

    // ---- plugin configuration ------------------------------------------------
    tempname pfx
    local sp `pfx'_
    local cfg "cfg=is_count=`is_count';"
    if (`is_count') local cfg "`cfg'count=`exp';"
    else local cfg "`cfg'pct=`exp';"
    local cfg "`cfg'has_unit=`has_unit';nby=`nby';has_time=`has_time';has_mob=`has_mob';"
    local cfg "`cfg'has_group=`has_block';nu=`nu';frame_rule=`frame_rule';group_rule=`grouprule';"
    local cfg "`cfg'balanced=`=("`balanced'" != "")';minobs=`minobs';maxobs=`maxobs';"
    local cfg "`cfg'minperiods=`minperiods';maxperiods=`maxperiods';"
    local cfg "`cfg'minmob=`minmobility';maxmob=`maxmobility';"
    if ("`movers'" != "") local cfg "`cfg'rate_movers=`movers';"
    if ("`stayers'" != "") local cfg "`cfg'rate_stayers=`stayers';"
    local cfg "`cfg'mobstrata=`=("`mobstrata'" != "")';connectivity=`=("`connectivity'" != "")';"
    local cfg "`cfg'reconnect=`=("`reconnect'" != "")';recon_target=`recon_target';recon_rule=`reconrule';"
    local cfg "`cfg'connected=`=("`connected'" != "")';num_threads=`numthreads';"
    local cfg "`cfg'verbose=`=("`verbose'" != "")';s_prefix=`sp';"

    tempvar out
    quietly gen byte `out' = .

    // ---- bind the plugin next to the active xsamplefe.ado --------------------
    quietly findfile xsamplefe.ado
    local plugin_path "`r(fn)'"
    local plugin_path : subinstr local plugin_path "xsamplefe.ado" "xsamplefe.plugin", all
    if (substr(`"`plugin_path'"', 1, 1) == "~") {
        local __plugin_home : env HOME
        if (`"`__plugin_home'"' != "") {
            local plugin_path : subinstr local plugin_path "~" `"`__plugin_home'"'
        }
    }
    capture confirm file "`plugin_path'"
    if (_rc) {
        di as err "xsamplefe.plugin not found next to xsamplefe.ado; build it with stata/tools/build-xsamplefe-plugin.sh"
        exit _rc
    }
    local plugin_prog "__xsamplefe_plugin"
    if ("$XSAMPLEFE_PLUGIN_PATH_INTERNAL" != "" & "$XSAMPLEFE_PLUGIN_PATH_INTERNAL" != "`plugin_path'") {
        di as err "xsamplefe: the active session is still bound to an older xsamplefe.plugin path"
        di as err "xsamplefe: run discard (with no arguments) and rerun the command"
        exit 498
    }
    capture program `plugin_prog', plugin using("`plugin_path'")
    if (_rc & _rc != 110) {
        di as err "xsamplefe.plugin could not be loaded from `plugin_path'"
        exit _rc
    }
    global XSAMPLEFE_PLUGIN_PATH_INTERNAL "`plugin_path'"

    capture noisily plugin call `plugin_prog' `touse' `unit_use' `by_use' `time_use' ///
        `mobility_use' `block_use' `ulist' `out', "`cfg'"
    local rc = _rc

    local scalars N_total N_frame N_outside N_ineligible N_frame_retained N_retained ///
        N_connected_dropped n_components U_frame U_eligible U_ineligible U_selected ///
        U_retained U_movers_eligible U_movers_selected U_movers_retained U_split ///
        U_partial U_inelig_ret K_target S_by S_final T_periods M_frame M_retained ///
        G_frame G_kept G_retained C_frame LCC_frame_share C_sample LCC_share ///
        LCC_units_share LCC_mob_share U_lcc_kept U_reconnected N_reconnected ///
        threads_requested threads_effective threads_used openmp_enabled thread_capacity
    if (`rc') {
        foreach s of local scalars {
            capture scalar drop `sp'`s'
        }
        exit `rc'
    }
    foreach s of local scalars {
        local `s' = scalar(`sp'`s')
        capture scalar drop `sp'`s'
    }
    // with group() equal to the sampling unit there is no closure to apply, but
    // the group counts are the unit counts and are reported all the same
    if ("`group'" != "" & !`has_block') {
        local G_frame = `U_frame'
        local G_kept = `U_selected'
        local G_retained = `U_retained'
    }

    // ---- apply ----------------------------------------------------------------
    if ("`generate'" != "") {
        tempvar gflag
        quietly gen byte `gflag' = `out'
        if (`gen_exists') drop `generate'
        rename `gflag' `generate'
        label variable `generate' "xsamplefe: 1 = retained in sample"
    }
    else {
        quietly drop if `out' == 0
    }

    // ---- report ---------------------------------------------------------------
    if (`is_count') local what "random sample of `exp' `=cond(`has_unit', "unit(s)", "observation(s)")'`=cond(`nby' > 0, " per stratum", "")'"
    else local what "`exp' percent random sample of `=cond(`has_unit', "units", "observations")'"
    di as txt ""
    if (`has_unit') {
        di as txt "xsamplefe: " as res "`what'" ///
            as txt "   (unit: " as res "`unit_display'" as txt ")"
        di as txt "  units          frame " as res %12.0fc `U_frame' ///
            as txt "  eligible " as res %12.0fc `U_eligible' ///
            as txt "  sampled " as res %12.0fc `U_selected' ///
            as txt "  retained " as res %12.0fc `U_retained'
    }
    else {
        di as txt "xsamplefe: " as res "`what'"
    }
    di as txt "  observations   frame " as res %12.0fc `N_frame' ///
        as txt "  retained " as res %12.0fc `N_frame_retained' ///
        as txt "  outside if/in " as res %10.0fc `N_outside' ///
        as txt "  ineligible " as res %10.0fc `N_ineligible'
    if (`nby' > 0 | "`mobstrata'" != "") {
        local strata_lbl "by(`by')"
        if ("`mobstrata'" != "") local strata_lbl "`strata_lbl' x mobility class"
        di as txt "  strata " as res "`strata_lbl'" as txt ": " as res %8.0fc `S_by' ///
            as txt cond(`S_final' != `S_by', "  (final strata: " + string(`S_final', "%8.0fc") + ")", "")
    }
    if (`has_time') {
        di as txt "  time (" as res "`time'" as txt "): " as res %6.0fc `T_periods' as txt " periods" ///
            as txt cond("`balanced'" != "", "; balanced units only", "") ///
            as txt cond(`minperiods' >= 0, "; min periods " + string(`minperiods'), "") ///
            as txt cond(`maxperiods' >= 0, "; max periods " + string(`maxperiods'), "")
        if ("`balanced'" != "" & `T_periods' == 0) {
            di as txt "note: no unit is eligible: the frame has no non-missing `time' value"
        }
    }
    if (`has_mob') {
        di as txt "  mobility (" as res "`mobility_display'" as txt "): movers eligible " ///
            as res %10.0fc `U_movers_eligible' as txt "  sampled " as res %10.0fc `U_movers_selected' ///
            as txt "  retained " as res %10.0fc `U_movers_retained'
        di as txt "                 values covered " as res %12.0fc `M_retained' ///
            as txt " of " as res %12.0fc `M_frame'
    }
    if (`has_diag') {
        di as txt "  connectivity: frame " as res %8.0fc `C_frame' as txt " component(s), largest " ///
            as res %5.1f 100 * `LCC_frame_share' as txt "% of rows; sample " as res %8.0fc `C_sample' ///
            as txt " component(s), largest " as res %5.1f 100 * `LCC_share' as txt "% of rows"
    }
    if (`has_block') {
        di as txt "  group closure (" as res "`block'" as txt ", `grouprule'): groups kept " ///
            as res %12.0fc `G_kept' as txt " of " as res %12.0fc `G_frame'
    }
    if ("`reconnect'" != "") {
        di as txt "  reconnect (" as res "`reconrule'" as txt "): " as res %12.0fc `U_reconnected' as txt " unit(s) added (" ///
            as res %12.0fc `N_reconnected' as txt " observations) to reach a largest component of " ///
            as res %5.1f 100 * `LCC_share' as txt "% of the sample rows"
    }
    if ("`connected'" != "") {
        di as txt "  connected set: " as res %6.0fc `n_components' as txt " component(s); " ///
            as res %12.0fc `N_connected_dropped' as txt " obs dropped outside the largest"
    }
    if ("`generate'" != "") {
        di as txt "  indicator saved in " as res "`generate'" as txt " (1 = retained); no observations dropped"
    }
    else {
        di as txt "  (" as res %12.0fc `N_total' - `N_retained' as txt " observations deleted)"
    }

    // ---- stored results -------------------------------------------------------
    return scalar N = `N_retained'
    return scalar N_total = `N_total'
    return scalar N_frame = `N_frame'
    return scalar N_outside = `N_outside'
    return scalar N_ineligible = `N_ineligible'
    return scalar N_frame_retained = `N_frame_retained'
    return scalar N_retained = `N_retained'
    return scalar N_connected_dropped = `N_connected_dropped'
    return scalar n_components = `n_components'
    return scalar N_units = `U_frame'
    return scalar N_units_eligible = `U_eligible'
    return scalar N_units_ineligible = `U_ineligible'
    return scalar N_units_sampled = `U_selected'
    return scalar N_units_retained = `U_retained'
    return scalar N_units_partial = `U_partial'
    return scalar N_units_ineligible_retained = `U_inelig_ret'
    return scalar N_movers_eligible = `U_movers_eligible'
    return scalar N_movers_sampled = `U_movers_selected'
    return scalar N_movers_retained = `U_movers_retained'
    return scalar N_units_split = `U_split'
    return scalar N_target = `K_target'
    return scalar N_strata = `S_by'
    return scalar N_strata_final = `S_final'
    return scalar N_periods = `T_periods'
    return scalar N_mobility = `M_frame'
    return scalar N_mobility_retained = `M_retained'
    return scalar N_groups = `G_frame'
    return scalar N_groups_kept = `G_kept'
    return scalar N_groups_retained = `G_retained'
    return scalar N_components_frame = `C_frame'
    return scalar lcc_share_frame = `LCC_frame_share'
    return scalar N_components = `C_sample'
    return scalar lcc_share = `LCC_share'
    return scalar lcc_units_share = `LCC_units_share'
    return scalar lcc_mobility_share = `LCC_mob_share'
    return scalar N_units_lcc_kept = `U_lcc_kept'
    return scalar N_units_reconnected = `U_reconnected'
    return scalar N_reconnected = `N_reconnected'
    return scalar threads_requested = `threads_requested'
    return scalar threads_effective = `threads_effective'
    return scalar threads_used = `threads_used'
    return scalar thread_capacity = `thread_capacity'
    return scalar openmp_enabled = `openmp_enabled'
    if (`is_count') return scalar count = `exp'
    else return scalar pct = `exp'
    return scalar n_uniforms = `nu'
    return local rngstate `"`rngstate'"'
    return local frame_rule "`frame_rule'"
    return local grouprule "`grouprule'"
    return local reconrule "`reconrule'"
    return local generate "`generate'"
    return local by "`by'"
    return local time "`time'"
    return local mobility "`mobility_display'"
    return local group "`group'"
    return local individual "`individual'"
    return local absorb "`absvars_display'"
    return local unit "`unit_display'"
    return local cmd "xsamplefe"
end
