import re

def parse_report(file):

    with open(file) as f:
        data = f.read()

    slacks = re.findall(r"Slack:\s*(-?\d+\.\d+)", data)

    slacks = [float(s) for s in slacks]

    return slacks