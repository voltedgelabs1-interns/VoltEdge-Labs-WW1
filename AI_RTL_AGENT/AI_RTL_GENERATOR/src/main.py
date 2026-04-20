import os
import re
import time
import subprocess
from dotenv import load_dotenv
from google import genai

# --- PATH CONFIGURATION (To match Week 3 Rubric) ---
# This ensures files are saved in the 'examples' folder, no matter where you run the script from
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
EXAMPLES_DIR = os.path.join(PROJECT_ROOT, "examples")

load_dotenv(os.path.join(SCRIPT_DIR, ".env"))
API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    print("❌ ERROR: Please put your Gemini API key in the src/.env file.")
    exit()

client = genai.Client(api_key=API_KEY)

def get_system_rules():
    try:
        with open(os.path.join(SCRIPT_DIR, "system_prompt.txt"), "r") as f:
            return f.read()
    except FileNotFoundError:
        print("❌ ERROR: system_prompt.txt not found in src/ folder.")
        exit()

def generate_rtl(user_request):
    print(f"\n☁️  [Agent 1] Generating RTL for: '{user_request}'...")
    rules = get_system_rules()
    full_prompt = f"{rules}\n\nUser Request: Design {user_request}. Ensure it is fully synthesizable."
    
    try:
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview', 
            contents=full_prompt
        )
        return response.text.replace("```verilog", "").replace("```", "").strip()
    except Exception as e:
        print(f"❌ API Error (RTL): {e}")
        return None

def generate_testbench(rtl_code, module_name):
    print(f"☁️  [Agent 2] Writing Testbench for '{module_name}'...")
    tb_prompt = f"""
    You are a Verification Engineer. Write a Verilog testbench for this module:
    {rtl_code}
    
    MANDATORY RULES:
    1. Testbench module name: {module_name}_tb
    2. YOU MUST include exactly: $dumpfile("{module_name}.vcd");
    3. YOU MUST include exactly: $dumpvars(0, {module_name}_tb);
    4. Provide clock and reset generation.
    5. Output ONLY raw Verilog code.
    """
    try:
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview', 
            contents=tb_prompt
        )
        return response.text.replace("```verilog", "").replace("```", "").strip()
    except Exception as e:
        print(f"❌ API Error (TB): {e}")
        return None

def save_file(code, project_path, subfolder, filename):
    path = os.path.join(project_path, subfolder)
    os.makedirs(path, exist_ok=True) 
    full_path = os.path.join(path, filename)
    with open(full_path, "w") as f:
        f.write(code)
    print(f"💾 Saved: {full_path}")
    return full_path

def run_validation(project_path, mod_name):
    print(f"\n🔨 Running Simulation Validation (Icarus Verilog)...")
    
    rtl_file = os.path.join(project_path, "hdl", f"{mod_name}.v")
    tb_file = os.path.join(project_path, "sim", f"{mod_name}_tb.v")
    out_file = os.path.join(project_path, "sim", "sim.out")

    # 1. Compile
    res = subprocess.run(["iverilog", "-o", out_file, rtl_file, tb_file], 
                         capture_output=True, text=True)
    
    if res.returncode != 0:
        print(f"❌ VALIDATION FAILED (Compilation Error):\n{res.stderr}")
        return False

    print("✅ Compilation Passed!")
    
    # 2. Simulate (Run inside the sim/ folder so the VCD file is saved there)
    sim_dir = os.path.join(project_path, "sim")
    subprocess.run(["vvp", "sim.out"], cwd=sim_dir, capture_output=True)
    print("✅ Simulation Passed! VCD waveform generated.")
    return True

def main_menu():
    print("\n" + "="*50)
    print("🚀 AI-POWERED RTL GENERATOR & VALIDATOR v1.0")
    print("="*50)
    print("Select a hardware module to generate:")
    print("  [1] Parameterized ALU")
    print("  [2] Synchronous FIFO")
    print("  [3] UART Transmitter")
    print("  [4] Custom / Free Text")
    print("  [0] Exit")
    print("-" * 50)
    
    choice = input("Selection: ")
    
    if choice == '1':
        width = input("Enter Data Width (e.g., 8, 16, 32): ")
        return f"a Parameterized ALU. Data width must be {width}-bits. Include basic operations (ADD, SUB, AND, OR)."
    elif choice == '2':
        width = input("Enter Data Width (e.g., 8, 16, 32): ")
        depth = input("Enter FIFO Depth (e.g., 16, 64, 128): ")
        return f"a Synchronous FIFO. Data width must be {width}-bits and depth must be {depth}. Include full and empty flags."
    elif choice == '3':
        baud = input("Enter Baud Rate (e.g., 9600, 115200): ")
        clk = input("Enter Clock Frequency in Hz (e.g., 50000000): ")
        return f"a UART Transmitter. The design must be calibrated for a {baud} baud rate running on a {clk} Hz clock."
    elif choice == '4':
        return input("Enter your custom Verilog request: ")
    elif choice == '0':
        return 'exit'
    else:
        print("Invalid selection.")
        return None

if __name__ == "__main__":
    while True:
        request = main_menu()
        
        if request == 'exit':
            print("Exiting... Good luck with Week 3!")
            break
        elif not request:
            continue
        
        # Step 1: RTL Generation
        rtl = generate_rtl(request)
        if not rtl: continue
        
        match = re.search(r"module\s+(\w+)", rtl)
        mod_name = match.group(1) if match else "temp_mod"
        
        # Determine the project folder path inside the 'examples' directory
        project_path = os.path.join(EXAMPLES_DIR, f"{mod_name}_Project")
        
        # Save RTL
        save_file(rtl, project_path, "hdl", f"{mod_name}.v")
        
        print("⏳ API Cooling Pause...")
        time.sleep(3) 
        
        # Step 2: Testbench Generation
        tb = generate_testbench(rtl, mod_name)
        if tb:
            # Save Testbench
            save_file(tb, project_path, "sim", f"{mod_name}_tb.v")
            
            # Step 3: Run the Verification Pipeline
            run_validation(project_path, mod_name)
