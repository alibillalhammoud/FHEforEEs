# 598_FHE_Research_Project
## Quickstart
To reproduce the content in the report you can follow these steps:
- **Base Conversions Working**: cd into "rtl" directory and run `make run-fastBConvEx`, `make run-fastBConv`, `make run-modSwitch`
- **Overall python model simulating sensor processing**: cd into "pymodel" and run `python run.py --enable_sensor_proc_test`
    - ensure python depedencies are installed from [requirements.txt](pymodel/requirements.txt). You can do this with `python3 -m pip install -r requirements.txt`
    - We use seed=123 with python random to generate same scheme each time, you can remove this to generate any scheme and run `python3 run.py --op all` for more testing
- **Overall RLT simulating sensor processing**: We are passing ctpt add, ctct add, & ctpt mul. You can see these results by running `make run-cpu` in the RTL directory. You can also run the ctct mul testbench which is currently failing by running 

## Directory Structure  
├── pymodel  
│...├── BFV_config.py  
│...├── BFV_model.py  
│...├── generic_math.py  
│...├── ntt_friendly_prime.py  
│...├── ntt_parameter_gen.py  
│...├── old_noRNS  
│...│...├── [directory containing implementation of nonRNS python model]  
│...├── requirements.txt  
│...└── run.py  
├── README.md  
├── rtl                                     #  RTL Verilog source  
....├── Makefile  
....├── run_all_working_testbenches.bash    # `bash run_all_working_testbenches.bash`  runs every working testbench
....├── Test  
....│...├── cpu_test_ctctmul.sv  
....│...├── cpu_test.sv                     # main working testbench for CPU running ctpt add, ctct add, & ctpt mul  
....│...├── ct_test_inputs.svh  
....│...├── tb_big.sv  
....│...├── tb_fastBConvEx_BBa_to_q.sv      # working exact fast base conversion testbench  
....│...├── tb_fastBconv.sv                 # working fast base conversion testbench  
....│...├── tb_full_mult.sv  
....│...├── tb_modSwitch_qBBa_to_BBa.sv     # working modswitch base conversion testbench   
....│...└── tb_regfile.sv  
....└── Verilog  
........├── adder.sv  
........├── cpu.sv  
........├── fastBConvEx_BBa_to_q.sv  
........├── fastBConv.sv  
........├── modSwitch_qBBa_to_BBa.sv  
........├── mult.sv  
........├── ntt_butterfly.sv  
........├── ntt_full.sv  
........├── regfile.sv  
........└── types.svh                       # contains scheme LUT parameters for NTT, base conversions, etc 



## Python Reference Implementation of the BFV Homomorphic Encryption Scheme
This repository provides a Python model of the Brakerski/Fan-Vercauteren (BFV) homomorphic encryption scheme, designed as a correctness and debug helper for hardware (RTL Verilog) implementation.

### Python Files
Python implementation provides a reference for the hardware design  
* `generic_math.py`: General math functions needed (e.g. generate vandermode matrices, uniform random numbers, bit reversal, etc)
* `BFV_config.py`: Manage BFV parameters and functions which are shared publicly between the client and server (t, q, n, batch encode/decode functionality, etc)
* `BFV_model.py`: Implements `BFVSchemeClient` class (handling encrypt/decrypt) and `BFVSchemeServer` class handling encrypted computations (ct/ct and ct/pt add&multiply)
* `ntt_friendly_prime.py`: generate primes for hardware friendly NTT
* `ntt_parameter_gen.py`: generate the twiddle factors for hardware NTT
* `run.py`: Runs a test case or other scenarios using the BFV framework

### Running

Usage  
1. Clone the repo.
2. Enter the pymodel/ directory.
3. Install dependencies `python3 -m pip install -r requirments.txt`
4. Run the example `python3 run.py --enable_sensor_proc_test`


