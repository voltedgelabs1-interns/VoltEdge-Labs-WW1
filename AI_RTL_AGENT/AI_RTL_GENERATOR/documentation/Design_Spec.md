# RTL Design & Micro-Architecture Specification
**Version:** 1.0
**Target Standard:** IEEE 1364-2001 (Verilog-2001)

## 1. Objective
This document outlines the strict micro-architectural rules and coding guidelines used by the AI RTL Generator's prompt engine. 
These rules guarantee that all generated IP cores are 100% synthesizable, portable, and compliant with standard ASIC/FPGA digital design flows.

## 2. Naming Conventions & Port Interfaces
To ensure code readability and smooth integration into larger System-on-Chip (SoC) environments, the generated RTL adheres to standard naming conventions:
* **Clocks & Resets:** The system clock is always named `clk`. Resets are strictly active-low and named `rst_n`.
* **Directional Suffixes:** Module ports use explicit directional suffixes where applicable (e.g., `data_i` for inputs, `valid_o` for outputs) to make top-level instantiation clear.
* **Module Declarations:** Verilog-2001 port declarations are strictly enforced to prevent port-type mismatches during compilation.

## 3. Clocking and Reset Strategy
* **Single Clock Domain:** Unless explicitly requested as an asynchronous crossing FIFO, all modules are generated within a single synchronous clock domain.
* **Reset Discipline:** The AI generates sequential blocks using asynchronous, active-low resets (`always @(posedge clk or negedge rst_n)`). This is the standard practice for modern standard-cell ASIC libraries.
* **Initialization:** The use of `initial` blocks is strictly forbidden in the RTL logic, because they cannot be synthesised. All register initialization must occur dynamically via the `rst_n` signal.

## 4. Synthesis & Linting Constraints
The AI is instructed to pass basic linting checks automatically to ensure "Silicon-Ready" netlists:
* **Zero-Latch Policy:** Transparent latches destroy timing analysis. The AI must provide explicit default assignments or complete `else` branches in all combinational `always @(*)` blocks.
* **Combinational Loops:** The AI avoids assigning a signal to itself in a combinational block to prevent zero-delay infinite loops.
* **Sensitivity Lists:** All combinational logic must use the `always @(*)` construct rather than manually listing signals, preventing simulation-synthesis mismatches.

## 5. State Machine (FSM) Architecture
For protocol controllers like UART, SPI, or I2C, the AI enforces strict Finite State Machine topologies:
* **State Encoding:** States are defined using `localparam` rather than hardcoded macros (``define`) to prevent namespace collisions in multi-module projects.
* **Separation of Logic:** FSMs are structured using the standard "Two-Block" or "Three-Block" methodology:
  1. A sequential block for the state register.
  2. A combinational block for next-state logic.
  3. A separate combinational or registered block for outputs.

## 6. Dynamic Parameterization & Scalability
* **Width Agnosticism:** Modules avoid hardcoded bit-widths. Bus widths are controlled via `# (parameter WIDTH = X)`.
* **Mathematical Scaling:** Memory arrays and FIFOs dynamically calculate their internal pointer widths based on the user-defined depth using the `$clog2()` system function (e.g., `reg [$clog2(DEPTH)-1:0] wr_ptr;`).

## 7. Conclusion
By strictly enforcing these micro-architectural specifications, the AI RTL Generator guarantees that all output code bypasses the common simulation-synthesis mismatches AI does until specified. 
This ensures a seamless transition for the generated IP cores from automated RTL generation directly into formal verification and physical synthesis pipelines.
