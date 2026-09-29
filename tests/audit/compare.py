"""Compare what Stata wrote for every case with the reference implementation.

Exit status 0 when every case matches (the indicator row by row, the stored
results, the expected errors and the random-number state after an error).
"""
import argparse
import csv
import json
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from oracle import OracleError, run  # noqa: E402

MISSING = {-99001: ".", -99002: ".a", -99003: ".b"}


def hex_double(text):
    """The value of Stata's %21x format, as +1.8000000000000X+005."""
    text = text.strip()
    sign = -1.0 if text[0] == "-" else 1.0
    mantissa, exponent = text.lstrip("+-").split("X")
    whole, fraction = mantissa.split(".")
    return sign * (int(whole, 16) + int(fraction, 16) / 16 ** len(fraction)) * 2.0 ** int(exponent, 16)


def number(text):
    if text == "":
        return None
    v = float(text)
    return int(v) if v == int(v) and abs(v) < 2 ** 53 else v


def unit_of(case, row):
    col = case["unit_col"]
    if col == "u":
        if case["string_unit"]:
            return row["us"] or None
        return number(row["u"])
    if col == "g":
        return number(row["g"])
    u = number(row["u"])  # the interaction u#b1, ranked as egen group() ranks it
    b = int(row["b1"])
    return None if (u is None or b in MISSING) else (u, b)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="the directory written by gen_cases.py and Stata")
    parser.add_argument("--show", type=int, default=20, help="number of differences to print")
    args = parser.parse_args()
    out = args.out
    design = json.load(open(os.path.join(out, "cases.json")))
    data = defaultdict(list)
    with open(os.path.join(out, "cases.csv")) as f:
        for r in csv.DictReader(f):
            data[int(r["case"])].append(r)
    with open(os.path.join(out, "results.tsv")) as f:
        results = {int(r["case"]): r for r in csv.DictReader(f, delimiter="\t")}

    summary = Counter()
    problems = []
    for case in design["cases"]:
        k = case["case"]
        cfg = case["cfg"]
        res = results.get(k)
        if res is None:
            summary["no result from Stata"] += 1
            problems.append((k, "no result from Stata", case["cmd"]))
            continue
        rows = []
        for r in sorted(data[k], key=lambda r: int(r["rowid"])):
            by = []
            for v in cfg.get("by_vars", []):
                b = int(r["b1"])
                by.append(("m" + MISSING[b] if b in MISSING else "n%09d" % b) if v == "b1" else "s" + r["b2"])
            rows.append(dict(unit=unit_of(case, r), by_sort=tuple(by), w=int(r["w"]), touse=int(r["t0"]),
                             group=number(r[case["grp_col"]]) if case["grp_col"] else None,
                             time=number(r["t"]) if cfg["has_time"] else None,
                             mob=number(r[case["mob_col"]]) if cfg["has_mob"] else None))
        with open(os.path.join(out, "rows", f"case_{k}.csv")) as f:
            written = sorted(csv.DictReader(f), key=lambda r: int(r["rowid"]))
        u1 = [hex_double(r["__u1"]) for r in written]
        rc = int(res["rc"])
        try:
            expected, error = run(rows, cfg, u1), None
        except OracleError as e:
            expected, error = None, str(e)
        if error == "tie-in-keys":
            summary["not decided by the reference (tie in the keys)"] += 1
            continue
        if error is not None:
            if rc == 198 and res["rngsame"] == "1":
                summary[f"expected error ({error})"] += 1
            else:
                summary["DIFFERENT"] += 1
                problems.append((k, f"the reference stops ({error}); Stata rc {rc}, "
                                    f"random-number state kept: {res['rngsame']}", case["cmd"]))
            continue
        if rc != 0:
            summary["DIFFERENT"] += 1
            problems.append((k, f"Stata rc {rc}; the reference draws", case["cmd"]))
            continue
        bad = []
        keep = [1 if x else 0 for x in expected["keep"]]
        got = [int(r["__s"]) for r in written]
        if keep != got:
            bad.append("indicator (%d rows)" % sum(1 for a, b in zip(keep, got) if a != b))
        for name in design["results"]:
            want = expected.get(name)
            raw = res[name].strip()
            value = None if raw == "." else float(raw)
            if want is None and value is None:
                continue
            if want is None or value is None or abs(float(want) - value) > 1e-12 * max(1.0, abs(float(want))):
                bad.append(f"r({name}): reference {want}, xsamplefe {value}")
        if bad:
            summary["DIFFERENT"] += 1
            problems.append((k, "; ".join(bad[:6]), case["cmd"]))
        else:
            summary["identical"] += 1

    for key, count in sorted(summary.items()):
        print(f"{count:7d}  {key}")
    for k, what, cmd in problems[:args.show]:
        print(f"case {k}: {what}\n    xsamplefe {cmd}")
    with open(os.path.join(out, "differences.json"), "w") as f:
        json.dump(problems, f, indent=1)
    if summary["DIFFERENT"] or summary["no result from Stata"] or not summary["identical"]:
        print("XSAMPLEFE AUDIT FAILED")
        return 1
    print("XSAMPLEFE AUDIT PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
