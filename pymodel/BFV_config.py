# BFV_config.py
import numpy as np
from generic_math import is_prime, is_t_minus_1_multiple_of_2n, batch_encode_decode_matrices, is_power_of_2
import math

class BFVSchemeConfiguration:
    def __init__(self, base: int, t: int, q: int, n: int, ternary: bool = True):
        """
        :param t: Plaintext modulus (prime or power of prime)
        :param q: Ciphertext modulus (t divides q, q much larger than t)
        :param n: Degree of polynomial + 1
        :param ternary: If true, secret key is ternary {-1,0,1}, else binary {0,1}
        """
        self.base = base
        self.t = int(t)
        assert is_prime(self.t), "plaintext modulus t must be prime"
        self.q = int(q)
        self.n = int(n)
        assert is_power_of_2(n), "n should be a power of 2"
        assert is_t_minus_1_multiple_of_2n(self.t,self.n), "t-1 must be a multiple of 2n"
        self.ternary = ternary
        self.Delta = q // t
        assert self.Delta%2==0, "q must be an even multiple of t"
        self.Q = self.q * self.Delta
        self.num_digits = math.ceil(math.log(self.Q) / math.log(self.base))
        # get encode/decode matrices
        self._E , self._WT = batch_encode_decode_matrices(n,t)
    
    def is_A_valid(self, A) -> bool:
        """
        Checks that A is a "n" long array of integers modulo q
        """
        # Must be length n
        if not isinstance(A, np.ndarray):
            raise TypeError("A must be a numpy array")
        if len(A) != self.n:
            return False
        if not np.all((0 <= A) & (A < self.q)):
            return False
        return True
    
    def validate_A(self, A):
        if not self.is_A_valid(A):
            raise ValueError("the passed A is not valid for this BFV configuration")
    
    def is_B_valid(self, B) -> bool:
        """
        Checks that B is an n-length array of integers modulo q
        """
        if not isinstance(B, np.ndarray):
            raise TypeError("B must be a numpy array")
        if len(B) != self.n:
            return False
        if not np.all((0 <= B) & (B < self.q)):
            return False
        return True
    
    def validate_B(self, B):
        if not self.is_B_valid(B):
            raise ValueError("the passed B is not valid for this BFV configuration")
    
    def validate_AB(self, A, B):
        self.validate_A(A)
        self.validate_B(B)
    
    def _naive_polynomial_mult_nomod(self, a_in: np.ndarray, b_in: np.ndarray) -> np.ndarray:
        """Compute a*b mod x^n+1 naively (without NTT)"""
        # self.validate_AB(a_in,b_in)
        n = len(a_in)
        cconv = np.convolve(a_in, b_in)
        # compute c mod x^n+1
        res = np.zeros(n, dtype=cconv.dtype)
        for i in range(len(cconv)):
            if i < n:
                res[i] += cconv[i]
            else:
                # Wrap and negate!
                res[i - n] -= cconv[i]
        return res
    
    def polynomial_mult_nomod(self, a_in: np.ndarray, b_in: np.ndarray) -> np.ndarray:
        return self._naive_polynomial_mult_nomod(a_in,b_in)
    
    def batch_encode(self, v: np.ndarray) -> np.ndarray:
        assert len(v)==self.n, "integer vector bad length"
        vcol = v.reshape(self.n, 1)
        m  = (self._E @ vcol) % self.t
        m = m.flatten()
        nooverflow_m = m.astype(object)
        return nooverflow_m
    
    def batch_decode(self, m: np.ndarray) -> np.ndarray:
        assert len(m)==self.n, "plaintext bad length"
        mcol = m.reshape(self.n, 1)
        v = (self._WT @ mcol) % self.t
        return v.flatten()

