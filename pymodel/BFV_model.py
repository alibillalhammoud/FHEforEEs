# BFV_model.py
import numpy as np
from BFV_config import BFVSchemeConfiguration
from generic_math import gen_uniform_rand_arr, nparr_int_round, RNSInteger, polynomial_RNSmult_constant
import math
import copy

class BFVSchemeClient:
    def __init__(self, config: BFVSchemeConfiguration):
        """
        :param config: the BFV scheme configuration containing all required parameters and settings
        """
        assert isinstance(config, BFVSchemeConfiguration)
        self.config = config
        # Secret key: polynomial degree n-1, n coefficients in {-1,0,1} or {0,1}
        if config.ternary:
            self._S = np.random.choice([-1, 0, 1], size=config.n).astype(object) % config.q # in practice you need to take this mod q
        else:
            self._S = np.random.choice([0, 1], size=config.n).astype(object)
        # relin keys
        self.relin_keys=self._compute_RLev_Ssqrd()

    def _compute_RLev_Ssqrd(self) -> list[tuple]:
        RLev_ciphertexts = []
        S_sqrd = self.polynomial_mul(self._S, self._S)
        for CRT_coef in self.config.RNS_CRT_coeffs_q:
            # Gadget factor is related to the RNS modulus 
            relinkey = CRT_coef*S_sqrd
            # encrypt the relinearization key
            A,B = self._alternative_RLWE_RNSencoded(relinkey)
            RLev_ciphertexts.append((A, B))
        return RLev_ciphertexts

    def polynomial_mul(self, A, B):
        return self.config.polynomial_mult_nomod(A,B)

    def _alternative_RLWE_RNSencoded(self, Xin: np.ndarray):
        """Encrypts Xin (length n polynomial)
        Returns tuple (A, B=-A*S+Xin+E)
        """
        modulus = self.config.q
        # random A (public key), n coefficients mod q, size n
        A = gen_uniform_rand_arr(0, modulus, size=self.config.n)
        # small noise E (centered discrete gaussian)
        E = np.round(np.random.normal(0, 1, size=self.config.n)).astype(int)
        # B = -A*S + Xin + E, all mod q, S is persistent secret key
        negAS = -self.polynomial_mul(A, self._S)
        B = (negAS + Xin + E) % modulus
        # return encryption result encoded with RNS
        return self.config.encode_integers_with_RNS(A), self.config.encode_integers_with_RNS(B)
    
    def encrypt(self, P: np.ndarray):
        """Encrypts plaintext P (integers mod t, length n).
        Returns ciphertext tuple (A, B)
        """
        # Message encoding
        M = self.config.batch_encode(np.array(P).flatten() % self.config.t)
        DeltaM = (M * self.config.Delta) % self.config.q # length n
        # return encryption result
        return self._alternative_RLWE_RNSencoded(DeltaM)

    def decrypt(self, A, B):
        self.config.validate_AB(A,B)
        A, B = self.config.convert_RNS_backto_integers(A), self.config.convert_RNS_backto_integers(B)
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
        Anew = A1+A2
        Bnew = B1+B2
        return Anew, Bnew
    
    def add_cipherplain(self, A1, B1, P2):
        """P2 is interpreted as the raw integers you want to multiply, so it is encoded and converted to RNS"""
        self.config.validate_AB(A1,B1)
        encoded_pt = self.config.encode_integers_with_RNS(self.config.batch_encode(P2))
        Bnew = B1 + polynomial_RNSmult_constant(constant=self.config.Delta, polyRNScoeffs=encoded_pt)
        return A1, Bnew
    
    def mul_cipherplain(self, A1, B1, P2):
        """P2 is interpreted as the raw integers you want to multiply, so it is encoded and converted to RNS"""
        # error checking
        self.config.validate_AB(A1,B1)
        # mul
        encoded_pt = self.config.encode_integers_with_RNS(self.config.batch_encode(P2))
        Anew = self.polynomial_mul(A1, encoded_pt)
        Bnew = self.polynomial_mul(B1, encoded_pt)
        return Anew, Bnew
  
    def _decompMultRNS(self,D2,RLev):
        # initialize total sums to 0
        total_sumA = np.array([RNSInteger(0, self.config.RNS_basis_q) for _ in range(self.config.n)], dtype=object)
        total_sumB = np.array([RNSInteger(0, self.config.RNS_basis_q) for _ in range(self.config.n)], dtype=object)
        # construct decomp matrix (vector of polynomials) and perform mult with RLev keys
        for i, prime_modulo in enumerate(self.config.RNS_basis_q):
            # get the ith gadget decomp polynomial of D2 (polynomial of normal integers)
            # Already in RNS basis, so extract the "i-th" residue from every coefficient in D2
            gadget_polynomial_i = [coef.residues[i] for coef in D2]
            # pretend like it is an RNSInteger (really need to broadcast each coefficient to all residues, easier to implement this way)
            # Note in hardware you dont actually need to write each coef in RNS basis (compute % prime_i). Just broadcast to all residues 
            gadget_polynomial_i = [RNSInteger(coef,self.config.RNS_basis_q) for coef in gadget_polynomial_i]
            # get the relinearization keys
            corresponding_relinA_key = RLev[i][0]
            corresponding_relinB_key = RLev[i][1]
            # convolve i-th relin keys with gadget decomp polynomial i
            A_partial_sum_i = self.polynomial_mul(gadget_polynomial_i,corresponding_relinA_key)
            B_partial_sum_i = self.polynomial_mul(gadget_polynomial_i,corresponding_relinB_key)
            # accumulate
            total_sumA += A_partial_sum_i
            total_sumB += B_partial_sum_i
        return total_sumA, total_sumB
            
    def _relinearization(self, D0, D1, D2, RLev):
        ct_alpha = D1, D0
        ct_beta = self._decompMultRNS(D2,RLev)
        return self.add_ciphercipher(*ct_alpha, *ct_beta)
    
    def mul_ciphercipher(self, A1, B1, A2, B2, RLev):
        # error checking
        self.config.validate_AB(A1,B1)
        self.config.validate_AB(A2,B2)
        # RNS Mod raise from q (current representation) to q*B*Ba (RNS_basis_qBBa)
        A1 = np.array([coef.fastBconv(self.config.RNS_basis_qBBa) for coef in A1], dtype=object)
        B1 = np.array([coef.fastBconv(self.config.RNS_basis_qBBa) for coef in B1], dtype=object)
        A2 = np.array([coef.fastBconv(self.config.RNS_basis_qBBa) for coef in A2], dtype=object)
        B2 = np.array([coef.fastBconv(self.config.RNS_basis_qBBa) for coef in B2], dtype=object)
        # polynomial multiplication
        D0 = self.polynomial_mul(B1,B2)
        D1 = self.polynomial_mul(B2,A1) + self.polynomial_mul(B1,A2)
        D2 = self.polynomial_mul(A1,A2)
        # Constant Multiplication by t
        D0 = np.array([coef.mul_constant(self.config.t) for coef in D0], dtype=object)
        D1 = np.array([coef.mul_constant(self.config.t) for coef in D1], dtype=object)
        D2 = np.array([coef.mul_constant(self.config.t) for coef in D2], dtype=object)
        # modswitch from q*B*Ba (current representation) to B*Ba (RNS_BBa)
        D0 = np.array([coef.modswitch(drop_modulis=self.config.RNS_basis_q) for coef in D0], dtype=object)
        D1 = np.array([coef.modswitch(drop_modulis=self.config.RNS_basis_q) for coef in D1], dtype=object)
        D2 = np.array([coef.modswitch(drop_modulis=self.config.RNS_basis_q) for coef in D2], dtype=object)
        # fastBconv from B*Ba to q
        D0 = np.array([coef.fastBconvEx(aux_modulis_B=self.config.RNS_basis_B, aux_modulis_Ba=self.config.RNS_basis_Ba, target_basis=self.config.RNS_basis_q) for coef in D0], dtype=object)
        D1 = np.array([coef.fastBconvEx(aux_modulis_B=self.config.RNS_basis_B, aux_modulis_Ba=self.config.RNS_basis_Ba, target_basis=self.config.RNS_basis_q) for coef in D1], dtype=object)
        D2 = np.array([coef.fastBconvEx(aux_modulis_B=self.config.RNS_basis_B, aux_modulis_Ba=self.config.RNS_basis_Ba, target_basis=self.config.RNS_basis_q) for coef in D2], dtype=object)
        #D0 = np.array([coef.centeredBconv(self.config.RNS_basis_q) for coef in D0], dtype=object)
        #D1 = np.array([coef.centeredBconv(self.config.RNS_basis_q) for coef in D1], dtype=object)
        #D2 = np.array([coef.centeredBconv(self.config.RNS_basis_q) for coef in D2], dtype=object)
        # Relinerization
        ctA, ctB = self._relinearization(D0, D1, D2, RLev)
        return ctA, ctB

