"""Random unit-level designs for the differential test: data, Stata commands, oracle designs.

Writes cases.csv (the rows of every case), cases.json (command and design of
every case) and run.do (the Stata driver) in the output directory.
"""
import argparse
import json
import os
import random

MISSING_CODES = {".": -99001, ".a": -99002, ".b": -99003}  # by() values written as numbers
PERCENTAGES = ["0", "100", "50", "10", "29", "33.3", "12.5", "75", "5", "99", "58", "0.5",
               "66.66666666666667"]
RESULTS = ["N", "N_total", "N_frame", "N_outside", "N_ineligible", "N_frame_retained", "N_retained",
           "N_connected_dropped", "n_components", "N_units", "N_units_eligible", "N_units_ineligible",
           "N_units_sampled", "N_units_retained", "N_units_partial", "N_units_ineligible_retained",
           "N_movers_eligible", "N_movers_sampled", "N_movers_retained", "N_units_split", "N_target",
           "N_strata", "N_strata_final", "N_periods", "N_mobility", "N_mobility_retained", "N_groups",
           "N_groups_kept", "N_groups_retained", "N_components_frame", "lcc_share_frame", "N_components",
           "lcc_share", "lcc_units_share", "lcc_mobility_share", "N_units_lcc_kept", "movers_per_mob_frame",
           "movers_per_mob", "weak_mob_share_frame", "weak_mob_share", "N_units_reconnected", "N_reconnected",
           "N_units_minmovers_dropped", "N_minmovers_dropped", "minmovers_iterations"]


