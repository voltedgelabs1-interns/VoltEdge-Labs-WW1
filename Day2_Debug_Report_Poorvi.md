# Day 2 Debug Report – Poorvi

## Task
Implementation of Mealy and Moore FSM (1011) using Verilog in Vivado.

## Tools Used
- Vivado
- Verilog
- Git & GitHub
- VS Code

## Initial Errors Faced
- Signals showing Z and X in waveform
- Testbench not driving inputs
- Module not found error in simulation

## Debugging Approach
- Verified module and file names
- Checked Design Sources vs Simulation Sources
- Ensured testbench set as simulation top
- Re-ran behavioral simulation after each fix

## What I Searched
- "Vivado signals Z and X"
- "Vivado module not found error"
- "How to set testbench as top in Vivado"

## Fixes Applied
- Moved testbench to Simulation Sources
- Corrected DUT instantiation
- Regenerated FSM code
- Recompiled and simulated again

## Final Result
Mealy and Moore FSMs simulated correctly. Output matched expected behavior.

## Learnings
- Importance of testbench hierarchy
- Difference between Mealy and Moore FSM outputs
- Debugging systematically instead of random changes
