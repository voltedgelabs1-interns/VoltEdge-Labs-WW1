import os
import re
import time
import subprocess
from dotenv import load_dotenv
from google import genai

# 1. Load Environment Variables
load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    print("❌ ERROR: Please put your real Gemini API key in the .env file.")
    exit()

# Initialize the new Gemini Client
client = genai.Client(api_key=API_KEY)

def get_system_rules():
    """Reads the 50 strict RTL rules from your text file."""
    try:
        with open("system_prompt.txt", "r") as f:
            return f.read()
    except FileNotFoundError:
        print("❌ ERROR: system_prompt.txt not found.")
        exit
        
def generate_rtl(user_request):
    """Generates the RTL module based on your 50 rules."""
    print(f"\n☁️  [RTL Agent] Designing hardware for: '{user_request}'...")
    rules = get_system_rules()
    
    # NEW: We add explicit formatting instructions for multiple modules
    full_prompt = f"{rules}\n\nIMPORTANT: If the request requires multiple modules, output EACH module in its own separate ```verilog ... ``` markdown block.\n\nUser Request: Design {user_request}"
    
    try:
        response = client.models.generate_content(
            model='gemini-3.1-flash-lite-preview', 
            contents=full_prompt
        )
        return response.text # Notice we do NOT strip the markdown tags here anymore!
    except Exception as e:
        if "429" in str(e):
            print("⚠️ Quota hit. Please wait a moment before trying again.")
        else:
            print(f"❌ API Error (RTL): {e}")
        return None

def save_to_project(code, project_name, subfolder, filename):
    """Saves code into a clearly defined folder structure."""
    path = os.path.join(project_name, subfolder)
    
    # exist_ok=True ensures it doesn't crash if the folder is already there
    os.makedirs(path, exist_ok=True) 
    
    full_path = os.path.join(path, filename)
    with open(full_path, "w") as f:
        f.write(code)
    print(f"💾 Saved RTL to: {full_path}")
    return full_path
    
def extract_and_save_modules(ai_response, base_project_name):
    """Finds all Verilog code blocks in the response and saves them separately."""
    
    # This regex finds everything inside ```verilog and ``` blocks
    blocks = re.findall(r"```verilog(.*?)```", ai_response, re.DOTALL)
    
    # Fallback just in case the AI forgets the markdown tags
    if not blocks:
        blocks = [ai_response.replace("```verilog", "").replace("```", "")]
        
    saved_files = []
    
    # Loop through every module block the AI generated
    for block in blocks:
        block = block.strip()
        if not block:
            continue
            
        # Extract the specific module name for this exact block
        match = re.search(r"module\s+(\w+)", block)
        mod_name = match.group(1) if match else f"temp_mod_{len(saved_files)}"
        
        # Save to the project's hdl/ folder
        path = os.path.join(base_project_name, "hdl")
        os.makedirs(path, exist_ok=True) 
        full_path = os.path.join(path, f"{mod_name}.v")
        
        with open(full_path, "w") as f:
            f.write(block)
            
        print(f"💾 Saved RTL to: {full_path}")
        saved_files.append(mod_name)
        
    return saved_files

def check_syntax(proj_name, mod_name):
    """Runs Icarus Verilog to compile the RTL and check for syntax errors."""
    print(f"🔨 Running Syntax Check (iverilog) for {mod_name}...")
    
    rtl_file = os.path.join("hdl", f"{mod_name}.v")
    out_file = os.path.join("hdl", "temp.out") # Temporary compilation output
    
    # Run iverilog strictly on the RTL file to check for syntax errors
    res = subprocess.run(["iverilog", "-o", out_file, rtl_file], 
                         cwd=proj_name, capture_output=True, text=True)
    
    if res.returncode != 0:
        print(f"❌ SYNTAX ERROR:\n{res.stderr}")
    else:
        print("✅ SYNTAX PASSED!")
        
        # Clean up the temporary .out file so your hdl folder stays clean
        temp_path = os.path.join(proj_name, out_file)
        if os.path.exists(temp_path):
            os.remove(temp_path)

# --- MAIN LOOP ---
if __name__ == "__main__":
    print("=== PROFESSIONAL AI RTL GENERATOR ===")
    while True:
        request = input("\n[Q] Enter module requirement (or 'exit'): ")
        if request.lower() == 'exit': 
            break
        
        # Step 1: Generate Raw Text (May contain multiple modules)
        raw_response = generate_rtl(request)
        if not raw_response: 
            continue
        
        # Create a base project folder named after the first module found
        first_mod_match = re.search(r"module\s+(\w+)", raw_response)
        base_name = first_mod_match.group(1) if first_mod_match else "Multi_Module"
        proj_name = f"{base_name}_Project"
        
        # Step 2: Extract and Save ALL modules into separate files
        saved_modules = extract_and_save_modules(raw_response, proj_name)
        
        # Step 3: Compile EACH file with Icarus Verilog
        for mod in saved_modules:
            check_syntax(proj_name, mod)
        
        # Step 4: Safety Pause
        print("⏳ Waiting a moment for API cooling...")
        time.sleep(3)
