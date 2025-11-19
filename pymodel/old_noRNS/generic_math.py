# generic_math.py
import sympy
import numpy as np
import math
import random

def is_prime(x) -> bool:
    return bool(sympy.isprime(x))

def is_power_of_2(n) -> bool:
    """Return True if n is a power of 2, False otherwise."""
    if n <= 0:
        return False
    return (n & (n - 1)) == 0

def is_t_minus_1_multiple_of_2n(t, n) -> bool:
    if n == 0:
        raise ValueError("n must be non-zero")
    return (t - 1) % (2 * n) == 0

def bit_reverse_perm(n):
    bits = int(math.log2(n))
    return [int(f"{i:0{bits}b}"[::-1], 2) for i in range(n)]

def batch_encode_decode_matrices(n: int, t: int) -> tuple[np.ndarray,np.ndarray]:
    """returns a tuple with [0] encode matrix and [1] decode matrix"""
    assert is_prime(t) and (t - 1) % (2 * n) == 0, "bad modulus"
    # build W_transpose  (decoding)  and  E = (W_transpose)^-1  (encoding) matrices
    g      = sympy.primitive_root(t)
    omega  = pow(g, (t - 1) // (2 * n), t) # primitive 2n-th root
    alpha  = np.array([pow(omega, 2 * k + 1, t) for k in range(n)], dtype=object)
    # Vandermonde in increasing powers:   (row i, col j) = α_i^j   (mod t)
    W_T = np.vander(alpha, N=n, increasing=True) % t # (n x n)
    # inverse with SymPy (modular)
    E   = np.array(sympy.Matrix(W_T.tolist()).inv_mod(t).tolist(), dtype=object)
    return E, W_T

def gen_uniform_rand_arr(lower_bound: int, upper_bound: int, size: int):
    """Generate a 1d np.array of length=size of uniform random numbers [lower_bound, upper_bound)
    upper_bound can be much larger than int64 becuase returned array is Object type
    """
    n = int(size)
    q = int(upper_bound)
    lb = int(lower_bound)
    # Create a list of n random integers in [0, q)
    data = [random.randrange(lb, q) for _ in range(n)]
    # Convert to np.array with dtype object so Python ints are preserved
    return np.array(data, dtype=object)

def nparr_int_round(dividend: np.ndarray, divisor: int) -> np.ndarray:
    """
    Return np.array of nearest‐integer rounding of dividend/divisor without using floating point,
    where dividend is an np.array(dtype=object) and divisor is a positive Python int.
    """
    divisor = int(divisor)
    assert divisor > 0 and divisor%2==0, "divisor must be positive and even number"
    half = divisor >> 1
    return (dividend+half) // divisor
