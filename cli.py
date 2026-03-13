import typer
from parser import parse_report
from ai_helper import explain_violation
from analyzer import find_violations, summary

app = typer.Typer()

@app.command()
def analyze(report: str):

    slacks = parse_report(report)

    summary(slacks)

    violations = find_violations(slacks)

    print("\nViolations:")

    for v in violations:
        explain_violation("unknown", "unknown", v)

if __name__ == "__main__":
    app()