# BFV_model.py
import numpy as np
from BFV_config import BFVSchemeConfiguration
from generic_math import gen_uniform_rand_arr, nparr_int_round
import math

class BFVSchemeClient:
    def __init__(self, config: BFVSchemeConfiguration):
        """
        :param config: the BFV scheme configuration containing all required parameters and settings
        """
        assert isinstance(config, BFVSchemeConfiguration)
        self.config = config
        # Secret key: polynomial degree n-1, n coefficients in {-1,0,1} or {0,1}
        if config.ternary:
            self._S = np.random.choice([-1, 0, 1], size=config.n) % config.q # in practice you need to take this mod q (at least I think)
        else:
            self._S = np.random.choice([0, 1], size=config.n)

    def polynomial_mul(self, A, B):
        return self.config.polynomial_mult_nomod(A,B)
    
    def compute_rlev(self):
        rlev_ciphertexts = []

        S_2 = self.polynomial_mul(self._S, self._S)
        for i in range(self.config.num_digits):
            # Gadget factor: Q/β^i
            gadget_plaintext = ((self.config.base ** i) * S_2.astype(object)) % self.config.Q

            A = gen_uniform_rand_arr(0, self.config.Q, size=self.config.n)
            
            E = np.round(np.random.normal(0, 1, size=self.config.n)).astype(int)
            
            negAS = -self.polynomial_mul(A, self._S)
            B = (negAS + gadget_plaintext + E) % self.config.Q
            
            rlev_ciphertexts.append((A, B))
        
        return rlev_ciphertexts

    def encrypt(self, P: np.ndarray):
        """
        Encrypts plaintext P (integers mod t, length n).
        Returns tuple (A, B) where:
            A: size n, each row is a public polynomial mod q.
            B: size n, the result poly mod q.
        """
        # Message encoding
        M = self.config.batch_encode(np.array(P).flatten() % self.config.t)
        DeltaM = (M * self.config.Delta) % self.config.q            # size n
        # random A (public key), n coefficients mod q, size n
        A = gen_uniform_rand_arr(0, self.config.q, size=self.config.n)
        # small noise E (centered discrete gaussian)
        E = np.round(np.random.normal(0, 1, size=self.config.n)).astype(int)
        # B = -A*S + DeltaM + E, all mod q, S is persistent secret key
        negAS = -self.polynomial_mul(A, self._S)
        B = (negAS + DeltaM + E) % self.config.q
        # return encryption result
        return A, B

    def decrypt(self, A, B):
        self.config.validate_AB(A,B)
        inverseu  = (B + self.polynomial_mul(A, self._S)) % self.config.q
        # centre-lift to (-q/2 , q/2]
        mask = inverseu > self.config.q // 2 # Boolean array
        inverseu[mask] -= self.config.q
        m_scaled = nparr_int_round(inverseu, self.config.Delta)
        m = m_scaled % self.config.t # remove Delta and reduce
        decode_v = self.config.batch_decode(m)
        return decode_v


class BFVSchemeServer:
    def __init__(self, config: BFVSchemeConfiguration):
        self.config = config

    # helper function
    def polynomial_mul(self, A, B):
        return self.config.polynomial_mult_nomod(A,B)

    def add_ciphercipher(self, A1,B1,A2,B2):
        # error checking
        self.config.validate_AB(A1,B1)
        self.config.validate_AB(A2,B2)
        # add
        Anew = (A1+A2) % self.config.q
        Bnew = (B1+B2) % self.config.q
        return Anew, Bnew
    
    def add_cipherplain(self, A1, B1, P2):
        Bnew = (B1 + (self.config.Delta * self.config.batch_encode(P2))) % self.config.q
        return A1, Bnew
    
    def mul_cipherplain(self, A1, B1, P2):
        encoding = self.config.batch_encode(P2)
        Anew = self.polynomial_mul(A1, encoding) % self.config.q
        Bnew = self.polynomial_mul(B1, encoding) % self.config.q
        return Anew, Bnew

    def gadget_decomposition(self, value):
        decomp = []
        temp = value % self.config.Q
        for _ in range(self.config.num_digits):
            digit = (temp % self.config.base)

            temp = temp // self.config.base
            
            decomp.append(digit)
        return decomp
    
    def relinearization(self, D0, D1, D2, RLev):
        ctaA = D1
        ctaB = D0
        ctbA = np.zeros_like(D2)
        ctbB = np.zeros_like(D2)

        #Gadget decomp
        D2_decomp = np.array([self.gadget_decomposition(coeff) for coeff in D2])

        # Inner product of Decomp and RLev
        for i in range(self.config.num_digits):

            # Get the i-th decomposition component of D2
            D2_i = D2_decomp[:, i]

            RLevA, RLevB = RLev[i]
        
            ctbA += self.polynomial_mul(D2_i, RLevA)
            ctbB += self.polynomial_mul(D2_i, RLevB)
        
        ctbA = ctbA % self.config.Q
        ctbB = ctbB % self.config.Q

        ctA = ctaA + ctbA
        ctB = ctaB + ctbB
        return ctA, ctB
    
    def mul_ciphercipher(self, A1, B1, A2, B2, RLev):
        # error checking
        self.config.validate_AB(A1,B1)
        self.config.validate_AB(A2,B2)

        D0 = self.polynomial_mul(B1,B2) % self.config.Q
        D1 = (self.polynomial_mul(B2,A1) + self.polynomial_mul(B1,A2)) % self.config.Q
        D2 = self.polynomial_mul(A1,A2) % self.config.Q

        #Relinerization
        ctA, ctB = self.relinearization(D0, D1, D2, RLev)

        # Rescaling
        Anew = (ctA // self.config.Delta) % self.config.q
        Bnew = (ctB // self.config.Delta) % self.config.q
        return Anew, Bnew

