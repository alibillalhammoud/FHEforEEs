import numpy as np

class BFVSchemeConfiguration:
    def __init__(self, t: int, q: int, n: int, ternary: bool = True):
        """
        :param t: Plaintext modulus (prime or power of prime)
        :param q: Ciphertext modulus (t divides q, q much larger than t)
        :param n: Degree of polynomial + 1
        :param ternary: If true, secret key is ternary {-1,0,1}, else binary {0,1}
        """
        self.t = int(t)
        self.q = int(q)
        self.k = 1 # BFV scheme (and other RLWS) have k=1
        self.n = int(n)
        self.ternary = ternary
        self.Delta = q // t
    
    def is_A_valid(self, A) -> bool:
        """
        Checks that A is a k x n array of integers modulo q
        """
        # Must be (k, n) shape
        if not isinstance(A, np.ndarray):
            raise TypeError("A must be a numpy array")
        if A.shape != (self.k, self.n):
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
        if B.shape != (self.n,):
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

