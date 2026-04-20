# VeriGen: AI-Powered RTL Generator & Validator

##  Project Overview
The AI RTL Generator is an automated, Command-Line Interface (CLI) tool designed to accelerate the semiconductor design workflow. It utilizes dual AI agents to generate highly parameterized, synthesizable Verilog (IEEE 1364-2001) modules and automatically validates them using an integrated open-source EDA pipeline.
Agent 1 acts as a design engineer, generating stricly verilog-2001 standard code. Agent 2 acts as the verification engineer, writing the testbench and running it through an automated Icarus Verilog pipeline.
 
##  Key Features
* **Interactive CLI:** Menu-driven interface for selecting industry-standard IP cores (ALU, Synchronous FIFO, UART) or custom free-text inputs.
* **Dynamic Parameterization:** User-defined hardware constraints (e.g., Data Width, FIFO Depth, Baud Rate, Clock Frequency) are injected directly into the RTL generation phase.
* **Synthesizable Output:** Strictly enforces Verilog-2001 standards, automatically calculates address widths (`$clog2`).
* **Strict Synthesis Rules** The system prompt forces the AI to avoid initial blocks in the RTL, handle default cases in the state machines and ensure zero  latch interference 
* **Automated Verification Pipeline:** Automatically generates a companion testbench, compiles the code via Icarus Verilog, and runs the simulation to produce `.vcd` waveforms
* **Smart Workspace Management** Automatically arranges the .v, .vcd, _tb.v files into the isolated project directories within the /examples folder.

##  Repository Structure
* `/src` - Core Python source code, API configurations, and prompt rules.
* `/examples` - Generated Verilog IP cores, testbenches, and simulation artifacts.
* `/documentation` - Daily progress reports and GTKWave validation screenshots.
* `/demo_material` - Video demonstrations of the tool execution.

##  Prerequisites
To enusre the automated EDA pipeline functions properly, your system must have the following dependencies installed.
Anotther important requirement is the operating system. The AI  Agent is designed to only run on Linux. 
Ensure your environment has the following installed:
* **Python 3.12+**: run these commands one by one in the terminal 
	python3 -m venv venv
	source venv/bin/activate
* **Icarus Verilog** (`iverilog` & `vvp`) for simulation. run this command in the terminal 
	sudo apt update
	sudo apt install iverilog
* **GTKWave** for viewing waveform outputs. run this command in the terminal 
	sudo aot update 
	sudo apt install gtkwave
* **Google GenAI SDK** (`google-genai`)
	pip install google-genai python-dotenv

##  Usage Instructions
1. Clone this repository and navigate to the root directory.
2. Add your Gemini API Key to the `.env` file inside the `src/` folder:
   `GEMINI_API_KEY="your_api_key_here"`
3. Run the application from the root directory:
   ```bash
   python src/main.py

## Step-By-Step Exceution Guide 
**Step 1: Lanuch the Application** Go to the root directory of the project and run this command python3 main.py or try python3 src/main.py 

**Step 2: Select an IP Core** The CLI will present an interacive menu. Enter the number corresponding to your desired module. 

**Step 3: Define the parameters** The tool will then dynamically ask for the parameters according to your selected module. 

**Step 4: Automated Pipeline Execution** The tool will now run autonomously. You will see the following sequence in your terminal. 
					
					1) Agent 1 generates the strict, parameter driven Verilog2001 code.
					
					2) Agent 2 generates the coressponding _tb.v testench.
					
					3) The system runs iverilog to check for syntax and compile the design.
					
					4) The system runs vvp to simulate the logic and dump into the waveform.

## Locating and Verifying the Outputs 
The tool clearly separates generated files into isolated project folders or rather directories. 
 
For example: Let's say you wanted to design  a FIFO and now the projet is ready. 
There wil be a folder called "examples" and inside that is the FIFO project and it will consist of the following files and order: 
examples/
|__ FIFO_Project/
    |_ hdl/ 
    |  |_fifo.v 		<---Agent 1 Synthesised RTL
    |_ sim/
       |_fifo_tb.v		<---Agent 2 Generated testbench
       |_sim.out		<---Icarus Verilog compiled binary
       |_fifo.vcd		<---Simulation Waveform 

To verify the waveform you click on the  ".vcd" file or run this command 
"gtkwave examples/project_folder/sim/project_name.vcd"
