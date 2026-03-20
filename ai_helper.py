"""
ai_helper.py — AI Explanation Module
Sends timing violations to Claude API and gets real,
accurate suggestions. Falls back to rule-based suggestions
if no API key is available.
"""

import os
import json
import urllib.request
import urllib.error


# ── Rule-based fallback suggestions ────────────────────────────────────────
RULE_SUGGESTIONS = {
    "setup_violation": [
        "Upsize drive strength of cells on critical path",
        "Add pipeline register to split long combinational path",
        "Replace slow cells with faster variants",
        "Reduce clock period constraint if goal is too aggressive",
        "Use faster library corner to check margin",
    ],
    "hold_violation": [
        "Insert delay buffers on the fast path",
        "Add clock insertion delay to balance arrival times",
        "Use set_multicycle_path if path is intentionally slow",
        "Increase clock uncertainty hold margin",
        "Ensure clock skew is correctly modeled in constraints",
    ],
    "in_to_reg": [
        "Reduce set_input_delay constraint value",
        "Add input register stage closer to input port",
        "Remove unnecessary buffering on input path",
        "Increase clock period to allow more input settling time",
        "Check if input path has high fanout causing extra delay",
    ],
    "reg_to_out": [
        "Reduce set_output_delay constraint",
        "Add output register stage closer to output port",
        "Upsize output buffer drive strength",
        "Check output net fanout - high fanout increases delay",
        "Consider adding dedicated output flip-flop",
    ],
    "deep_logic_path": [
        "Insert pipeline register in middle of logic chain",
        "Restructure logic to reduce depth using balanced tree",
        "Use faster AOI/OAI cells to reduce gate count",
        "Apply logic retiming to move registers across logic",
        "Check if redundant logic can be optimized away",
    ],
    "worst_case": [
        "CRITICAL PATH - fix this first before other violations",
        "Consider architectural change: split into 2 pipeline stages",
        "Run with faster process corner to check true criticality",
        "Apply set_max_delay to relax non-critical path copies",
        "Use physical optimization to place cells closer together",
    ],
    "max_delay_violation": [
        "Identify the single cell causing maximum delay on path",
        "Upsize that specific cell to reduce propagation delay",
        "Check for high capacitance on net - add repeater buffer",
        "Verify liberty timing model is accurate for this cell",
        "Consider replacing cell with a faster variant",
    ],
    "min_delay_violation": [
        "Add delay buffer on fast path to meet minimum delay",
        "Check for missing hold constraints on this path",
        "Verify clock skew modeling is correct",
        "Use set_min_delay constraint to tighten hold requirement",
    ],
    "skew_related": [
        "Check clock tree synthesis settings - skew too high",
        "Add clock buffers to balance clock arrival time at FFs",
        "Use set_clock_latency to model insertion delay accurately",
        "Verify clock uncertainty value matches actual jitter spec",
        "Reduce CTS target skew in synthesis constraints",
    ],
    "marginal_hold": [
        "Hold margin very tight - add small delay buffer as safety",
        "Monitor across all PVT corners - may fail at fast corner",
        "Increase clock uncertainty hold margin slightly",
    ],
    "long_chain_check_false_path": [
        "This path may be a false path - verify it is exercised",
        "Apply set_false_path if path never sensitizes in operation",
        "Check if this is a test/scan path to exclude from STA",
    ],
}


