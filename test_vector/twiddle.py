def generate_twiddle_hex(N, q, omega, filename="twiddle.hex", montgomery=False, R=None):
    """
    N: Transform length
    q: Modulus
    omega: Primitive N-th root of unity modulo q
    montgomery: Set True if storing in Montgomery form (W * R mod q)
    R: 1 << DATA_WIDTH (used if montgomery=True)
    """
    entries = N // 2
    factors = []
    
    current = 1
    for i in range(entries):
        val = current
        if montgomery:
            val = (val * R) % q
        factors.append(val)
        current = (current * omega) % q

    with open(filename, "w") as f:
        for val in factors:
            f.write(f"{val:X}\n")

# Example configuration for N=8, q=17, omega=2:
# generate_twiddle_hex(N=8, q=17, omega=2, filename="twiddle.hex")echo $LD_LIBRARY_PATH