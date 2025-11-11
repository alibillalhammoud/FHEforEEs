# BFV_model.py
import numpy as np
from BFV_config import BFVSchemeConfiguration

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
        A = np.random.randint(0, self.config.q, size=self.config.n)
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
        inverseu = inverseu.astype(int)
        # centre-lift to (-q/2 , q/2]
        mask = inverseu > self.config.q // 2 # Boolean array
        inverseu[mask] -= self.config.q
        m_scaled = np.round(inverseu / self.config.Delta).astype(int)  # now ~ M
        m = m_scaled % self.config.t # remove Delta and reduce
        return self.config.batch_decode(m)


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


