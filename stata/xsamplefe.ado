*! version 1.0.0  08sep2026
*! xsamplefe: panel / fixed-effect aware random sampling for reghdfe and xhdfe
*! - sample / sample2 semantics for the simple cases (drawn rows are
*!   bit-identical to sample under the same seed and data order)
*! - whole-unit sampling aligned with absorb(), group() and individual()
*! - strata, balanced panels, mobility structure and connected sets
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
        MINobs(integer -1) MAXobs(integer -1) ///
        MINPeriods(integer -1) MAXPeriods(integer -1) ///
        MINMobility(integer -1) MAXMobility(integer -1) ///
        MOVers(numlist max=1 >=0) STAYers(numlist max=1 >=0) ///
        ANY ALL GROUPRule(string) ///
        CONNected ///
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
    if (`numthreads' < 0) {
        di as err "numthreads() must be >= 0"
        exit 198
    }
    if ("`any'" != "" & "`all'" != "") {
        di as err "options any and all may not be combined"
        exit 198
    }
    if ("`generate'" != "" & "`keep'" != "") {
        di as err "specify either generate() or keep(), not both"
        exit 198
    }
    if ("`keep'" != "") local generate `keep'
    if ("`generate'" != "" & "`replace'" == "") confirm new variable `generate'
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
    if ("`movers'" != "" | "`stayers'" != "") {
        foreach r in movers stayers {
            if ("``r''" == "") continue
            if (!`is_count' & ``r'' > 100) {
                di as err "`r'() must be a percentage between 0 and 100"
                exit 198
            }
            if (`is_count' & ``r'' != int(``r'')) {
                di as err "`r'() must be an integer count when option count is specified"
                exit 198
            }
        }
    }

    // ---- absorb(): reghdfe-style absvars -> plain sampling dimensions -------
    local absvars
    local absvars_display
    if (`"`absorb'"' != "") {
        local absorb_raw = strtrim(`"`absorb'"')
        gettoken absorb_raw absorb_opts : absorb_raw, parse(",")
        foreach tok of local absorb_raw {
            local tok `tok'
            if (strpos("`tok'", "=")) {
                gettoken lhs tok : tok, parse("=")
                local tok = subinstr("`tok'", "=", "", 1)
            }
            local tok = subinstr("`tok'", "i.", "", .)
            if (strpos("`tok'", "#")) {
                local tok = subinstr("`tok'", "##", "#", .)
                local parts = subinstr("`tok'", "#", " ", .)
                local fevars
                foreach p of local parts {
                    if (substr("`p'", 1, 2) == "c.") continue
                    confirm variable `p'
                    local fevars `fevars' `p'
                }
                if ("`fevars'" == "") continue
                local nfev : word count `fevars'
                if (`nfev' == 1) {
                    local absvars `absvars' `fevars'
                    local absvars_display `absvars_display' `fevars'
                }
                else {
                    tempvar iv
                    quietly egen long `iv' = group(`fevars')
                    local absvars `absvars' `iv'
                    local absvars_display `absvars_display' `tok'
                }
            }
            else {
                confirm variable `tok'
                local absvars `absvars' `tok'
                local absvars_display `absvars_display' `tok'
            }
        }
    }

    // ---- sampling unit, inseparable block, mobility and time dimensions ----
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
                       "`stayers'" != "" | "`connected'" != "")) {
        di as err "{p 0 4}minmobility(), maxmobility(), movers(), stayers() and connected require a mobility dimension: specify mobility(), a second absorb() variable, or group() with individual(){p_end}"
        exit 198
    }

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
    if (`N_frame' == 0) exit

    // ---- uniform keys: same draws (order and count) as sample ---------------
    local rngstate = c(rngstate)
    if ("`seed'" != "") set seed `seed'
    local draw 1
    if ("`movers'" == "" & "`stayers'" == "") {
        if (!`is_count' & `exp' == 100) local draw 0
        if (`is_count' & `exp' >= _N) local draw 0
    }
    local nu 0
    local ulist
    if (`draw') {
        if (!`is_count') local nobs = int(`N_frame' * (`exp') / 100 + .5)
        else local nobs = `exp'
        local d1 32
        if ("`c(rng_current)'" == "mt64") local d1 52
        local d = log(-log1m(`pduplicates'))
        local d = ceil((2 * log(`nobs') - `d') / log(2) - 1)
        local d = ceil(`d' / `d1')
        local nu = max(2, `d')
        forvalues c = 1/`nu' {
            tempvar u`c'
            quietly gen double `u`c'' = runiform()
            local ulist `ulist' `u`c''
        }
    }

    // ---- plugin configuration ------------------------------------------------
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
    local cfg "`cfg'connected=`=("`connected'" != "")';num_threads=`numthreads';"
    local cfg "`cfg'verbose=`=("`verbose'" != "")';s_prefix=__xsf_;"

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
    if (`rc') exit `rc'

    local scalars N_total N_frame N_outside N_ineligible N_frame_retained N_retained ///
        N_connected_dropped n_components U_frame U_eligible U_ineligible U_selected ///
        U_retained U_movers_eligible U_movers_selected U_movers_retained U_split ///
        K_target S_by S_final T_periods M_frame M_retained G_frame G_kept G_retained ///
        threads_requested threads_effective threads_used openmp_enabled thread_capacity
    foreach s of local scalars {
        local `s' = scalar(__xsf_`s')
        capture scalar drop __xsf_`s'
    }

    // ---- apply ----------------------------------------------------------------
    if ("`generate'" != "") {
        capture drop `generate'
        quietly gen byte `generate' = `out'
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
    if (`nby' > 0) {
        di as txt "  strata by(" as res "`by'" as txt "): " as res %8.0fc `S_by' ///
            as txt cond(`S_final' != `S_by', "  (final strata incl. mover class: " + string(`S_final', "%8.0fc") + ")", "")
    }
    if (`has_time') {
        di as txt "  time (" as res "`time'" as txt "): " as res %6.0fc `T_periods' as txt " periods" ///
            as txt cond("`balanced'" != "", "; balanced units only", "") ///
            as txt cond(`minperiods' >= 0, "; min periods " + string(`minperiods'), "") ///
            as txt cond(`maxperiods' >= 0, "; max periods " + string(`maxperiods'), "")
    }
    if (`has_mob') {
        di as txt "  mobility (" as res "`mobility_display'" as txt "): movers eligible " ///
            as res %10.0fc `U_movers_eligible' as txt "  sampled " as res %10.0fc `U_movers_selected' ///
            as txt "  retained " as res %10.0fc `U_movers_retained'
        di as txt "                 values covered " as res %12.0fc `M_retained' ///
            as txt " of " as res %12.0fc `M_frame'
    }
    if (`has_block') {
        di as txt "  group closure (" as res "`block'" as txt ", `grouprule'): groups kept " ///
            as res %12.0fc `G_kept' as txt " of " as res %12.0fc `G_frame'
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
