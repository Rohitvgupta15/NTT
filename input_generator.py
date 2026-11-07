"""
Generate random 256-coefficient input and golden NTT output for ML-KEM (q = 3329)
Compatible with Python 3.6+
"""

import random

Q = 3329
N = 256
ROOT_OF_UNITY = 17

def bit_reverse_7(x):
    res = 0
    for _ in range(7):
        res = (res << 1) | (x & 1)
        x >>= 1
    return res

# Precompute bit-reversed powers of zeta mod 3329
ZETAS = [pow(ROOT_OF_UNITY, bit_reverse_7(i), Q) for i in range(128)]

def ntt_mlkem(f):
    """Forward NTT according to FIPS 203 (ML-KEM) Algorithm 8."""
    f_hat = list(f)
    k = 1
    length = 128
    while length >= 2:
        start = 0
        while start < 256:
            zeta = ZETAS[k]
            k += 1
            for j in range(start, start + length):
                t = (zeta * f_hat[j + length]) % Q
                f_hat[j + length] = (f_hat[j] - t) % Q
                f_hat[j] = (f_hat[j] + t) % Q
            start += 2 * length
        length //= 2
    return f_hat

def format_hex_lines(coefficients):
    lines = []
    for i in range(0, len(coefficients), 16):
        chunk = coefficients[i:i + 16]
        lines.append(" ".join(f"{val:03x}" for val in chunk))
    return "\n".join(lines)

# Generate 256 random coefficients in [0, 3328]
random_input = [random.randint(0, Q - 1) for _ in range(N)]
golden_output = ntt_mlkem(random_input)

# Write to files
with open("ntt256_input.hex", "w") as f:
    f.write(format_hex_lines(random_input) + "\n")

with open("ntt256_golden.hex", "w") as f:
    f.write(format_hex_lines(golden_output) + "\n")

print("Files 'ntt256_input.hex' and 'ntt256_golden.hex' created successfully.")