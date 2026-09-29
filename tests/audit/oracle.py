"""Reference implementation of xsamplefe's unit-level pipeline.

Written from the help file (frame, eligibility, strata, draw, group closure,
reconnect, minmovers, connected, stored results) with naive algorithms: no
heaps, no incremental graphs, integer arithmetic where the help says so. It
is the oracle of the differential test in this directory, not a second
implementation to be used: it is quadratic in places and it does not decide
ties between uniform keys.
"""
import math
from collections import defaultdict


class OracleError(Exception):
    """An error the command is expected to stop with, or a case the oracle leaves undecided."""


def target_size(n, is_count, pct, count):
    """int(n*#/100+.5) as Stata evaluates it, n*(#/100); min(#, n) with count."""
    if n <= 0:
        return 0
    if is_count:
        if not count > 0:
            return 0
        if count >= n:
            return n
        return int(count)
    return max(0, min(n, int(math.floor(float(n) * (pct / 100.0) + 0.5))))


def components(nodes, edges):
    """Label of every node: the smallest node of its component."""
    parent = {x: x for x in nodes}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b in edges:
        ra, rb = find(a), find(b)
        if ra != rb:
            if ra < rb:
                parent[rb] = ra
            else:
                parent[ra] = rb
    return {x: find(x) for x in nodes}


