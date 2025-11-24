import numpy as np
import random
import argparse

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

def main():
    parser = argparse.ArgumentParser(
        description='Test BFV homomorphic encryption operations with configurable options.'
    )
    parser.add_argument('--t', type=int, default=257,
                        help='Plaintext modulus (prime number), default: 257')
    parser.add_argument('--n', type=int, default=8,
                        help='Polynomial degree (power of 2), default: 8')
    parser.add_argument('--qbits', type=int, default=150,
                        help='Bit-length of ciphertext modulus q, default: 150')
    parser.add_argument('--vector1', type=parse_vector,
                        default='1,2,3,4,5,6,7,8',
                        help='First input vector (comma-separated), default: 1,2,3,4,5,6,7,8')
    parser.add_argument('--vector2', type=parse_vector,
                        default='2,3,4,5,4,3,2,3',
                        help='Second input vector (comma-separated), default: 2,3,4,5,4,3,2,3')
    parser.add_argument('--plaintext', type=parse_vector,
                        default='1,2,3,4,5,6,7,8',
                        help='Plaintext vector for plaintext ops, default: 1,2,3,4,5,6,7,8')
    parser.add_argument('--op', choices=[
        'add_cipherplain', 'add_ciphercipher', 'mul_cipherplain', 'mul_ciphercipher', 'all'
    ], default='mul_ciphercipher',
    help='Test operation to perform (or "all" for all)')

    args = parser.parse_args()

    # Setup
    config = BFVSchemeConfiguration(args.t, args.qbits, args.n, False)
    client = BFVSchemeClient(config)
    server = BFVSchemeServer(config)
    rlev = client.relin_keys

    ops = ['add_cipherplain', 'add_ciphercipher', 'mul_cipherplain', 'mul_ciphercipher'] if args.op == 'all' else [args.op]

    for op in ops:
        run_test(op, client, server, args.vector1, args.vector2, args.plaintext, args.t, rlev)

if __name__ == "__main__":
    main()