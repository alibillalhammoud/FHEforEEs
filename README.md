# BFV Homomorphic Encryption Scheme for Non-Cryptographers (Especially Electrical Engineers)
This repository provides a Python model and partial RTL implementation of the Brakerski/Fan-Vercauteren (BFV) homomorphic encryption scheme, designed to help electrical engineers (and non-cryptographers) understand FHE. **DISCLAIMER** We are NOT cryptographers and we did NOT consult a cryptography expert in the making of this project.  
We did this work as part of a University project. As electrical engineers, we found it difficult to understand FHE at the level required to implement hardware acceleration. Although we were not able to complete RTL in the short time we worked on the project (and **the RTL we wrote is not optimized for real world**), we believe our contribution can help explain the algorithm.  
The most helpful resource was the open-source fhetextbook [here](https://fhetextbook.github.io/) and [here](https://github.com/fhetextbook/fhetextbook.github.io).

We also include pdf/slides to explain the algorithm to the EE who needs enough info to implement **[WIP 50% done]**. Note, we did not implement boot-strapping.

Additionally, we include real hardware tips for the EE who may want to do this in the future. The main challenge you will face with real implementation is memory. Because the algorithm is heavy on SIMD processing, a very efficient implementation can be done with limited data movements. We had some idea for the pipeline and memory, but ran out of time (still do not have correctness on everything). Furthermore, our controller implementation is very crude and we have some suggestions on how to the pipeline smaller (area & power) to make it more efficient.

### Python Files
Python implementation provides a reference for the hardware design  
* `generic_math.py`: General math functions needed (e.g. generate vandermode matrices, uniform random numbers, bit reversal, etc)
* `BFV_config.py`: Manage BFV parameters and functions which are shared publicly between the client and server (t, q, n, batch encode/decode functionality, etc)
* `BFV_model.py`: Implements `BFVSchemeClient` class (handling encrypt/decrypt) and `BFVSchemeServer` class handling encrypted computations (ct/ct and ct/pt add&multiply)
* `ntt_friendly_prime.py`: generate primes for hardware friendly NTT
* `ntt_parameter_gen.py`: generate the twiddle factors for hardware NTT
* `run.py`: Runs a test case or other scenarios using the BFV framework


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
....├── test  
....│...├── cpu_test_ctctmul.sv  
....│...├── cpu_test.sv                     # main working testbench for CPU running ctpt add, ctct add, & ctpt mul  
....│...├── ct_test_inputs.svh  
....│...├── tb_big.sv  
....│...├── tb_fastBConvEx_BBa_to_q.sv      # working exact fast base conversion testbench  
....│...├── tb_fastBConv.sv                 # working fast base conversion testbench  
....│...├── tb_full_mult.sv  
....│...├── tb_modSwitch_qBBa_to_BBa.sv     # working modswitch base conversion testbench   
....│...└── tb_regfile.sv  
....└── verilog  
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



