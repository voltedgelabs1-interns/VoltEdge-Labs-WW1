"""
timing_analyzer.py — AI Timing Analyzer CLI
Team C — Semiconductor Internship Week 3

Usage:
    python timing_analyzer.py <report.rpt>
    python timing_analyzer.py <report.rpt> --verbose
    python timing_analyzer.py <report.rpt> --no-ai

With Claude AI (set API key first):
    export ANTHROPIC_API_KEY=your_key_here
    python timing_analyzer.py d1_setup.rpt
"""

import os
import typer
from typing import Optional
from analyzer import analyze_timing, generate_summary
from ai_helper import explain_violation

app = typer.Typer(
    name="AI Timing Analyzer",
    help="Analyzes OpenROAD timing reports and identifies violations using AI."
)


@app.command()
def analyze(
    report: str = typer.Argument(..., help="Path to timing report .rpt file"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="Show full path details"),
    no_ai: bool = typer.Option(False, "--no-ai", help="Skip AI, use rule-based only"),
    output: Optional[str] = typer.Option(None, "--output", "-o", help="Custom output file name"),
):
    # ── File check ──────────────────────────────────────────────
    if not os.path.exists(report):
        typer.echo(f"[ERROR] File not found: {report}", err=True)
        raise typer.Exit(1)

    if no_ai:
        os.environ.pop("ANTHROPIC_API_KEY", None)

    typer.echo(f"\n{'='*58}")
    typer.echo(f"  AI TIMING ANALYZER")
    typer.echo(f"{'='*58}")
    typer.echo(f"  Report : {report}")
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    typer.echo(f"  AI Mode: {'Claude API' if api_key else 'Rule-based (set ANTHROPIC_API_KEY for AI)'}")
    typer.echo(f"{'='*58}")

    # ── Parse ────────────────────────────────────────────────────
    typer.echo("\n[1/3] Parsing timing report...")
    paths, violations = analyze_timing(report)

    if not paths:
        typer.echo("[WARNING] No timing paths found.")
        typer.echo("Check that report contains 'Startpoint:' and 'slack' lines.")
        raise typer.Exit(1)

    # ── Summary ──────────────────────────────────────────────────
    typer.echo("\n[2/3] Analyzing violations...\n")

    slacks  = [p["slack"] for p in paths]
    wns     = min(slacks)
    tns     = sum(s for s in slacks if s < 0)

    setup_v  = [v for v in violations if "setup_violation"     in v["violation_type"]]
    hold_v   = [v for v in violations if "hold_violation"      in v["violation_type"]]
    inreg_v  = [v for v in violations if "in_to_reg"           in v["violation_type"]]
    rout_v   = [v for v in violations if "reg_to_out"          in v["violation_type"]]
    deep_v   = [v for v in violations if "deep_logic_path"     in v["violation_type"]]
    worst_v  = [v for v in violations if "worst_case"          in v["violation_type"]]
    maxd_v   = [v for v in violations if "max_delay_violation" in v["violation_type"]]
    mind_v   = [v for v in violations if "min_delay_violation" in v["violation_type"]]
    skew_v   = [v for v in violations if "skew_related"        in v["violation_type"]]
    fp_v     = [v for v in violations if v["false_path_candidate"]]

    typer.echo("TIMING SUMMARY")
    typer.echo("-" * 40)
    typer.echo(f"  Total paths           : {len(paths)}")
    typer.echo(f"  Total violations      : {len(violations)}")
    typer.echo(f"  Worst slack (WNS)     : {wns:.3f} ns")
    typer.echo(f"  Total neg slack (TNS) : {tns:.3f} ns")
    typer.echo("")
    typer.echo(f"  Setup violations      : {len(setup_v)}")
    typer.echo(f"  Hold violations       : {len(hold_v)}")
    typer.echo(f"  In-to-reg paths       : {len(inreg_v)}")
    typer.echo(f"  Reg-to-out paths      : {len(rout_v)}")
    typer.echo(f"  Deep logic paths      : {len(deep_v)}")
    typer.echo(f"  Worst case paths      : {len(worst_v)}")
    typer.echo(f"  Max delay violations  : {len(maxd_v)}")
    typer.echo(f"  Min delay violations  : {len(mind_v)}")
    typer.echo(f"  Skew-related          : {len(skew_v)}")
    typer.echo(f"  False path suspects   : {len(fp_v)}")

    if verbose:
        typer.echo("\nALL PATHS:")
        for i, p in enumerate(paths, 1):
            status = "VIOLATED" if p["slack"] < 0 else "MET"
            typer.echo(f"  [{i}] {p['startpoint']} -> {p['endpoint']}"
                       f"  slack={p['slack']:.3f}  [{status}]")

    # ── AI Explanations ──────────────────────────────────────────
    typer.echo(f"\n[3/3] Generating AI explanations for {len(violations)} violation(s)...")

    if not violations:
        typer.echo("\nAll timing paths MET. No violations to explain.")
    else:
        for v in violations:
            explain_violation(
                startpoint      = v["startpoint"],
                endpoint        = v["endpoint"],
                slack           = v["slack"],
                violation_types = v["violation_type"],
                path            = v
            )

    # ── Save summary ─────────────────────────────────────────────
    out_file = output if output else "timing_summary.txt"
    generate_summary(paths, violations)

    typer.echo(f"\n[DONE] Summary saved -> {out_file}")
    typer.echo("="*58)


if __name__ == "__main__":
    app()
