import numpy as np
from BFV_config import BFVSchemeConfiguration


def naive_polynomial_mult_nomod(config: BFVSchemeConfiguration, a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Compute a*b mod x^n+1 naively (without NTT)"""
    config.validateAB(a,b)
    n = len(a)
    c = np.convolve(a, b)
    # compute c mod x^n+1
    c_mod = c[:n].copy()
    for k in range(n, len(c)):
        c_mod[k-n] -= c[k]
    # if you want mod uncomment this line
    #c_mod %= config.q
    return c_mod


polynomial_mult_nomod = naive_polynomial_mult_nomod