def one_case(k, rng, focus):
    """The rows, the command and the design of case k."""
    style = rng.choices(["A", "B", "C", "D", "E"], weights=[45, 20, 12, 18, 5])[0]
    n_units = rng.randint(1, 40)
    if focus in ("reconnect", "prune"):
        style = rng.choice(["A", "B", "C"])
        n_units = rng.randint(20, 160)
    if focus == "closure":
        style = rng.choice(["A", "D"])
        n_units = rng.randint(5, 60)
    n_mob = rng.randint(1, max(1, int(n_units * rng.choice([0.3, 0.6, 1.0, 1.5]))))
    n_grp = rng.randint(1, max(1, n_units // 2 + 1))
    string_unit = style == "A" and rng.random() < 0.2
    kind = rng.choice(["int", "int", "int", "neg", "frac", "big"])
    ids = rng.sample(range(1, 100000), n_units)

    def unit_value(j):
        if kind == "neg":
            return ids[j] - 50000
        if kind == "frac":
            return ids[j] + 0.5
        if kind == "big":
            return 4503599627370496 + ids[j]  # 2^52 + id, exact in a double
        return ids[j]

    data = []
    for j in range(n_units):
        home = rng.randrange(n_mob)
        b1 = rng.choice([1, 2, 3, ".", ".a"])
        b2 = rng.choice(["x", "y", ""])
        inside = rng.random() < 0.8
        for _ in range(rng.randint(1, 6)):
            data.append(dict(uj=j, m=home if rng.random() < 0.6 else rng.randrange(n_mob),
                             t=rng.randint(1, 5), g=rng.randrange(n_grp), b1=b1, b2=b2,
                             w=rng.randint(1, 4), tu=inside))
    if rng.random() < 0.04 and data:
        data[rng.randrange(len(data))]["b1"] = 7  # a by() value that varies within a unit
    for r in data:
        if rng.random() < (0.004 if focus != "mixed" else 0.04):
            r["uj"] = None
        if rng.random() < 0.06:
            r["m"] = None
        if rng.random() < 0.06:
            r["t"] = None
        if rng.random() < 0.03:
            r["g"] = None
    rng.shuffle(data)
    n = len(data)

    # ---- if / in
    qual = rng.choices(["none", "unit", "group", "row", "in"], weights=[50, 15, 8, 17, 10])[0]
    if focus != "mixed":
        qual = rng.choices(["none", "unit", "group"], weights=[70, 15, 15])[0]
        if focus != "closure" and qual == "group":
            qual = "none"
    group_inside = {g: rng.random() < 0.8 for g in range(n_grp)}
    in_a = rng.randint(1, n)
    in_b = rng.randint(in_a, n)
    for i, r in enumerate(data):
        if qual == "none":
            r["t0"] = 1
        elif qual == "unit":
            r["t0"] = 1 if r["tu"] else 0
        elif qual == "group":
            r["t0"] = 1 if (r["g"] is None or group_inside[r["g"]]) else 0
        elif qual == "row":
            r["t0"] = 1 if rng.random() < 0.85 else 0
        else:
            r["t0"] = 1 if in_a <= i + 1 <= in_b else 0
    frame_rule = rng.choices(["strict", "any", "all"], weights=[40, 30, 30])[0]

    # ---- sampling unit, mobility, time and group
    cfg = dict(nby=0, frame_rule=frame_rule)
    opts = []
    has_time = has_mob = has_group = False
    unit_col, mob_col, grp_col = "u", "m", None
    if style == "A":
        opts.append("unit(us)" if string_unit else "unit(u)")
        if rng.random() < 0.8:
            opts.append("mobility(m)")
            has_mob = True
        if rng.random() < 0.5:
            opts.append("time(t)")
            has_time = True
        if (rng.random() < 0.25 and focus not in ("reconnect", "prune")) or focus == "closure":
            opts.append("group(g)")
            has_group = True
            grp_col = "g"
    elif style == "B":
        opts.append(rng.choice(["absorb(u m t)", "absorb(u m)", "absorb(i.u m, savefe)",
                                "absorb(fe1=u fe2=m)", "absorb(u##c.x m)", "absorb(u m#c.(x z))"]))
        has_mob = True
        if rng.random() < 0.5:
            opts.append("time(t)")
            has_time = True
    elif style == "C":
        opts.append("group(g) individual(u)")
        unit_col, mob_col = "g", "u"
        has_mob = True
        cfg["group_is_unit"] = True
        if rng.random() < 0.3:
            opts.append("time(t)")
            has_time = True
    elif style == "D":
        opts.append("group(g) individual(u) unit(u)")
        unit_col, mob_col, grp_col = "u", "g", "g"
        has_mob = has_group = True
    else:
        opts.append("absorb(u#b1 m)")
        unit_col = "u#b1"
        has_mob = True
    cfg.update(has_time=has_time, has_mob=has_mob, has_group=has_group)

    # ---- # and the strata
    is_count = rng.random() < 0.3
    cfg["is_count"] = is_count
    if is_count:
        num = str(rng.randint(0, n_units + 3))
        if focus != "mixed":
            num = str(rng.randint(1, max(1, n_units // 2)))
        cfg["count"] = int(num)
        opts.append("count")
    else:
        num = rng.choice(PERCENTAGES)
        if focus == "reconnect":
            num = rng.choice(["5", "10", "20", "29", "33.3", "12.5"])
        if focus in ("prune", "closure"):
            num = rng.choice(["20", "33.3", "50", "75", "58", "66.66666666666667"])
        cfg["pct"] = float(num)
    by_vars = []
    if style != "E" and unit_col != "g" and rng.random() < 0.35:
        by_vars = rng.choice([["b1"], ["b2"], ["b1", "b2"], ["b2", "b1"]])
    if by_vars:
        opts.append("by(" + " ".join(by_vars) + ")")
    cfg["nby"] = len(by_vars)
    cfg["by_vars"] = by_vars

    # ---- eligibility
    if rng.random() < 0.2:
        cfg["minobs"] = rng.randint(0, 5)
        opts.append(f"minobs({cfg['minobs']})")
    if rng.random() < 0.15:
        cfg["maxobs"] = rng.randint(1, 8)
        opts.append(f"maxobs({cfg['maxobs']})")
    if has_time:
        if rng.random() < 0.2:
            cfg["balanced"] = True
            opts.append("balanced")
        if rng.random() < 0.2:
            cfg["minperiods"] = rng.randint(0, 4)
            opts.append(f"minperiods({cfg['minperiods']})")
        if rng.random() < 0.1:
            cfg["maxperiods"] = rng.randint(1, 5)
            opts.append(f"maxperiods({cfg['maxperiods']})")

    # ---- mobility structure and retention rules
    if has_mob:
        if rng.random() < 0.15:
            cfg["minmob"] = rng.randint(0, 3)
            opts.append(f"minmobility({cfg['minmob']})")
        if rng.random() < 0.1:
            cfg["maxmob"] = rng.randint(1, 4)
            opts.append(f"maxmobility({cfg['maxmob']})")
        for name, option in (("rate_movers", "movers"), ("rate_stayers", "stayers")):
            if rng.random() < 0.2:
                v = str(rng.randint(0, 6)) if is_count else rng.choice(PERCENTAGES)
                cfg[name] = float(v)
                opts.append(f"{option}({v})")
        if rng.random() < 0.15:
            cfg["mobstrata"] = True
            opts.append("mobstrata")
        if rng.random() < 0.25:
            cfg["connectivity"] = True
            opts.append("connectivity")
        if rng.random() < 0.3 or (focus == "prune" and rng.random() < 0.6):
            cfg["connected"] = True
            opts.append("connected")
        pruned = False
        if not has_group and focus != "reconnect" and (rng.random() < 0.25 or focus == "prune"):
            cfg["minmovers"] = rng.randint(1, 3) if focus == "prune" else rng.randint(0, 3)
            opts.append(f"minmovers({cfg['minmovers']})")
            pruned = True
        if not has_group and not pruned and (rng.random() < 0.35 or focus == "reconnect"):
            cfg["reconnect"] = True
            form = rng.choice(["reconnect", "target", "rule", "both"])
            if form == "reconnect":
                opts.append("reconnect")
            if form in ("target", "both"):
                t = rng.choice(["0", "100", "50", "56", "33.3", "80", "12.5", "99", "70", "25"])
                cfg["recon_target"] = float(t)
                opts.append(f"recontarget({t})")
            if form in ("rule", "both"):
                cfg["recon_rule"] = rng.choice(["gain", "key"])
                opts.append(f"reconrule({cfg['recon_rule']})")
    if has_group:
        rule = rng.choice(["any", "all", None])
        if rule:
            cfg["group_rule"] = rule
            opts.append(f"grouprule({rule})")
    if frame_rule != "strict":
        opts.append(frame_rule)
    cfg["has_weight"] = rng.random() < 0.25
    threads = rng.choice([None, None, 1, 2, 3, 8, 48])
    if threads is not None:
        opts.append(f"numthreads({threads})")

    qualifier = "" if qual == "none" else (f" in {in_a}/{in_b}" if qual == "in" else " if t0 == 1")
    weight = " [fw=w]" if cfg["has_weight"] else ""
    case = dict(case=k, cmd=f"{num}{qualifier}{weight}, " + " ".join(opts), seed=rng.randint(1, 10 ** 6),
                cfg=cfg, unit_col=unit_col, mob_col=mob_col, grp_col=grp_col, string_unit=string_unit,
                qual=qual, style=style)
    rows = []
    for i, r in enumerate(data):
        u = None if r["uj"] is None else unit_value(r["uj"])
        rows.append(dict(case=k, rowid=i + 1, u="" if u is None else repr(u),
                         us="" if r["uj"] is None else "w%07d" % ids[r["uj"]],
                         m="" if r["m"] is None else r["m"] + 1, t="" if r["t"] is None else r["t"],
                         g="" if r["g"] is None else r["g"] + 1, b1=MISSING_CODES.get(r["b1"], r["b1"]),
                         b2=r["b2"], w=r["w"], t0=r["t0"], x=round(rng.random(), 6), z=round(rng.random(), 6)))
    return case, rows


def driver(cases, out, adopath):
    """The do-file: every case in its own frame, the indicator and the keys exported as text."""
    lines = [
        "clear all", "set more off", "set linesize 255", f'adopath ++ "{adopath}"', "which xsamplefe",
        f'import delimited using "{out}/cases.csv", clear stringcols(4 9) asdouble',
        "replace b1 = .  if b1 == -99001", "replace b1 = .a if b1 == -99002",
        "replace b1 = .b if b1 == -99003", "compress", "frame rename default all", "tempname fh",
        f'file open `fh\' using "{out}/results.tsv", write replace text',
        'file write `fh\' "case" _tab "rc" _tab "rngsame" ' + " ".join(f'_tab "{r}"' for r in RESULTS) + " _n",
    ]
    for c in cases:
        k = c["case"]
        lines += [
            "", f"* ---- case {k}", "frame change all", "capture frame drop work",
            f"frame put if case == {k}, into(work)", "frame change work", "sort rowid",
            # the first key column the ado draws: the first _N uniforms after set seed
            f"set seed {c['seed']}", "gen double __u1 = runiform()", f"set seed {c['seed']}",
            "local s0 = c(rngstate)", f"capture noisily xsamplefe {c['cmd']} generate(__s)", "local rc = _rc",
            'local same = (`"`c(rngstate)\'"\' == `"`s0\'"\')',
            f'file write `fh\' "{k}" _tab "`rc\'" _tab "`same\'"',
            "foreach r in " + " ".join(RESULTS) + " {",
            "    if (`rc' == 0) file write `fh' _tab %24.17g (r(`r'))",
            '    else file write `fh\' _tab "NA"', "}", "file write `fh' _n",
            "if (`rc' == 0) keep rowid __u1 __s", "else keep rowid __u1", "format __u1 %21x",
            f'quietly export delimited using "{out}/rows/case_{k}.csv", replace datafmt',
        ]
    lines += ["", "file close `fh'", 'display "XSAMPLEFE AUDIT RUN COMPLETED"', ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--focus", choices=["mixed", "reconnect", "prune", "closure"], default="mixed")
    parser.add_argument("--out", required=True, help="a new output directory")
    parser.add_argument("--adopath", required=True, help="the directory of xsamplefe.ado and xsamplefe.plugin")
    args = parser.parse_args()
    out = os.path.abspath(args.out)
    os.makedirs(os.path.join(out, "rows"))
    rng = random.Random(args.seed)
    cases, rows = [], []
    for k in range(1, args.cases + 1):
        case, case_rows = one_case(k, rng, args.focus)
        cases.append(case)
        rows += case_rows
    columns = ["case", "rowid", "u", "us", "m", "t", "g", "b1", "b2", "w", "t0", "x", "z"]
    with open(os.path.join(out, "cases.csv"), "w") as f:
        f.write(",".join(columns) + "\n")
        for r in rows:
            f.write(",".join(str(r[c]) for c in columns) + "\n")
    with open(os.path.join(out, "cases.json"), "w") as f:
        json.dump(dict(results=RESULTS, cases=cases), f)
    with open(os.path.join(out, "run.do"), "w") as f:
        f.write(driver(cases, out, os.path.abspath(args.adopath)))
    print(f"{len(cases)} designs, {len(rows)} rows, in {out}")


if __name__ == "__main__":
    main()
