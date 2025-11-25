# generic_math.py
import sympy
import numpy as np
import math
import random
from collections.abc import Iterable
import warnings
import copy
from ntt_friendly_prime import negacyclic_moduli

def is_prime(x) -> bool:
    return bool(sympy.isprime(x))

def is_odd(x) -> bool:
    return bool(x % 2 == 1)

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
    #assert divisor > 0 and divisor%2==0, "divisor must be positive and even number"
    assert divisor > 0, "divisor must be positive"
    half = divisor >> 1
    return (dividend+half) // divisor

def gen_RNS_basis(lower_bound: int, max_residue_size: int, multiple_of: Iterable = None, scheme_SIMD_slots: int = None) -> np.ndarray:
    """Generates a valid ResidueNumberSystem basis (a set of co-prime integers)
    RNS can be used for modulo arithmetic on very large integers. This algorithm is deterministic

    Args:
        lower_bound (int): RNS basis produced is gaurenteed to work for integers <= lower_bound
            (i.e. integers % lower_bound)
        max_residue_size (int): set the max size of each residue in the basis
            (e.g. 2^32 for 32 bit residues)
        multiple_of (Iterable, optional): ensure that RNS modulus is a multiple of these numbers
            default is None (so this is ignored)
        scheme_SIMD_slot (int, optional): if this option is specified, the function attempts to create negacyclic NTT friendly primes

    Returns:
        np.ndarray: the residue basis
    """
    lower_bound = int(lower_bound)
    max_residue_size = int(max_residue_size)
    min_residue_size = max_residue_size // 2 # primes are spaced ~ln(x) apart so there is a good chance this works
    if lower_bound < 1:
        raise ValueError("`lower_bound` must be >= 1.")
    # accumulate primes until the running product exceeds the desired lower bound.
    moduli: List[int] = []
    current_product = 1
    candidate = min_residue_size
    # gaurantee that current_product is a multiple of multiple_of
    if multiple_of is not None:
        assert isinstance(multiple_of, Iterable), "\"multiple_of\" should be list like"
        assert all([multiple > 0 for multiple in multiple_of]), "\"multiple_of\" must be a postive"
        multiple = 1
        for multiple in multiple_of:
            multiple = int(multiple)
            if multiple > max_residue_size:
                raise ValueError("Passed multiple_of value exceedes max_residue_size")
            moduli.append(multiple)
            current_product *= multiple
        if candidate < multiple:
            candidate = multiple+1
    # generate a bunch of NTT friendly primes (or dont if scheme_SIMD_slots=None)
    warnings.warn("NTT friedly prime generation code still has not been tested")
    if scheme_SIMD_slots is not None:
        # You usually set scheme_SIMD_slot = N (NTT length)
        # We grab more primes than strictly needed and then take them one by one.
        primes_needed = lower_bound//max_residue_size + 20
        raise NotImplementedError("specify start_multiple=...")
        ntt_friendly_candidates = [mp.q for mp in negacyclic_moduli(scheme_SIMD_slot, count=primes_needed)]#, start_multiple=)]
        get_next_prime = lambda x: next(primes_iter)
        candidate = next(primes_iter)
    else:
        get_next_prime = sympy.nextprime
    # accumulate primes
    while current_product < lower_bound:
        candidate = get_next_prime(candidate)
        if candidate > max_residue_size:
            raise ValueError("Cannot reach lower_bound without exceeding max_residue_size")
        moduli.append(candidate)
        current_product *= candidate
    # error check
    assert all([is_prime(m) for m in moduli]), "non prime basis modulus produced"
    assert len(set(moduli))==len(moduli), "redundant basis primes"
    # return result
    return np.array(moduli, dtype=object)

def compute_CRT_coefficients(RNS_basis) -> np.ndarray:
    """Compute CRT coefficients for a given RNS modulus basis.
    Args:
        RNS_basis: Iterable of pairwise coprime moduli (e.g., [q1, q2, ..., qk])
    Returns:
        np.ndarray of CRT coefficients (alpha_i), dtype=object (to support bigints)
    """
    moduli = np.array(RNS_basis, dtype=object)
    k = len(moduli)
    q = np.prod(moduli)
    coeffs = np.empty(k, dtype=object)
    for i in range(k):
        q_over_qi = q // moduli[i]
        inv = sympy.mod_inverse(q_over_qi, moduli[i]) % moduli[i]
        alpha_i = (q_over_qi * inv) % q
        coeffs[i] = alpha_i
    return coeffs

