import numpy as np
from BFV_config import BFVSchemeConfiguration

# naive multiplication
n = len(a)
c = np.convolve(a, b)
c_mod = c[:n].copy()
for k in range(n, len(c)):
    c_mod[k-n] -= c[k]
c_mod %= q


def naive_polynomial_mult(config: BFVSchemeConfiguration, a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Compute a*b mod x^n+1 naively (without NTT)"""
    config.validateAB(a,b)
    n = len(a)
    c = np.convolve(a, b)
    c_mod = c[:n].copy()
    for k in range(n, len(c)):
        c_mod[k-n] -= c[k]
    # coefficients are mod q
    c_mod %= config.q
    return c_mod