def _build_prompt(startpoint, endpoint, slack, violation_types, path):
    """Build a detailed prompt for the AI."""
    vt_str   = ", ".join(violation_types) if violation_types else "unknown"
    depth    = path.get("logic_depth", "N/A") if path else "N/A"
    max_del  = path.get("max_segment_delay", 0) if path else 0
    max_cell = path.get("max_delay_cell", "unknown") if path else "unknown"
    arr      = path.get("arrival_time", "N/A") if path else "N/A"
    req      = path.get("required_time", "N/A") if path else "N/A"
    fp       = path.get("false_path_candidate", []) if path else []
    check    = path.get("check_type", "unknown") if path else "unknown"

    prompt = f"""You are an expert digital IC timing analysis engineer.
Analyze this timing violation from an OpenROAD STA report and provide:
1. Root cause explanation (2-3 sentences, technical)
2. Top 4 specific actionable fixes ranked by effectiveness
3. One-line severity assessment

VIOLATION DATA:
- Startpoint     : {startpoint}
- Endpoint       : {endpoint}
- Slack          : {slack:.3f} ns (VIOLATED)
- Check type     : {check.upper()}
- Violation types: {vt_str}
- Logic depth    : {depth} cells
- Max cell delay : {max_del:.3f} ns at {max_cell}
- Arrival time   : {arr} ns
- Required time  : {req} ns
- False path hint: {', '.join(fp) if fp else 'None'}

Respond in this exact format:
ROOT CAUSE: <explanation>
FIX 1: <most effective fix>
FIX 2: <second fix>
FIX 3: <third fix>
FIX 4: <fourth fix>
SEVERITY: <Critical/High/Medium/Low> - <one line reason>"""

    return prompt


def _call_claude_api(prompt):
    """Call Claude API directly using urllib (no extra packages needed)."""
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return None

    payload = json.dumps({
        "model": "claude-sonnet-4-20250514",
        "max_tokens": 1000,
        "messages": [{"role": "user", "content": prompt}]
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
            return data["content"][0]["text"]
    except urllib.error.HTTPError as e:
        print(f"[WARNING] API error {e.code} — using rule-based suggestions")
        return None
    except Exception as e:
        print(f"[WARNING] API call failed ({e}) — using rule-based suggestions")
        return None


def _rule_based_suggestions(violation_types, path):
    """Generate suggestions from rule table when API not available."""
    seen = set()
    suggestions = []

    priority = [
        "worst_case", "setup_violation", "hold_violation",
        "deep_logic_path", "in_to_reg", "reg_to_out",
        "max_delay_violation", "min_delay_violation",
        "skew_related", "marginal_hold", "long_chain_check_false_path"
    ]

    for vtype in priority:
        if vtype in (violation_types or []) and vtype in RULE_SUGGESTIONS:
            for s in RULE_SUGGESTIONS[vtype]:
                if s not in seen:
                    seen.add(s)
                    suggestions.append(s)
            if len(suggestions) >= 5:
                break

    return suggestions[:5]


def explain_violation(startpoint, endpoint, slack,
                      violation_types=None, path=None):
    """
    Main function called by timing_analyzer.py.
    Uses Claude API if ANTHROPIC_API_KEY is set, else rule-based.
    """
    print("\n" + "=" * 58)
    print("  VIOLATION")
    print("=" * 58)
    print(f"  Startpoint  : {startpoint}")
    print(f"  Endpoint    : {endpoint}")
    print(f"  Slack       : {slack:.3f} ns  [VIOLATED]")

    if path:
        print(f"  Check       : {path.get('check_type','').upper()}")
        print(f"  Types       : {', '.join(violation_types or [])}")
        print(f"  Logic depth : {path.get('logic_depth', 'N/A')} cells")
        print(f"  Max delay   : {path.get('max_segment_delay', 0):.3f} ns"
              f" at {path.get('max_delay_cell','unknown')}")
        if path.get("false_path_candidate"):
            print(f"  FP Warning  : {', '.join(path['false_path_candidate'])}")

    # Try Claude API first
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if api_key:
        print("\n  [AI] Querying Claude for analysis...")
        prompt   = _build_prompt(startpoint, endpoint, slack, violation_types or [], path)
        response = _call_claude_api(prompt)

        if response:
            print("\n  AI ANALYSIS:")
            for line in response.strip().split("\n"):
                print(f"  {line}")
            print("=" * 58)
            return

    # Fallback to rule-based
    print("\n  SUGGESTIONS (rule-based):")
    suggestions = _rule_based_suggestions(violation_types, path)
    for i, s in enumerate(suggestions, 1):
        print(f"   {i}. {s}")
    print("=" * 58)
