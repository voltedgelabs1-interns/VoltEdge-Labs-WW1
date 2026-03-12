from openai import OpenAI
import os

client = OpenAI(api_key="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")

PROMPTS = {
    "UART": "Generate synthesizable Verilog code for a UART transmitter with 8-bit data and 9600 baud rate.",
    "SPI": "Generate synthesizable Verilog code for an SPI Master with MOSI, MISO, SCLK and CS.",
    "I2C": "Generate synthesizable Verilog code for an I2C controller with SDA and SCL."
}

os.makedirs("generated_rtl", exist_ok=True)

print("\nAI RTL Generator")
print("----------------")

print("Available modules:")
for module in PROMPTS:
    print("-", module)

module_type = input("\nEnter module type: ").upper()

if module_type not in PROMPTS:
    print("Invalid module")
    exit()

prompt = PROMPTS[module_type]

print("\nGenerating RTL...\n")

response = client.responses.create(
    model="gpt-5-nano",
    input=prompt
)

# Extract generated text safely
verilog_code = ""

for item in response.output:
    if item.type == "message":
        for content in item.content:
            if content.type == "output_text":
                verilog_code += content.text

filename = f"generated_rtl/{module_type.lower()}.v"

with open(filename, "w") as f:
    f.write(verilog_code)

print(f"RTL generated successfully: {filename}")