def is_pairwise_coprime(arr) -> bool:
    n = len(arr)
    for i in range(n):
        for j in range(i + 1, n):
            if sympy.gcd(arr[i], arr[j]) != 1:
                return False
    return True


def centered_mod(x, q):
    """
    Centered residue of x (scalar or array‑like) modulo q.

    Returned range:
        (-⌊q/2⌋ , ⌈q/2⌉]   for any positive integer q.
    """
    if q <= 0:
        raise ValueError("Modulus q must be positive.")
    # scalar
    if np.isscalar(x):
        r = x % q     # bring into [0, q-1]
        if r > q // 2: # fold the upper half down
            r -= q
        return int(r)
    #vect0r
    arr = np.asarray(x) # 1‑D, 2‑D,anything works
    r = np.mod(arr, q) # same shape as arr
    mask = r > q // 2
    r = r.astype(object, copy=False)  # allow big ints if q is big
    r[mask] -= q
    return r if isinstance(x, np.ndarray) else type(x)(r.tolist())


class RNSInteger:
    def __init__(self, num: int, residue_basis: np.ndarray, scheme_modulus: int=None, center=False):
        """Represent num (integer) using RNS under the provided residue_basis
        if scheme_modulus is provided then slow error checking steps are skipped (it is assumed user knows what they are doing)
        """
        if scheme_modulus is None:
            residue_basis = np.array(residue_basis,dtype=object).flatten()
            assert residue_basis.ndim == 1, "residue_basis must be 1d"
            ispyint = bool(residue_basis.dtype==object and isinstance(residue_basis[0],int))
            assert np.issubdtype(residue_basis.dtype, np.integer) or ispyint, "residue_basis must contain integers"
            assert is_pairwise_coprime(residue_basis), "residue basis must be coprime"
            # Ensure Python ints, not np.int32/etc
            self.basis = residue_basis.astype(object)
            self.modulus = np.prod(self.basis)
        else:
            self.basis = residue_basis
            self.modulus = int(scheme_modulus)
        assert isinstance(self.basis,np.ndarray), "self.basis must be np array"
        # convert integer to RNS
        num = int(num)
        self.residues = np.array([num % m for m in self.basis], dtype=object)
    
    # helper for building new instance from explicit residues
    @staticmethod
    def _from_residues(res_vec: Iterable[int], basis: Iterable[int]) -> "RNSInteger":
        obj = RNSInteger(0, residue_basis=np.array(basis, dtype=object), scheme_modulus=int(np.prod(basis)))
        obj.residues = np.array(res_vec, dtype=object)
        return obj
    
    def assert_valid(self):
        assert isinstance(self.basis,np.ndarray), "self.basis must be np array"
        assert all([is_prime(m) for m in self.basis]), "non prime basis modulus found"
        assert self.modulus == np.prod(self.basis), "modulus not equal to product of basis"
        assert len(set(self.basis))==len(self.basis), "redundant basis primes"
    
    def set_to_zero(self):
        self.residues = np.array([0 for m in self.basis], dtype=object)

    def __repr__(self):
        return f"RNSInteger(num='{int(self)}', residues={self.residues}, basis={self.basis})"
    
    def mul_constant(self, c: int):
        c = int(c) % self.modulus
        res = RNSInteger(0, self.basis, self.modulus)
        res.residues = (self.residues * c) % self.basis
        return res
    
    # allow  c * RNSInteger  by mapping to mul_constant
    #__rmul__ = mul_constant
    
    def __int__(self) -> int:
        """Reconstruct the integer by calling SymPy's CRT.
        Returns an integer in [0, modulus).
        """
        crt_val, _ = sympy.ntheory.modular.crt(list(map(int, self.basis)), list(map(int, self.residues)), symmetric=False)
        return int(crt_val)
    
    def __add__(self, other):
        assert np.array_equal(self.basis, other.basis), "Basis mismatch in addition"
        new_residues = (self.residues + other.residues) % self.basis
        result = RNSInteger(num=0, residue_basis=self.basis, scheme_modulus=self.modulus)
        result.residues = new_residues
        return result

    def __mul__(self, other):
        assert np.array_equal(self.basis, other.basis), "Basis mismatch in multiplication"
        new_residues = (self.residues * other.residues) % self.basis
        result = RNSInteger(num=0, residue_basis=self.basis, scheme_modulus=self.modulus)
        result.residues = new_residues
        return result
    
    def __iadd__(self, other):
        assert np.array_equal(self.basis, other.basis), "Basis mismatch in addition"
        self.residues = (self.residues + other.residues) % self.basis
        return self

    def __imul__(self, other):
        assert np.array_equal(self.basis, other.basis), "Basis mismatch in multiplication"
        self.residues = (self.residues * other.residues) % self.basis
        return self
    
    def __sub__(self, other):
        assert np.array_equal(self.basis, other.basis), "Basis mismatch in subtraction"
        new_residues = (self.residues - other.residues) % self.basis
        result = RNSInteger(num=0, residue_basis=self.basis, scheme_modulus=self.modulus)
        result.residues = new_residues
        return result

    def __isub__(self, other):
        assert np.array_equal(self.basis, other.basis), "Basis mismatch in subtraction"
        self.residues = (self.residues - other.residues) % self.basis
        return self
    
    @staticmethod
    def _center(res_vec, mod_vec):
        """Map each residue r (0 <= r < m) to the centred representative (-m/2, m/2]"""
        out = np.array([residue for residue in res_vec], dtype=object)
        for i in range(len(out)):
            m = int(mod_vec[i])
            out[i] %= m
            if out[i] > m // 2: # single comparator
                out[i] -= m # conditional subtraction
        return out
    
    def fastBconv(self, target_basis: Iterable[int], zero_center: bool=True) -> "RNSInteger":
        # precompute
        q = self.modulus
        y  = [q // qi for qi in self.basis] # yi = q/qi
        z  = [sympy.mod_inverse(yi, qi) for yi, qi in zip(y, self.basis)] # zi = yi^{-1} mod qi
        residues = self.residues
        if zero_center:
            z = RNSInteger._center(z,self.basis) # need the centered inverse apparently
        #
        # Hardware step
        if zero_center:
            residues = RNSInteger._center(self.residues, self.basis)
        a  = [(xi * zi) % qi for xi, zi, qi in zip(residues, z, self.basis)]  # ai
        if zero_center:
            a = RNSInteger._center(a,self.basis)
        c_res = []
        for bj in target_basis:
            acc = 0
            y_mod_bj = [yi % bj for yi in y]
            for ai, yib in zip(a, y_mod_bj):
                psum = (ai * yib) % bj
                acc = (acc + psum) % bj
            c_res.append(acc)
        #
        # result a python int (and more error checking)
        result = RNSInteger(0, target_basis)
        result.residues = np.array(c_res, dtype=object)
        result.assert_valid()
        self.assert_valid()
        return result

    def modswitch(self, drop_modulis) -> "RNSInteger":
        """RNS-based modulus switching. Removes moduli in drop_modulis
        and updates the residues in the remaining basis (q_i) accordingly.
        Args:
            drop_modulis: list of prime modulus values to drop (e.g. [b1, b2, ...])
        Returns:
            RNSInteger representing value modulo q (updated residues)
        """
        drop_modulis = set(int(v) for v in drop_modulis)
        keep_indices = [i for i, m in enumerate(self.basis) if m not in drop_modulis]
        drop_indices = [i for i, m in enumerate(self.basis) if m in drop_modulis]
        assert len(drop_indices) > 0, "No basis elements to drop"
        assert all(m in set(self.basis) for m in drop_modulis), "All dropped moduli must exist in basis"
        q_basis = self.basis[keep_indices].astype(object)
        q_residues = self.residues[keep_indices].astype(object)
        b_basis = self.basis[drop_indices].astype(object)
        b_residues = self.residues[drop_indices].astype(object)
        # Compute |chi|_b from dropped residues and moduli
        # Compute CRT (Chinese Remainder Theorem) for residues mod b
        crt_int = int(sympy.ntheory.modular.crt(list(map(int, b_basis)), list(map(int, b_residues)))[0])
        # Fast base conversion: Convert crt_int modulo b to RNS residues in q_basis
        hat_chi = np.array([crt_int % int(q_i) for q_i in q_basis], dtype=object)  # hat_chi_i for each q_i
        # precompute stuff
        b = int(np.prod(b_basis))
        b_invs = list()
        for i in range(len(q_basis)):
            b_invs.append(sympy.mod_inverse(b, q_basis[i]))
        #
        # HARDWARE: For each modulus in q_basis, compute new residue
        new_residues = []
        for i in range(len(q_basis)):
            # look up table
            q_i = int(q_basis[i])
            hat_chi_i = int(hat_chi[i])
            b_inv = b_invs[i]
            # hardware computation
            chi_i = int(q_residues[i])
            y_i = (b_inv * (chi_i - hat_chi_i)) % q_i
            new_residues.append(y_i)
        #
        # return new RNSInteger object using the calculated basis
        result = RNSInteger(num=0, residue_basis=q_basis, scheme_modulus=int(np.prod(q_basis)))
        result.residues = np.array(new_residues, dtype=object)
        return result
        
    def _moddrop(self, keep_moduli: Iterable[int], center_residues: bool=False) -> "RNSInteger":
        keep_set = set(int(m) for m in keep_moduli)
        assert len(keep_moduli)==len(keep_set), "redundant basis not allowed"
        idx = [i for i, m in enumerate(self.basis) if m in keep_set]
        assert idx, "Resulting basis is empty (cant drop everything)"
        new_residues = self.residues[idx]
        if center_residues:
            new_residues = self._center(new_residues, self.basis[idx])
        return RNSInteger._from_residues(new_residues, self.basis[idx])

    def fastBconvEx(self, aux_modulis_B: Iterable[int], aux_modulis_Ba: Iterable[int], target_basis: Iterable[int]) -> "RNSInteger":
        """Exact fast base conversion (FastBConvEx) from the union base
        B union B_a (which equals self.basis) to target_basis (= B union B_a).
        """
        # error checking
        B = np.array(aux_modulis_B, dtype=object)
        Ba = np.array(aux_modulis_Ba, dtype=object)
        q = np.array(target_basis, dtype=object)
        assert set(B).isdisjoint(set(Ba)), "aux_modulis_B and aux_modulis_Ba must be disjoint"
        # precalculation
        b_bigmodulus = int(np.prod(B))
        Ba_bigmodulus = np.prod(Ba)
        b_inv_Ba_bigint = sympy.mod_inverse(b_bigmodulus,Ba_bigmodulus)
        b_inv_Ba = np.array([b_inv_Ba_bigint % prime for prime in Ba], dtype=object)
        #b_inv_Ba = np.array([sympy.mod_inverse(b_bigmodulus % int(p), int(p)) for p in Ba], dtype=object)
        b_inv_Ba = RNSInteger._center(b_inv_Ba,Ba)
        #
        # step 1: mod drops
        xB = self._moddrop(B, True) # residues only on B
        xBa = self._moddrop(Ba, True) # residues only on Ba
        # Step 2: compute gamma
        # You may have realized that the BFV with RNS paper and the fhetextbook directly take gamma as a big int
        # This is because gamma is bounded (small), ensuring it fits into a machine word
        temp = (xB.fastBconv(Ba, zero_center=True).residues - xBa.residues) % Ba
        temp = RNSInteger._center(temp, Ba)
        gamma_Ba = (temp * b_inv_Ba) % Ba # gamma in Ba basis
        gamma_Ba = RNSInteger._center(gamma_Ba, Ba)
        if abs(centered_mod(int(RNSInteger._from_residues(gamma_Ba,Ba)),Ba_bigmodulus))>(2**32):
            raise ValueError("int too BIG!!!!!")
        # Step 3: convert gamma to the q basis (this is the correction term)
        gamma_int, _ = sympy.ntheory.modular.crt(list(map(int, Ba)), list(map(int, gamma_Ba)), symmetric=True)
        gamma_q = RNSInteger._from_residues(gamma_Ba, Ba).centeredBconv(q, zero_center=True).residues
        # Step 4: final exact conversion
        xB_to_q = xB.fastBconv(q, zero_center=True).residues
        b_mod_q = np.array([b_bigmodulus % int(p) for p in q], dtype=object)
        result_residues = (xB_to_q - gamma_q * b_mod_q) % q
        # check that I got the right answer
        expected_result = self.centeredBconv(target_basis=target_basis).residues
        return RNSInteger._from_residues(result_residues, q)

    def centeredBconv(self, target_basis: Iterable[int],zero_center=True) -> "RNSInteger":
        """Convert the current representation to `target_basis`.
        A simple and *always correct* strategy is:
          1. Reconstruct the integer via CRT.
          2. Reduce it modulo each target modulus.
        """
        target_basis = np.asarray(list(target_basis), dtype=object)
        val, _ = sympy.ntheory.modular.crt(list(map(int, self.basis)), list(map(int, self.residues)), symmetric=True)
        new_res = np.array([val % int(m) for m in target_basis], dtype=object)
        out = RNSInteger(0, target_basis, int(np.prod(target_basis)))
        out.residues = new_res
        return out


def polynomial_RNSmult_constant(constant: int, polyRNScoeffs: Iterable) -> np.ndarray:
    """Create and return an np.ndarray representing the multiplication of each coefficient by the integer constant"""
    constant=int(constant)
    assert isinstance(polyRNScoeffs[0],RNSInteger), "expecting RNSInteger"
    result = [coef.mul_constant(constant) for coef in polyRNScoeffs]
    return np.array(result,dtype=object)
