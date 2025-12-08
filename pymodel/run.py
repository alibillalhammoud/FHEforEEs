import numpy as np
import random
import argparse
import math

from BFV_config import BFVSchemeConfiguration
from BFV_model import BFVSchemeClient, BFVSchemeServer
from generic_math import polynomial_RNSmult_constant

random.seed(123)
np.random.seed(123)

def parse_vector(string):
    try:
        return np.array([int(s.strip()) for s in string.split(',')])
    except Exception as e:
        raise argparse.ArgumentTypeError(
            f"Could not parse vector from '{string}', error: {e}"
        )

def plaintext_op(op, v1, v2, pt, t):
    """Perform the plaintext equivalent operation."""
    if op == 'add_cipherplain':
        return (v1 + pt) % t
    elif op == 'add_ciphercipher':
        return (v1 + v2) % t
    elif op == 'mul_cipherplain':
        return (v1 * pt) % t
    elif op == 'mul_ciphercipher':
        return (v1 * v2) % t
    else:
        raise ValueError(f"Unknown operation {op}")

def run_test(op, client, server, v1, v2, pt, t, rlev):
    # Encrypt messages
    cipher1 = client.encrypt(v1)
    cipher2 = client.encrypt(v2)
    A1, B1 = cipher1
    A2, B2 = cipher2

    # Run selected test
    if op == 'add_cipherplain':
        computed_cipher = server.add_cipherplain(A1, B1, pt)
    elif op == 'add_ciphercipher':
        computed_cipher = server.add_ciphercipher(A1, B1, A2, B2)
    elif op == 'mul_cipherplain':
        computed_cipher = server.mul_cipherplain(A1, B1, pt)
    elif op == 'mul_ciphercipher':
        computed_cipher = server.mul_ciphercipher(A1, B1, A2, B2, rlev)
    else:
        raise ValueError(f"Unknown operation {op}")

    Ao, Bo = computed_cipher
    decrypted = client.decrypt(Ao, Bo)

    # Plaintext reference computation
    plain_result = plaintext_op(op, v1, v2, pt, t)
    success = np.all(decrypted == plain_result)
    print(f"===== {op} =====")
    print("Decrypted result:", decrypted)
    print("Plaintext computation:", plain_result)
    print("Test PASSED!" if success else "Test FAILED!")
    print()

def generate_test_vectors(n, low=0, high=100):
    """Generate random test vectors of given length n."""
    v1 = np.random.randint(low, high, size=n)
    v2 = np.random.randint(low, high, size=n)
    pt = np.random.randint(low, high, size=n)
    return v1, v2, pt


def as_sv_array(name: str, residuesin, lenname: str):
    arr = [[element for element in row.residues] for row in residuesin]
    rows = []
    for row in arr:
        rows.append("'{" + ", ".join(str(x) for x in row) + "}")
    body = ",\n    ".join(rows)
    return (f"const rns_residue_t {name} [`N_SLOTS][{lenname}] = '{{\n"
            f"    {body}\n}};\n")


