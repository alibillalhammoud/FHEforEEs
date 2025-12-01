"""
negacyclic-NTT friendly prime searcher
Given a transform size n (usually a power of two) this script locates
prime moduli q such that
      2n | (q-1)
which guarantees the existence of a primitive 2n-th root of unity psi.
It then finds psi and verifies      psi^n = -1  (mod q).
Such (q, psi) can be used to implement an n-point negacyclic NTT

e.g.
python ntt_friendly_prime.py -k 4000000 -c 100

"""

from typing import Iterator, List, Tuple
from dataclasses import dataclass

import sympy

@dataclass
class NTTModulus:
    q: int     # the prime modulus
    psi: int   # a primitive 2n-th root of unity (order exactly 2n)
    omega: int # omega = psi^2  (primitive n-th root)
    n: int     # transform size that this modulus supports

    def __str__(self) -> str:
        return (f"q = {self.q}  (bit-length {self.q.bit_length()})\n"
                f"    psi   = {self.psi}\n"
                f"    omega = {self.omega}\n"
                f"    check: psi^n  ≡ {pow(self.psi, self.n, self.q)}\n"
                f"           psi^2n ≡ {pow(self.psi, 2*self.n, self.q)}")


def _candidate_primes(n: int, start_multiple: int = 1) -> Iterator[int]:
    """
    Generate numbers of the form q = k*(2n) + 1  (k ≥ start_multiple).
    Only candidates are produced; primality is tested by the caller.
    """
    k = max(start_multiple, 1)
    step = 2 * n
    while True:
        yield k * step + 1
        k += 1


def _find_psi(q: int, n: int) -> int:
    """
    Given a prime q satisfying 2n | (q-1), return a primitive 2n-th root ψ.
    A generator 'g' of F_q^x has order q-1; raise it to (q-1)/(2n).
    """
    g = sympy.primitive_root(q)  # a generator of (Z/qZ)^×
    exponent = (q - 1) // (2 * n)
    psi = pow(g, exponent, q)
    # Ensure we really obtained order 2n (might fail for small primes if g
    # is not primitive, although SymPy should give us one).  Fall back to
    # exhaustive search if necessary.
    if sympy.n_order(psi, q) != 2 * n:
        for x in range(2, q):
            if sympy.n_order(x, q) == 2 * n:
                psi = x
                break
    return psi


def negacyclic_moduli_internal(n: int, count: int = 5, start_multiple: int = 1) -> List[NTTModulus]:
    """
    Search for the requested number of negacyclic-NTT friendly primes.

    Parameters
    ----------
    n              size of the NTT (degree of the negacyclic ring)
    count          how many primes to return
    start_multiple begin the search with q = (start_multiple)*(2n)+1

    Returns
    -------
    list of NTTModulus objects
    """
    if n <= 0:
        raise ValueError("n must be positive")
    if count <= 0:
        raise ValueError("count must be positive")

    results: List[NTTModulus] = []
    for q in _candidate_primes(n, start_multiple):
        if not sympy.isprime(q):
            continue

        psi = _find_psi(q, n)

        # Check the negacyclic conditions
        if pow(psi, n, q) != q - 1: # psi^n ≡ -1  ?
            continue
        if pow(psi, 2 * n, q) != 1: # psi^(2n) ≡ 1 ?
            continue
        if sympy.n_order(psi, q) != 2 * n: # order exactly 2n?
            continue

        omega = pow(psi, 2, q) # primitive n-th root
        results.append(NTTModulus(q, psi, omega, n))
        if len(results) >= count:
            break
    return results


def convert_primesize_to_kmultiple(prime_size: int, scheme_SIMD_slots: int) -> int:
    #prime_size = (start_multiple)*(2*scheme_SIMD_slots)+1
    start_multiple = (prime_size-1)//(2*scheme_SIMD_slots)
    return start_multiple

def negacyclic_moduli(n: int, count: int, prime_size: int) -> List[NTTModulus]:
    start_multiple = convert_primesize_to_kmultiple(prime_size,n)
    return negacyclic_moduli_internal(n,count,start_multiple)


if __name__ == "__main__":
    import argparse, textwrap

    parser = argparse.ArgumentParser(
        description="Search for negacyclic-NTT friendly primes.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Example:
              python ntt_primes.py -n 256 -c 3
            will print the first three primes q such that 512 | (q-1)
            together with suitable roots of unity.
        """))
    parser.add_argument("-n",  type=int, default=256,
                        help="transform length (default: 256)")
    parser.add_argument("-c", "--count",  type=int, default=5,
                        help="how many primes to list (default: 5)")
    parser.add_argument("-k", "--kstart", type=int, default=1,
                        help="start the search with q = k*(2n)+1  (default: 1)")
    args = parser.parse_args()

    print(f"Searching for {args.count} negacyclic-NTT friendly primes "
          f"for n = {args.n} ...\n")
    for i, modulus in enumerate(negacyclic_moduli_internal(args.n, count=args.count, start_multiple=args.kstart), 1):
        print(f"[{i}] {modulus.q}")
        print(modulus)
        print("-" * 60)
