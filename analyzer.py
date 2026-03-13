def find_violations(slacks):

    violations = []

    for s in slacks:
        if s < 0:
            violations.append(s)

    return violations


def summary(slacks):

    total = len(slacks)
    violations = [s for s in slacks if s < 0]

    worst = min(slacks)

    print("\nTiming Summary")
    print("----------------")
    print("Total paths:", total)
    print("Total violations:", len(violations))
    print("Worst slack:", worst)