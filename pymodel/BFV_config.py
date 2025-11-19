# BFV_config.py
import numpy as np
from generic_math import is_prime, is_t_minus_1_multiple_of_2n, batch_encode_decode_matrices, is_power_of_2, gen_RNS_basis, RNSInteger, compute_CRT_coefficients
import math
import copy

class BFVSchemeConfiguration:
    def __init__(self, t: int, desired_q_numbits: int, n: int, ternary: bool = True):
        """
        :param t: Plaintext modulus (prime or power of prime)
        :param desired_q_numbits: Ciphertext modulus (t divides q, q much larger than t)
        :param n: Degree of polynomial + 1
        :param ternary: If true, secret key is ternary {-1,0,1}, else binary {0,1}
        """
        # plaintext modulus
        self.t = int(t)
        assert is_prime(self.t), "plaintext modulus t must be prime"
        # num SIMD slots
        self.n = int(n)
        assert is_power_of_2(n), "n should be a power of 2"
        assert is_t_minus_1_multiple_of_2n(self.t,self.n), "t-1 must be a multiple of 2n" # helps with NTT
        # calculate an appropriate ct modulus (q), then get scaling factor (delta) and large mod (Q)
        # also init RNS
        desired_q_numbits = int(desired_q_numbits)
        approx_q_size = 2**desired_q_numbits
        self.RNS_basis_q = gen_RNS_basis(lower_bound=approx_q_size, max_residue_size=2**64, multiple_of=[self.t])
        self.RNS_CRT_coeffs_q = compute_CRT_coefficients(self.RNS_basis_q)
        self.q = np.prod(self.RNS_basis_q)
        assert self.q % self.t==0, "q must be a multiple of t"
        self.Delta = self.q // self.t
        # (I think this is impossible actually!) assert self.Delta%2==0, "q must be an even multiple of t"
        self.Q = self.q * self.Delta
        self.RNS_basis_qB = gen_RNS_basis(lower_bound=self.Q, max_residue_size=2**64, multiple_of=self.RNS_basis_q)
        self.RNS_basis_qBBa = gen_RNS_basis(lower_bound=self.Q*self.Delta, max_residue_size=2**64, multiple_of=self.RNS_basis_qB)
        self.qBBa = np.prod(self.RNS_basis_qBBa)
        #qmask = np.isin(self.RNS_basis_qBBa, self.RNS_basis_q)
        #self.RNS_basis_BBa = self.RNS_basis_qBBa[~qmask]
        #raise ValueError("you need to check that self.RNS_basis_BBa is a bunch of python ints (not numpy ints)")
        # get encode/decode matrices
        self._E , self._WT = batch_encode_decode_matrices(n,t)
        # secret key setting
        self.ternary = bool(ternary)
    
    def is_AorB_valid(self, AorB) -> bool:
        """
        Checks that A or B is a "n" long array of integers modulo q
        """
        A = AorB
        if not isinstance(A, np.ndarray):
            raise TypeError("A and B must be numpy arrays")
        if len(A) != self.n:
            return False
        if not all([isinstance(cmp,RNSInteger) and cmp.modulus==self.q for cmp in A]):
            return False
        return True
    
    def validate_AorB(self, AorB):
        if not self.is_AorB_valid(AorB):
            raise ValueError("the passed A or B is not valid for this BFV configuration")
    
    def validate_AB(self, A, B):
        self.validate_AorB(A)
        self.validate_AorB(B)
    
    def _naive_polynomial_mult_nomod(self, a_in: np.ndarray, b_in: np.ndarray) -> np.ndarray:
        """Compute a*b mod x^n+1 naively (without NTT)"""
        # error checks
        n = len(a_in)
        RNSin = bool(isinstance(a_in[0],RNSInteger))
        # convolution
        cconv = np.convolve(a_in, b_in)
        # create result polynomial
        assert (not(RNSin)) or isinstance(cconv[0],RNSInteger), "convolution result must be in RNS representation"
        if RNSin:
            modelRNS = cconv[0]
            res = np.array([RNSInteger(0,modelRNS.basis,modelRNS.modulus) for i in range(n)], dtype=object)
        else:
            res = np.zeros(n, dtype=cconv.dtype)
        # compute c mod x^n+1
        for i in range(len(cconv)):
            if i < n:
                res[i] += cconv[i]
            else:
                # Wrap and negate
                res[i - n] -= cconv[i]
        return res
    
    def polynomial_mult_nomod(self, a_in: np.ndarray, b_in: np.ndarray) -> np.ndarray:
        return self._naive_polynomial_mult_nomod(a_in,b_in)
    
    def encode_integers_with_RNS(self, ints_in: np.ndarray) -> np.ndarray:
        """takes an np.ndarray of integers and returns an np.ndarray of RNSIntegers"""
        rns_encoded_ints = [RNSInteger(x,self.RNS_basis_q) for x in ints_in.flatten()]
        return np.array(rns_encoded_ints, dtype=object)
    
    def convert_RNS_backto_integers(self, RNS_in: np.ndarray) -> np.ndarray:
        """takes an np.ndarray of RNSIntegers and returns an np.ndarray of ints"""
        plain_ints = [int(x) for x in RNS_in.flatten()]
        return np.array(plain_ints, dtype=object)
    
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

