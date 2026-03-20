from ai_helper import explain_violation
import typer
from analyzer import analyze_timing, generate_summary

app = typer.Typer()

@app.command()
def analyze(report: str):

    paths, violations = analyze_timing(report)

    print("\nTiming Summary")
    print("----------------")

    print(f"Total paths: {len(paths)}")
    print(f"Total violations: {len(violations)}")

    worst = min([p["slack"] for p in paths])
    print(f"Worst slack: {worst}")

    if violations:
        print("\nTiming Violations:")

        for v in violations:
            explain_violation(v["startpoint"], v["endpoint"], v["slack"])

    generate_summary(paths, violations)

app()