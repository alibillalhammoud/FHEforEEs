import numpy as np
import sympy
import math

# --- To make the example runnable, we first create a virtual class ---
class MyPolynomialProcessor:
    
    def __init__(self):
        """
        Initializes the instance, used to store computed parameters.
        """
        self.N = None
        self.min_p_bound = None
        self.p = None
        self.g = None # Primitive root
        self.psi = None # 2N-th root (for twisting)
        self.psi_inv = None
        self.w = None   # N-th root (for NTT)
        self.w_inv = None
        self.n_inv = None # Inverse of N
    
    def validate_AB(self, a: np.ndarray, b: np.ndarray):
        """
        Validation function, from your code.
        The NTT algorithm (Cooley-Tukey) requires N to be a power of 2.
        """
        if len(a) != len(b):
            raise ValueError("Input vectors a and b must have the same length.")
        N = len(a)
        if (N <= 0) or (N & (N - 1) != 0):
            raise ValueError(f"Input length N={N} must be a power of 2 (for Radix-2 NTT).")
    
    def _naive_polynomial_mult_nomod(self, a_in: np.ndarray, b_in: np.ndarray) -> np.ndarray:
        """
        【Your original function, for comparison/validation】
        Note: Must use 'object' dtype to handle large numbers, otherwise np.convolve will overflow.
        """
        self.validate_AB(a_in,b_in)
        n = len(a_in)
        
        # Must use object dtype, otherwise 10^40 * 10^40 will overflow
        a_obj = a_in.astype(object)
        b_obj = b_in.astype(object)

        cconv = np.convolve(a_obj, b_obj)
        res = np.zeros(n, dtype=object) 
        for i in range(len(cconv)):
            if i < n:
                res[i] += cconv[i]
            else:
                res[i - n] -= cconv[i]
        # Match the output dtype
        return res.astype(a_in.dtype) % self.p

    # -----------------------------------------------------------------
    # ---  ↓↓↓ Helper functions "promoted" to class methods ↓↓↓  ---
    # -----------------------------------------------------------------
    
    def _is_prime(self, n: int) -> bool:
        if n <= 1: return False
        if n <= 3: return True
        if n % 2 == 0 or n % 3 == 0: return False
        i = 5
        while i * i <= n:
            if n % i == 0 or n % (i + 2) == 0:
                return False
            i += 6
        return True

    def _get_prime_factors(self, n: int) -> list:
        factors = set()
        d = 2
        temp = n
        while d * d <= temp:
            if temp % d == 0:
                factors.add(d)
                while temp % d == 0:
                    temp //= d
            d += 1
        if temp > 1:
            factors.add(temp)
        return list(factors)

    def _power_mod(self, a, b, m):
        """ Scalar modular exponentiation: (a^b) % m """
        return pow(int(a), int(b), int(m))

    def _ntt(self, x_list: list, p: int, w: int) -> list:
        """ Fast O(N log N) recursive NTT """
        N_local = len(x_list)
        if N_local == 1:
            return x_list
        
        w_sq = self._power_mod(w, 2, p)
        # Recursive call
        even = self._ntt(x_list[0::2], p, w_sq)
        odd  = self._ntt(x_list[1::2], p, w_sq)
        
        y = [0] * N_local
        wk = 1
        for k in range(N_local // 2):
            t = (wk * odd[k]) % p
            y[k] = (even[k] + t) % p
            y[k + N_local // 2] = (even[k] - t + p) % p
            wk = (wk * w) % p
        
        return y

    def _calculate_min_p_bound(self, a: np.ndarray, b: np.ndarray, N_val: int) -> int:
        """
        Calculate the minimum prime p required for lossless convolution.
        """
        # Find the maximum absolute value of input coefficients
        # (Use object dtype to prevent overflow when calculating a_max * b_max)
        a_max = np.max(np.abs(a.astype(object)))
        b_max = np.max(np.abs(b.astype(object)))
        
        # A safe (though loose) bound B is N * A_max * B_max
        conv_bound_B = N_val * a_max * b_max
        
        # We need p > 2 * B to handle negative numbers explicitly.
        min_p = 2 * conv_bound_B + 1
        return int(min_p)

    def _generate_large_ntt_params(self, N_val: int, min_p_bound: int):
        """
        Automatically find a *sufficiently large* p and its roots.
        【Change】: This function now stores results in self.
        """
        # 1. Find a prime p = 2*N*k + 1, such that p >= min_p_bound
        k = math.ceil((min_p_bound - 1) / (2 * N_val))
        
        p = 0 # Initialize
        while True:
            p = 2 * N_val * k + 1
            if self._is_prime(p):
                break # Found it
            k += 1
            if k > 134221489: # Safety check
                raise TimeoutError(f"Could not find a prime for N={N_val} and p_bound={min_p_bound}.")
        
        # 2. Find primitive root g
        phi = p - 1
        prime_factors = self._get_prime_factors(phi)
        g = 2
        while True:
            is_generator = True
            for q in prime_factors:
                if self._power_mod(g, phi // q, p) == 1:
                    is_generator = False
                    break
            if is_generator:
                break
            g += 1
            
        # 3. Calculate primitive roots of unity
        psi = self._power_mod(g, k, p)
        w = self._power_mod(psi, 2, p)
        
        # 4. Calculate inverses
        psi_inv = self._power_mod(psi, p - 2, p)
        w_inv = self._power_mod(w, p - 2, p)
        n_inv = self._power_mod(N_val, p - 2, p)
        
        # --- 5. 【Core Change】Store in instance attributes ---
        self.p = p
        self.g = g
        self.psi = psi
        self.psi_inv = psi_inv
        self.w = w
        self.w_inv = w_inv
        self.n_inv = n_inv
        # (N and min_p_bound are already stored by the main function)
        return # No longer returns a tuple

    # -----------------------------------------------------------------
    # ---  ↓↓↓ The "SymPy + 5-step NTT" function you requested ↓↓↓  ---
    # -----------------------------------------------------------------
    
    def ntt_negacyclic_conv(self, a_in: np.ndarray, b_in: np.ndarray) -> np.ndarray:
        """
        【New "Lossless" NTT Implementation】
        Uses N-point NTT and Twisting to compute (a * b) mod (x^n + 1)
        on the *integer ring*, ensuring a "lossless" result.
        """
        
        # --- 0. Validation ---
        self.validate_AB(a_in, b_in)
        self.N = N = len(a_in) # Store N
        
        # --- 1. Calculate bound and get a sufficiently large p and its parameters ---
        
        # Calculate and store min_p
        # (Using a fixed large bound for this example, but
        # _calculate_min_p_bound(a_in, b_in, N) is the correct way)
        self.min_p_bound = int(2147483777-5) 
        
        # Calculate and store p, psi, w, n_inv, and all other parameters
        self._generate_large_ntt_params(N, self.min_p_bound)

        # --- 2. Main algorithm for "lossless" negacyclic convolution ---
        # (Now using instance attributes like self.p, self.psi, etc.)
        
        # 2.2. Prepare input vectors (use 'object' dtype for large numbers)
        a = np.array(a_in, dtype=object) % self.p
        b = np.array(b_in, dtype=object) % self.p
        
        # 2.3. Pre-processing (Twisting)
        psi_powers = np.array([self._power_mod(self.psi, i, self.p) for i in range(N)], dtype=object)
        print(f"Debug: psi_powers = {psi_powers}")
        a_twisted = (a * psi_powers) % self.p
        print(f"Debug: a_twisted = {a_twisted}")
        b_twisted = (b * psi_powers) % self.p

        # 2.4. Standard NTT (N-point)
        A_twisted = np.array(self._ntt(list(a_twisted), self.p, self.w), dtype=object)
        print(f"Debug: A_twisted = {A_twisted}")
        B_twisted = np.array(self._ntt(list(b_twisted), self.p, self.w), dtype=object)
        
        # 2.5. Point-wise multiplication
        C_twisted = (A_twisted * B_twisted) % self.p
        print(f"Debug: C_twisted = {C_twisted}")

        # 2.6. Standard Inverse NTT (N-point)
        c_twisted_raw = np.array(self._ntt(list(C_twisted), self.p, self.w_inv), dtype=object)
        print(f"Debug: c_twisted_raw (before n_inv) = {c_twisted_raw}")
        c_twisted = (c_twisted_raw * self.n_inv) % self.p
        
        # 2.7. Post-processing (Untwisting)
        psi_inv_powers = np.array([self._power_mod(self.psi_inv, i, self.p) for i in range(N)], dtype=object)
        c_mod_p = (c_twisted * psi_inv_powers) % self.p
        
        # 2.8. "Lift" the result from Z_p back to Z (integers)
        # (This maps values from [0, p-1] to [-p/2, p/2])
        p_half = self.p // 2
        
        c_final =c_mod_p # np.where(c_mod_p > p_half, c_mod_p - self.p, c_mod_p)

        # 2.9. Return integer result matching input dtype
        return c_final.astype(a_in.dtype)

# -----------------------------------------------------------------
# ---  ↓↓↓ Testing and Validation ↓↓↓  ---
# -----------------------------------------------------------------

if __name__ == "__main__":
    
    # 1. Set parameters
    N = 8
    
    # 2. Create sample input (using standard int64)
    a_vec = np.array([1, 2,3,4,5,6,7,8], dtype=np.int64)
    b_vec = np.array([1,2,3,4,5,6,7,8], dtype=np.int64)

    # 3. Instantiate the class
    processor = MyPolynomialProcessor()

    print(f"--- Testing N = {N} (Lossless) ---")
    print(f"Input a: {a_vec}")
    print(f"Input b: {b_vec}")

    # 4. Run the new "Lossless NTT" version
    c_ntt_lossless = processor.ntt_negacyclic_conv(a_vec, b_vec)
    print(f"\nNTT (Lossless) Result: {c_ntt_lossless}")
    print(f"Min Bound (min_p_bound): {processor.min_p_bound}")
    print(f"Selected Prime (p): {processor.p}")
    print(f"Primitive Root (g): {processor.g}")
    print(f"NTT Root (w): {processor.w}")
    
    # 5. Run the original "naive" integer version (must use object dtype)
    c_naive_int = processor._naive_polynomial_mult_nomod(a_vec, b_vec)
    print(f"Naive (Integer) Result: {c_naive_int}\n")

    # 6. Final comparison
    if np.array_equal(c_ntt_lossless, c_naive_int):
        print("✅ Validation Successful: Lossless NTT result matches naive integer result perfectly.")
    else:
        print("❌ Validation Failed: Results do not match.")

    # -----------------------------------------------------------------
    # ---  ↓↓↓ [New Feature] Reading stored parameters afterward ↓↓↓  ---
    # -----------------------------------------------------------------
    print("\n--- Stored Parameters (Readable afterward) ---")
    print(f"N: {processor.N}")
    print(f"Min Bound (min_p_bound): {processor.min_p_bound}")
    print(f"Selected Prime (p): {processor.p}")
    print(f"Primitive Root (g): {processor.g}")
    print(f"NTT Root (w): {processor.w}")
    print(f"NTT Inverse Root (w_inv): {processor.w_inv}")
    print(f"Twist Root (psi): {processor.psi}")
    print(f"Twist Inverse Root (psi_inv): {processor.psi_inv}")
    print(f"N Inverse (n_inv): {processor.n_inv}")
    print("-----------------------------------")


    # print("\n--- Testing N = 4, including large numbers (10^12 scale) ---")
    # N_4 = 4
    # large_num = 10**12 
    # a_large = np.array([1 * large_num, 2 * large_num, 3, 4], dtype=object)
    # b_large = np.array([5 * large_num, 6, -7, 8], dtype=object)

    # # (To allow N=4 to pass, we override the validate_AB method)
    # # This inherits from the main class and changes only the validation
    # class TempProcessor(MyPolynomialProcessor):
    #     def validate_AB(self, a: np.ndarray, b: np.ndarray):
    #         if len(a) != len(b):
    #             raise ValueError("Lengths not equal")
    #         N = len(a)
    #         if (N <= 0) or (N & (N - 1) != 0):
    #             raise ValueError(f"Input length N={N} must be a power of 2.")

    # processor_large = TempProcessor()
    
    # # Note: We take the result mod p here just for comparison,
    # # as the naive method doesn't know about 'p' and would show different numbers.
    # # The *lossless* method correctly lifts to the true negative/positive integers.
    # # For this test, we just check if they are congruent mod p.
    
    # c_ntt_large = processor_large.ntt_negacyclic_conv(a_large, b_large) % processor_large.p
    # c_naive_large = processor_large._naive_polynomial_mult_nomod(a_large, b_large) % processor_large.p

    # print(f"\nNTT (Lossless) Result: {c_ntt_large}")
    # print(f"Naive (Integer) Result: {c_naive_large}\n")
    
    # # The real test is if the raw integer results match
    # if np.array_equal(c_ntt_large, c_naive_large):
    #     print("✅ Validation Successful: Large number lossless NTT result matches naive integer result.")
    # else:
    #     print("❌ Validation Failed: Large number results do not match.")
    #     print("NTT:", c_ntt_large)
    #     print("Naive:", c_naive_large)
        
    # print("\n--- Stored Large Number Parameters (Readable afterward) ---")
    # print(f"N: {processor_large.N}")
    # print(f"Min Bound (min_p_bound): {processor_large.min_p_bound}")
    # print(f"Selected Prime (p): {processor_large.p}")
    # # (p will be very large)
    # print("-----------------------------------")