def run(rows, cfg, u1):
    """rows: dicts with unit, group, by_sort (tuple), time, mob, w, touse; unit, group,
    time and mob are None when missing, the by() values are categories (missing values
    included). cfg: the design. u1: the first uniform key column, in row order.
    Returns the retention indicator and the stored results; raises OracleError."""
    n = len(rows)
    has_group = cfg.get("has_group", False)  # group() different from the unit
    has_time = cfg.get("has_time", False)
    has_mob = cfg.get("has_mob", False)
    has_w = cfg.get("has_weight", False)
    rule = cfg.get("frame_rule", "strict")
    w = [r["w"] if has_w else 1 for r in rows]

    # ---- frame: if/in, and a unit (and group) value
    frame = []
    for r in rows:
        ok = bool(r["touse"]) and r["unit"] is not None
        if has_group and r["group"] is None:
            ok = False
        frame.append(ok)
    by_block = defaultdict(list)
    for i, r in enumerate(rows):
        b = r["group"] if has_group else r["unit"]
        if b is not None:
            by_block[b].append(i)
    n_split = 0
    for idx in by_block.values():
        inside = sum(1 for i in idx if frame[i])
        if 0 < inside < len(idx):
            n_split += 1
            if rule == "any":
                for i in idx:
                    frame[i] = True
            elif rule == "all":
                for i in idx:
                    frame[i] = False
    if rule == "strict" and n_split > 0:
        raise OracleError("split")
    if rule == "any" and n_split > 0 and any(frame):
        for i, r in enumerate(rows):
            if frame[i] and (r["unit"] is None or (has_group and r["group"] is None)):
                raise OracleError("any-missing")

    fr = [i for i in range(n) if frame[i]]
    W_all = sum(w)
    W_frame = sum(w[i] for i in fr)

    # ---- units, ranked by value: the r-th smallest takes the r-th uniform
    uvals = sorted({rows[i]["unit"] for i in fr})
    urank = {v: k for k, v in enumerate(uvals)}
    U = len(uvals)
    urows = defaultdict(list)
    for i in fr:
        urows[urank[rows[i]["unit"]]].append(i)

    # ---- strata, constant within units
    nby = cfg.get("nby", 0)
    S_by = len({rows[i]["by_sort"] for i in fr}) if nby > 0 else 1
    ustr = {}
    conflicts = 0
    for u in range(U):
        vals = {rows[i]["by_sort"] for i in urows[u]} if nby > 0 else {()}
        if len(vals) > 1:
            conflicts += 1
        ustr[u] = sorted(vals)[0]
    if conflicts:
        raise OracleError("by-conflict")

    # ---- per-unit statistics over the frame rows
    T = len({rows[i]["time"] for i in fr if rows[i]["time"] is not None}) if has_time else None
    M = len({rows[i]["mob"] for i in fr if rows[i]["mob"] is not None}) if has_mob else None
    G = len({rows[i]["group"] for i in fr}) if has_group else None
    nobs, nper, nmob = {}, {}, {}
    for u in range(U):
        idx = urows[u]
        nobs[u] = sum(w[i] for i in idx)
        nper[u] = len({rows[i]["time"] for i in idx if rows[i]["time"] is not None}) if has_time else 0
        nmob[u] = len({rows[i]["mob"] for i in idx if rows[i]["mob"] is not None}) if has_mob else 0
    sfinal = {u: (ustr[u], nmob[u]) if cfg.get("mobstrata") else (ustr[u],) for u in range(U)}

    # ---- eligibility: the bounds are inclusive
    def bound(name):
        v = cfg.get(name, -1)
        return -1 if v is None else v

    elig = {}
    for u in range(U):
        ok = True
        if bound("minobs") >= 0 and nobs[u] < bound("minobs"):
            ok = False
        if bound("maxobs") >= 0 and nobs[u] > bound("maxobs"):
            ok = False
        if has_time:
            if bound("minperiods") >= 0 and nper[u] < bound("minperiods"):
                ok = False
            if bound("maxperiods") >= 0 and nper[u] > bound("maxperiods"):
                ok = False
            if cfg.get("balanced") and (nper[u] == 0 or nper[u] != T):
                ok = False
        if has_mob:
            if bound("minmob") >= 0 and nmob[u] < bound("minmob"):
                ok = False
            if bound("maxmob") >= 0 and nmob[u] > bound("maxmob"):
                ok = False
        elig[u] = ok
    mover = {u: (has_mob and nmob[u] >= 2) for u in range(U)}

    # ---- draw: the smallest keys of every final stratum
    has_rates = ("rate_movers" in cfg) or ("rate_stayers" in cfg)
    strata = defaultdict(list)
    for u in range(U):
        if elig[u]:
            strata[sfinal[u] + ((1 if mover[u] else 0,) if has_rates else ())].append(u)
    is_count = cfg["is_count"]
    sel = set()
    K_total = 0
    for key in sorted(strata):
        units = strata[key]
        pct = cfg.get("pct", 0.0)
        count = cfg.get("count", 0)
        if has_rates:
            name = "rate_movers" if key[-1] == 1 else "rate_stayers"
            if name in cfg:
                if is_count:
                    count = cfg[name]
                else:
                    pct = cfg[name]
        k = target_size(len(units), is_count, pct, count)
        K_total += k
        if 0 < k < len(units):
            keys = sorted((u1[u], u) for u in units)
            if len({a for a, _ in keys}) != len(keys):
                raise OracleError("tie-in-keys")
            sel.update(u for _, u in keys[:k])
        elif k >= len(units):
            sel.update(units)

    keep = [True] * n  # rows outside the frame are kept
    for i in fr:
        keep[i] = urank[rows[i]["unit"]] in sel

    # ---- group closure
    G_kept = None
    if has_group:
        grow = defaultdict(list)
        for i in fr:
            grow[rows[i]["group"]].append(i)
        gk = {}
        for g, idx in grow.items():
            kept = sum(1 for i in idx if keep[i])
            gk[g] = (kept > 0) if cfg.get("group_rule", "any") == "any" else (kept == len(idx))
        G_kept = sum(1 for g in gk if gk[g])
        for i in fr:
            keep[i] = gk[rows[i]["group"]]

    # ---- the unit x mobility graph of a set of rows
    def graph(mask_rows):
        units_rows = defaultdict(int)
        edges = []
        mobs = set()
        gfirst = {}
        for i in mask_rows:
            u = urank[rows[i]["unit"]]
            units_rows[u] += w[i]
            m = rows[i]["mob"]
            if m is not None:
                mobs.add(m)
                edges.append((("a", u), ("b", m)))
            if has_group:
                g = rows[i]["group"]
                if g in gfirst:
                    edges.append((("a", u), ("a", gfirst[g])))
                else:
                    gfirst[g] = u
        comp = components([("a", u) for u in units_rows] + [("b", m) for m in mobs], edges)
        crow = defaultdict(int)
        for u, rws in units_rows.items():
            crow[comp[("a", u)]] += rws
        best, lcc = 0, None
        for u in sorted(units_rows):  # ties: the component of the smallest unit
            c = comp[("a", u)]
            if crow[c] > best:
                best, lcc = crow[c], c
        return dict(comp=comp, crow=crow, total=sum(units_rows.values()), best=best, lcc=lcc,
                    ncomp=len({comp[("a", u)] for u in units_rows}), units=set(units_rows), mobs=mobs,
                    lcc_units={u for u in units_rows if lcc is not None and comp[("a", u)] == lcc},
                    lcc_mobs={m for m in mobs if lcc is not None and comp[("b", m)] == lcc})

    def mobstats(mask_rows):
        links = defaultdict(set)
        for i in mask_rows:
            if rows[i]["mob"] is not None:
                links[urank[rows[i]["unit"]]].add(rows[i]["mob"])
        movers_of = defaultdict(int)
        present = set()
        for ms in links.values():
            for m in ms:
                present.add(m)
                if len(ms) >= 2:
                    movers_of[m] += 1
        total = sum(movers_of[m] for m in present)
        return dict(values=len(present), mean=(total / len(present) if present else 0.0),
                    weak=sum(1 for m in present if movers_of[m] <= 1), movers_of=movers_of, links=links)

    minmovers = cfg.get("minmovers", -1)
    diag = has_mob and bool(cfg.get("connectivity") or cfg.get("reconnect") or cfg.get("connected")
                            or minmovers >= 0)
    mobdiag = has_mob and bool(cfg.get("connectivity") or minmovers >= 0)
    frame_g = frame_m = None
    if diag and fr:
        elig_rows = [i for i in fr if elig[urank[rows[i]["unit"]]]]
        frame_g = graph(elig_rows)
        if mobdiag:
            frame_m = mobstats(elig_rows)

    def sample_rows():
        return [i for i in fr if keep[i]]

    # ---- reconnect: one unit at a time, the graph recomputed after each
    U_rec = N_rec = None
    if cfg.get("reconnect"):
        U_rec = N_rec = 0
        if fr and U > 0:
            target = cfg.get("recon_target", -1.0)
            explicit = target >= 0.0
            whole = explicit and math.floor(target) == target
            if explicit:
                has_target = target > 0.0
            else:
                has_target = frame_g is not None and frame_g["total"] > 0 and frame_g["best"] > 0

            def below(b, t):
                if not explicit:
                    return b * frame_g["total"] < frame_g["best"] * t
                if whole:
                    return b * 100 < int(target) * t
                return float(b) * 100.0 < target * float(t)

            unit_mobs = defaultdict(set)
            for i in fr:
                if rows[i]["mob"] is not None:
                    unit_mobs[urank[rows[i]["unit"]]].add(rows[i]["mob"])
            g0 = graph(sample_rows())
            grown = set(g0["lcc_units"])
            while g0["lcc"] is not None and has_target:
                g = graph(sample_rows())
                lab = g["comp"][("a", min(grown))]
                if not (g["total"] > 0 and below(g["crow"][lab], g["total"])):
                    break
                lcc_m = {m for m in g["mobs"] if g["comp"][("b", m)] == lab}
                cands = [u for u in range(U) if elig[u] and u not in g["units"] and (unit_mobs[u] & lcc_m)]
                if not cands:
                    break
                if cfg.get("recon_rule", "gain") == "gain":
                    def gain(u):
                        touched = {g["comp"][("b", m)] for m in unit_mobs[u] if m in g["mobs"]} - {lab}
                        return nobs[u] + sum(g["crow"][c] for c in touched)
                    scored = sorted((-gain(u), u1[u], u) for u in cands)
                else:
                    scored = sorted((0, u1[u], u) for u in cands)
                if len(scored) > 1 and scored[0][:2] == scored[1][:2]:
                    raise OracleError("tie-in-keys")
                pick = scored[0][2]
                for i in urows[pick]:
                    keep[i] = True
                grown.add(pick)
                U_rec += 1
                N_rec += nobs[pick]

    # ---- minmovers and connected, to a joint fixed point
    N_conn = 0
    n_comp_first = 0
    U_mm = N_mm = iters = None
    if minmovers >= 0:
        U_mm = N_mm = iters = 0
    if (cfg.get("connected") or minmovers >= 0) and fr:
        iters = 0
        first = True
        while True:
            changed = False
            if minmovers >= 0:
                ms = mobstats(sample_rows())
                weak = {u for u, mset in ms["links"].items()
                        if any(ms["movers_of"][m] < minmovers for m in mset)}
                if weak:
                    for i in sample_rows():
                        if urank[rows[i]["unit"]] in weak:
                            keep[i] = False
                            N_mm += w[i]
                    U_mm += len(weak)
                    changed = True
            if cfg.get("connected"):
                g = graph(sample_rows())
                if first:
                    n_comp_first = g["ncomp"]
                    first = False
                dropped = 0
                for i in sample_rows():
                    if g["comp"][("a", urank[rows[i]["unit"]])] != g["lcc"]:
                        keep[i] = False
                        dropped += w[i]
                if dropped > 0:
                    N_conn += dropped
                    changed = True
            iters += 1
            if not changed or minmovers < 0:
                break
            if iters > 10000:
                raise OracleError("no-convergence")
    if minmovers < 0:
        iters = None

    # ---- stored results
    samp = sample_rows()
    retrows = defaultdict(int)
    for i in samp:
        retrows[urank[rows[i]["unit"]]] += w[i]
    N_fr_ret = sum(retrows.values())
    res = dict(keep=keep)
    res["N_total"] = W_all
    res["N_frame"] = W_frame
    res["N_outside"] = W_all - W_frame
    res["N_ineligible"] = sum(nobs[u] for u in range(U) if not elig[u])
    res["N_frame_retained"] = N_fr_ret
    res["N_retained"] = res["N"] = N_fr_ret + (W_all - W_frame)
    res["N_connected_dropped"] = N_conn
    res["n_components"] = n_comp_first
    res["N_units"] = U
    res["N_units_eligible"] = sum(1 for u in range(U) if elig[u])
    res["N_units_ineligible"] = sum(1 for u in range(U) if not elig[u])
    res["N_units_sampled"] = len(sel)
    res["N_units_retained"] = len(retrows)
    res["N_units_partial"] = sum(1 for u, r in retrows.items() if r < nobs[u])
    res["N_units_ineligible_retained"] = sum(1 for u in retrows if not elig[u])
    res["N_movers_eligible"] = sum(1 for u in range(U) if elig[u] and mover[u])
    res["N_movers_sampled"] = sum(1 for u in sel if mover[u])
    res["N_movers_retained"] = sum(1 for u in retrows if mover[u])
    res["N_units_split"] = n_split
    res["N_target"] = K_total
    res["N_strata"] = S_by
    res["N_strata_final"] = len(strata)
    res["N_periods"] = T
    res["N_mobility"] = M
    res["N_mobility_retained"] = (len({rows[i]["mob"] for i in samp if rows[i]["mob"] is not None})
                                  if has_mob else None)
    if has_group:
        res["N_groups"], res["N_groups_kept"] = G, G_kept
        res["N_groups_retained"] = len({rows[i]["group"] for i in samp})
    elif cfg.get("group_is_unit"):
        res["N_groups"], res["N_groups_kept"], res["N_groups_retained"] = U, len(sel), len(retrows)
    else:
        res["N_groups"] = res["N_groups_kept"] = res["N_groups_retained"] = None
    graph_names = ["N_components_frame", "lcc_share_frame", "N_components", "lcc_share", "lcc_units_share",
                   "lcc_mobility_share", "N_units_lcc_kept"]
    for k in graph_names:
        res[k] = 0 if diag else None
    if diag and fr:
        sg = graph(samp)
        res["N_components_frame"] = frame_g["ncomp"]
        res["lcc_share_frame"] = frame_g["best"] / frame_g["total"] if frame_g["total"] else 0.0
        res["N_components"] = sg["ncomp"]
        res["lcc_share"] = sg["best"] / sg["total"] if sg["total"] else 0.0
        res["lcc_units_share"] = len(sg["lcc_units"]) / len(sg["units"]) if sg["units"] else 0.0
        res["lcc_mobility_share"] = len(sg["lcc_mobs"]) / len(sg["mobs"]) if sg["mobs"] else 0.0
        res["N_units_lcc_kept"] = len(sg["lcc_units"] & frame_g["lcc_units"])
    mob_names = ["movers_per_mob_frame", "movers_per_mob", "weak_mob_share_frame", "weak_mob_share"]
    for k in mob_names:
        res[k] = 0.0 if mobdiag else None
    if mobdiag and fr:
        sm = mobstats(samp)
        res["movers_per_mob_frame"] = frame_m["mean"]
        res["movers_per_mob"] = sm["mean"]
        res["weak_mob_share_frame"] = frame_m["weak"] / frame_m["values"] if frame_m["values"] else 0.0
        res["weak_mob_share"] = sm["weak"] / sm["values"] if sm["values"] else 0.0
    res["N_units_reconnected"] = U_rec
    res["N_reconnected"] = N_rec
    res["N_units_minmovers_dropped"] = U_mm
    res["N_minmovers_dropped"] = N_mm
    res["minmovers_iterations"] = iters
    return res
