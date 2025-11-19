# generic_math.py
import sympy
import numpy as np
import math
import random
from collections.abc import Iterable
import warnings

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

def gen_RNS_basis(lower_bound: int, max_residue_size: int, multiple_of: Iterable = None) -> np.ndarray:
    """Generates a valid ResidueNumberSystem basis (a set of co-prime integers)
    RNS can be used for modulo arithmetic on very large integers. This algorithm is deterministic

    Args:
        lower_bound (int): RNS basis produced is gaurenteed to work for integers <= lower_bound
            (i.e. integers % lower_bound)
        max_residue_size (int): set the max size of each residue in the basis
            (e.g. 2^32 for 32 bit residues)
        multiple_of (Iterable, optional): ensure that RNS modulus is a multiple of these numbers
            default is None (so this is ignored)

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
    # accumulate primes
    while current_product < lower_bound:
        candidate = sympy.nextprime(candidate)
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



class RNSInteger:
    def __init__(self, num: int, residue_basis: np.ndarray, scheme_modulus: int=None):
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
    
    def assert_valid(self):
        assert isinstance(self.basis,np.ndarray), "self.basis must be np array"
        assert all([is_prime(m) for m in self.basis]), "non prime basis modulus found"
        assert self.modulus == np.prod(self.basis), "modulus not equal to product of basis"
        assert len(set(self.basis))==len(self.basis), "redundant basis primes"
    
    # allow  c * RNSInteger  by mapping to mul_constant
    #__rmul__ = mul_constant
    
    def set_to_zero(self):
        self.residues = np.array([0 for m in self.basis], dtype=object)

    def __repr__(self):
        return f"RNSInteger(num='{int(self)}', residues={self.residues}, basis={self.basis})"
    
    def mul_constant(self, c: int):
        c = int(c) % self.modulus
        res = RNSInteger(0, self.basis, self.modulus)
        res.residues = (self.residues * c) % self.basis
        return res
    
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
    
    # TODO fix
    def BROKENfastBconv(self, target_basis):
        """
        Perform Fast Base Conversion to a new modulus basis (target_basis)
        Returns a new RNSInteger in the target_basis (b_j)
        """
        old_basis = self.basis
        residues = self.residues
        q = np.prod(old_basis)
        target_basis = np.array(target_basis, dtype=object)
        assert len(set(target_basis))==len(target_basis), "target_basis cannot contain redundant basis primes" 
        new_residues = []
        
        # Precompute y_i and z_i for old basis elements
        y_list = [q // int(qi) for qi in old_basis]
        z_list = [sympy.mod_inverse(yi, qi) for yi, qi in zip(y_list, old_basis)]
        
        for bj in target_basis:
            bj = int(bj)
            # For each target modulus bj, compute the new residue
            s = 0
            for xi, qi, yi, zi in zip(residues, old_basis, y_list, z_list):
                val = (int(xi) * zi * yi) % bj
                s = (s + val) % bj
            new_residues.append(s)
        
        result = RNSInteger(num=0, residue_basis=target_basis, scheme_modulus=int(np.prod(target_basis)))
        result.residues = np.array(new_residues, dtype=object)
        # error check and return
        result.assert_valid()
        self.assert_valid()
        return result
    
    def fastBconv(self, target_basis: Iterable[int]) -> "RNSInteger":
        """NOT ACTUALLY FAST B CONV
        Convert the current representation to `target_basis`.
        A simple and *always correct* strategy is:
          1. Reconstruct the integer via CRT.
          2. Reduce it modulo each target modulus.
        """
        target_basis = np.asarray(list(target_basis), dtype=object)
        val = int(self)
        new_res = np.array([val % int(m) for m in target_basis], dtype=object)
        out = RNSInteger(0, target_basis, int(np.prod(target_basis)))
        out.residues = new_res
        return out
    
    def centeredfastBconv(self, target_basis: Iterable[int]) -> "RNSInteger":
        """NOT ACTUALLY centered FAST B CONV
        Convert the current representation to `target_basis`.
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
    
    # TODO fix
    def BROKEN_modswitch(self, drop_modulis):
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

        # Step 2: Compute |chi|_b from dropped residues and moduli
        b = int(np.prod(b_basis))
        # Compute CRT (Chinese Remainder Theorem) for residues mod b
        crt_int = int(sympy.ntheory.modular.crt(list(map(int, b_basis)), list(map(int, b_residues)))[0])

        # Step 3: Fast base conversion: Convert crt_int modulo b to RNS residues in q_basis
        hat_chi = np.array([crt_int % int(q_i) for q_i in q_basis], dtype=object)  # hat_chi_i for each q_i

        # Step 4: For each modulus in q_basis, compute new residue
        new_residues = []
        for i in range(len(q_basis)):
            q_i = int(q_basis[i])
            chi_i = int(q_residues[i])
            hat_chi_i = int(hat_chi[i])
            b_inv = sympy.mod_inverse(b, q_i)
            y_i = (b_inv * (chi_i - hat_chi_i)) % q_i
            new_residues.append(y_i)

        # Step 5: Create new RNSInteger object in new basis
        result = RNSInteger(num=0, residue_basis=q_basis, scheme_modulus=int(np.prod(q_basis)))
        result.residues = np.array(new_residues, dtype=object)
        return result
    
    def modswitch(self, drop_modulis: Iterable[int]) -> "RNSInteger":
        """NOT ACTUALL MODSWITCH
        Drop the moduli in `drop_modulis` and divide the
        represented integer by their product (rounded to the nearest int)
        """
        drop_list  = [int(m) for m in drop_modulis]
        keep_basis = [int(m) for m in self.basis if m not in drop_list]
        if len(keep_basis) == len(self.basis):
            raise ValueError("drop_modulis does not intersect the basis")
        if not keep_basis:
            raise ValueError("cannot drop the entire basis")
        x            = int(self)
        q_prod       = math.prod(drop_list)           # the q we remove
        half_q       = q_prod >> 1                    # for nearest-integer rounding
        new_value    = (x + half_q) // q_prod         # (x/q) + 1/2
        return RNSInteger(new_value, np.asarray(keep_basis, dtype=object))




def polynomial_RNSmult_constant(constant: int, polyRNScoeffs: Iterable) -> np.ndarray:
    """Create and return an np.ndarray representing the multiplication of each coefficient by the integer constant"""
    constant=int(constant)
    assert isinstance(polyRNScoeffs[0],RNSInteger), "expecting RNSInteger"
    result = [coef.mul_constant(constant) for coef in polyRNScoeffs]
    return np.array(result,dtype=object)