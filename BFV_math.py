import numpy as np

# naive multiplication
n = len(a)
c = np.convolve(a, b)
print(c)
c_mod = c[:n].copy()
for k in range(n, len(c)):
    c_mod[k-n] -= c[k]
