import numpy as np
import random
import argparse
import math

from BFV_config import BFVSchemeConfiguration
from BFV_model import BFVSchemeClient, BFVSchemeServer

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

def main():
    parser = argparse.ArgumentParser(
        description='Test BFV homomorphic encryption operations with configurable options.'
    )
    parser.add_argument('--t', type=int, default=257,
                        help='Plaintext modulus (prime number), default: 257')
    parser.add_argument('--n', type=int, default=128,
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

    args = parser.parse_args()

    # Setup
    config = BFVSchemeConfiguration(args.t, args.qbits, args.n, False)
    client = BFVSchemeClient(config)
    server = BFVSchemeServer(config)
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

if __name__ == "__main__":
    main()