def main():
    parser = argparse.ArgumentParser(
        description='Test BFV homomorphic encryption operations with configurable options.'
    )
    parser.add_argument('--t', type=int, default=257,
                        help='Plaintext modulus (prime number), default: 257')
    parser.add_argument('--n', type=int, default=64,
                        help='Polynomial degree (power of 2), default: 128')
    parser.add_argument('--qbits', type=int, default=300,
                        help='Bit-length of ciphertext modulus q, default: 290')
    parser.add_argument('--vector1', type=parse_vector,
                        default=None,
                        help='First input vector (comma-separated). If omitted, random test vector is generated.')
    parser.add_argument('--vector2', type=parse_vector,
                        default=None,
                        help='Second input vector (comma-separated). If omitted, random test vector is generated.')
    parser.add_argument('--plaintext', type=parse_vector,
                        default=None,
                        help='Plaintext vector for plaintext ops. If omitted, random test vector is generated.')
    parser.add_argument('--op', choices=[
        'add_cipherplain', 'add_ciphercipher', 'mul_cipherplain', 'mul_ciphercipher', 'all'
    ], default='mul_ciphercipher',
    help='Test operation to perform (or "all" for all)')
    parser.add_argument('--enable_sensor_proc_test', action='store_true', help='Enable a specific feature')

    args = parser.parse_args()

    # Setup
    config = BFVSchemeConfiguration(args.t, args.qbits, args.n, False)
    client = BFVSchemeClient(config)
    server = BFVSchemeServer(config)
    if not args.enable_sensor_proc_test:
        # Print current config in verilog format
        config.print_verilog_format()
        # Generate test arrays of length n if vectors not supplied
        if args.vector1 is None or args.vector2 is None or args.plaintext is None:
            v1, v2, pt = generate_test_vectors(args.n,low=0,high=args.t)
        else:
            # Make sure input vectors have the correct length, resize or pad if necessary
            def fix_len(v):
                v = np.array(v)
                if v.size < args.n:
                    # Pad with zeros
                    return np.pad(v, (0, args.n-v.size))
                elif v.size > args.n:
                    # Trim the vector
                    return v[:args.n]
                else:
                    return v
            v1 = fix_len(args.vector1)
            v2 = fix_len(args.vector2)
            pt = fix_len(args.plaintext)

        ops = ['add_cipherplain', 'add_ciphercipher', 'mul_cipherplain', 'mul_ciphercipher'] if args.op == 'all' else [args.op]

        for op in ops:
            run_test(op, client, server, v1, v2, pt, args.t, client.relin_keys)
    
    # run the IoT application test (all the ops together)
    else:
        PRINT_INTERMEDIATES = True
        PRINT_VERILOGTESTINS = False
        qlenmacro = "`q_BASIS_LEN"
        # Generate temperature and humidity readings for n sensors (must be smaller than 257)
        temp_readings = np.random.randint(15, 36, size=args.n)
        humidity_readings = np.random.randint(20, 71, size=args.n)
        # Calibration vector, could be negative for offset  (must be smaller than 257)
        calibration = np.random.randint(-2, 3, size=args.n)
        # Encrypt inputs
        temp_enc = client.encrypt(temp_readings)
        humidity_enc = client.encrypt(humidity_readings)
        #
        # create a test_inputs file for the cpu
        if PRINT_VERILOGTESTINS:
            print(as_sv_array("A1__INPUT" , temp_enc[0] , qlenmacro))
            print(as_sv_array("B1__INPUT", temp_enc[1], qlenmacro))
            print(as_sv_array("A2__INPUT" , humidity_enc[0] , qlenmacro))
            print(as_sv_array("B2__INPUT", humidity_enc[1], qlenmacro))
            #
            unscaledPT = config.encode_integers_with_RNS(config.batch_encode(calibration))
            scaledPT = polynomial_RNSmult_constant(constant=config.Delta, polyRNScoeffs=unscaledPT)
            print(as_sv_array("PLAIN__TEXT" , unscaledPT , qlenmacro))
            print(as_sv_array("PLAIN__TEXTSCALED_FORADD", scaledPT, qlenmacro))
        if PRINT_INTERMEDIATES:
            print("Simulated Temperatures:", temp_readings)
            print("Simulated Humidity:", humidity_readings)
            print("Simulated Calibrations:", calibration)
        # xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        # temp + humidity (ctct add)
        aggregate_score_cipher = server.add_ciphercipher(*temp_enc, *humidity_enc)
        if PRINT_VERILOGTESTINS:
            print(as_sv_array("CTCT_ADDA__GOLDRES", aggregate_score_cipher[0], qlenmacro))
            print(as_sv_array("CTCT_ADDB__GOLDRES", aggregate_score_cipher[1], qlenmacro))
        if PRINT_INTERMEDIATES:
            aggregate_score = client.decrypt(*aggregate_score_cipher)
            print("Aggregate score (decrypted):", aggregate_score)
            print("Plain reference:", (temp_readings + humidity_readings) % args.t)
        # xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        # Calibrated temperature (ctpt add)
        calibrated_temp_cipher = server.add_cipherplain(*temp_enc, calibration)
        if PRINT_VERILOGTESTINS:
            print(as_sv_array("PTCT_ADDB__GOLDRES", calibrated_temp_cipher[1], qlenmacro))
        if PRINT_INTERMEDIATES:
            calibrated_temp = client.decrypt(*calibrated_temp_cipher)
            print("Calibrated temp (decrypted):", calibrated_temp)
            print("Plain reference:", (temp_readings + calibration) % args.t)
        # xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        # scale temperature (ctptmul)
        scale_cipher = server.mul_cipherplain(*temp_enc, calibration)
        if PRINT_VERILOGTESTINS:
            print(as_sv_array("PTCT_MULA__GOLDRES", scale_cipher[0], qlenmacro))
            print(as_sv_array("PTCT_MULB__GOLDRES", scale_cipher[1], qlenmacro))
        if PRINT_INTERMEDIATES:
            decrypted_scale_result = client.decrypt(*scale_cipher)
            print("Scaled temp (decrypted):", decrypted_scale_result)
            plain_result = (temp_readings * calibration) % args.t
            print("Plain reference:", plain_result)
            success = np.all(decrypted_scale_result == plain_result)
            print(success)
        # xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        # Product temp * humidity (ctctmul)
        product_cipher = server.mul_ciphercipher(*temp_enc, *humidity_enc, client.relin_keys)
        if PRINT_VERILOGTESTINS:
            print(as_sv_array("CTCT_MULA__GOLDRES", product_cipher[0], qlenmacro))
            print(as_sv_array("CTCT_MULB__GOLDRES", product_cipher[1], qlenmacro))
        if PRINT_INTERMEDIATES:
            product_result = client.decrypt(*product_cipher)
            print("Product (temp * humidity) decrypted:", product_result)
            print("Plain reference:", (temp_readings * humidity_readings) % args.t)



if __name__ == "__main__":
    main()