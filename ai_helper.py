
def explain_violation(startpoint, endpoint, slack):

    print("\nTiming Violation Detected")
    print("-------------------------")
    print("Startpoint:", startpoint)
    print("Endpoint:", endpoint)
    print("Slack:", slack, "ns")

    if slack < -0.3:
        print("\nAI Analysis: Severe timing violation")
        print("Possible cause: long combinational path")

        print("\nSuggested Fixes:")
        print("- Insert pipeline stage")
        print("- Break long combinational logic")
        print("- Improve placement and routing")

    elif slack < 0:
        print("\nAI Analysis: Moderate timing violation")

        print("\nSuggested Fixes:")
        print("- Reduce fanout")
        print("- Optimize synthesis")
        print("- Adjust clock constraints")