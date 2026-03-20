import re


def analyze_timing(report_file):
    with open(report_file, 'r') as f:
        content = f.read()

    blocks = re.split(r'(?=Startpoint:)', content)
    blocks = [b.strip() for b in blocks if 'Startpoint:' in b]

    paths = []
    violations = []

    for block in blocks:
        path = _parse_block(block)
        if path:
            paths.append(path)
            if path["slack"] < 0:
                violations.append(path)

    return paths, violations


def _parse_block(block):
    path = {}

    m = re.search(r'Startpoint:\s+(.+)', block)
    path["startpoint"] = m.group(1).strip() if m else "unknown"

    m = re.search(r'Endpoint:\s+(.+)', block)
    path["endpoint"] = m.group(1).strip() if m else "unknown"

    m = re.search(r'Path Type:\s+(\w+)', block)
    raw_type = m.group(1).strip() if m else "unknown"
    path["path_type"] = raw_type
    path["check_type"] = "setup" if raw_type == "max" else "hold" if raw_type == "min" else "unknown"

    m = re.search(r'Path Group:\s+(.+)', block)
    path["path_group"] = m.group(1).strip() if m else "unknown"

    # Slack format in OpenROAD: "          -0.17   slack (VIOLATED)"
    m = re.search(r'([-\d.]+)\s+slack\s+\((\w+)\)', block)
    if m:
        path["slack"] = float(m.group(1))
        path["slack_status"] = m.group(2)
    else:
        path["slack"] = 0.0
        path["slack_status"] = "UNKNOWN"

    # Arrival time: "           0.55   data arrival time"
    m = re.search(r'([\d.]+)\s+data arrival time', block)
    path["arrival_time"] = float(m.group(1)) if m else None

    # Required time: "           0.39   data required time"
    m = re.search(r'([\d.]+)\s+data required time', block)
    path["required_time"] = float(m.group(1)) if m else None

    cells = re.findall(r'\((sky130_fd_sc_hd__\w+)\)', block)
    path["cell_chain"] = cells
    path["logic_depth"] = len(cells)

    delay_lines = re.findall(r'^\s+([\d.]+)\s+([\d.]+)\s+[v^]\s+(.+)', block, re.MULTILINE)
    path["delays"] = [(float(d[0]), d[2].strip()) for d in delay_lines]
    path["max_segment_delay"] = max([d[0] for d in path["delays"]]) if path["delays"] else 0.0
    path["max_delay_cell"] = next(
        (d[1] for d in path["delays"] if d[0] == path["max_segment_delay"]), "unknown"
    )

    path["violation_type"] = _classify(path)
    path["false_path_candidate"] = _false_path_hints(path)

    return path


def _classify(path):
    slack = path["slack"]
    check = path["check_type"]
    start = path["startpoint"].lower()
    end   = path["endpoint"].lower()
    depth = path["logic_depth"]

    if slack >= 0:
        return ["no_violation"]

    types = []

    if check == "setup":
        types.append("setup_violation")
        if "input port" in start or "(input" in start:
            types.append("in_to_reg")
        if "output" in end or "(output" in end:
            types.append("reg_to_out")
        if depth >= 4:
            types.append("deep_logic_path")
        if slack < -0.3:
            types.append("worst_case")
        if path.get("max_segment_delay", 0) > 0.3:
            types.append("max_delay_violation")

    elif check == "hold":
        types.append("hold_violation")
        types.append("min_delay_violation")
        if path.get("arrival_time") and path.get("required_time"):
            if abs(path["arrival_time"] - path["required_time"]) < 0.05:
                types.append("skew_related")
        if slack > -0.1:
            types.append("marginal_hold")

    return types if types else ["unknown_violation"]


def _false_path_hints(path):
    start = path["startpoint"].lower()
    end   = path["endpoint"].lower()
    hints = []
    if "scan" in start or "scan" in end:
        hints.append("possible_scan_path")
    if "test" in start or "test" in end:
        hints.append("possible_test_path")
    if path["logic_depth"] > 8 and path["check_type"] == "setup":
        hints.append("long_chain_check_false_path")
    if path["path_group"] == "**async_default**":
        hints.append("async_crossing_needs_constraints")
    return hints


def generate_summary(paths, violations):
    lines = []
    lines.append("=" * 60)
    lines.append("     AI TIMING ANALYZER - SUMMARY REPORT")
    lines.append("=" * 60)
    lines.append(f"Total paths analyzed  : {len(paths)}")
    lines.append(f"Total violations      : {len(violations)}")

    if paths:
        slacks = [p["slack"] for p in paths]
        lines.append(f"Worst slack (WNS)     : {min(slacks):.3f} ns")
        lines.append(f"Best slack            : {max(slacks):.3f} ns")
        tns = sum(p["slack"] for p in paths if p["slack"] < 0)
        lines.append(f"Total negative slack  : {tns:.3f} ns")

    setup_v = [v for v in violations if "setup_violation"     in v["violation_type"]]
    hold_v  = [v for v in violations if "hold_violation"      in v["violation_type"]]
    inreg_v = [v for v in violations if "in_to_reg"           in v["violation_type"]]
    rout_v  = [v for v in violations if "reg_to_out"          in v["violation_type"]]
    deep_v  = [v for v in violations if "deep_logic_path"     in v["violation_type"]]
    worst_v = [v for v in violations if "worst_case"          in v["violation_type"]]
    maxd_v  = [v for v in violations if "max_delay_violation" in v["violation_type"]]
    mind_v  = [v for v in violations if "min_delay_violation" in v["violation_type"]]
    fp_v    = [v for v in violations if v["false_path_candidate"]]

    lines.append(f"\nSetup violations      : {len(setup_v)}")
    lines.append(f"Hold violations       : {len(hold_v)}")
    lines.append(f"In-to-reg violations  : {len(inreg_v)}")
    lines.append(f"Reg-to-out violations : {len(rout_v)}")
    lines.append(f"Deep logic paths      : {len(deep_v)}")
    lines.append(f"Worst case paths      : {len(worst_v)}")
    lines.append(f"Max delay violations  : {len(maxd_v)}")
    lines.append(f"Min delay violations  : {len(mind_v)}")
    lines.append(f"False path suspects   : {len(fp_v)}")

    lines.append("\n" + "-" * 60)
    lines.append("VIOLATION DETAILS")
    lines.append("-" * 60)

    for i, v in enumerate(violations, 1):
        lines.append(f"\n[{i}] {' | '.join(v['violation_type'])}")
        lines.append(f"    Startpoint  : {v['startpoint']}")
        lines.append(f"    Endpoint    : {v['endpoint']}")
        lines.append(f"    Slack       : {v['slack']:.3f} ns  ({v['slack_status']})")
        lines.append(f"    Check type  : {v['check_type'].upper()}")
        lines.append(f"    Logic depth : {v['logic_depth']} cells")
        lines.append(f"    Max delay   : {v['max_segment_delay']:.3f} ns at {v['max_delay_cell']}")
        if v["false_path_candidate"]:
            lines.append(f"    FP Warning  : {', '.join(v['false_path_candidate'])}")

    lines.append("\n" + "=" * 60)

    with open("timing_summary.txt", "w") as f:
        f.write("\n".join(lines))

    print("\n".join(lines))
    print("\n[INFO] Summary saved -> timing_summary.txt")
