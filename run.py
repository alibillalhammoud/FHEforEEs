import numpy as np
from BFV_config import BFVSchemeConfiguration
from BFV_model import BFVSchemeClient, BFVSchemeServer


if __name__ == "__main__":
    t = 17             # example prime, pick this to bigger to get bigger results
    n = 8              # degree + 1 => degree 7 polynomials
    q = 65299          # q >> t, t divides q, 17*3837
    message1 = np.array([1 , 2, 3 ,4 ,5 ,6, 7, 8])
    message2 = np.array([2 , 1, 4 ,3 ,6 ,5, 8, 7])

    # setup
    config = BFVSchemeConfiguration(t, q, n, False)
    client = BFVSchemeClient(config)
    server = BFVSchemeServer(config)
    # encrypt messages
    cipher1 = client.encrypt(message1)
    cipher2 = client.encrypt(message2)
    A1, B1 = cipher1
    A2, B2 = cipher2
    computed_cipher = server.add_ciphercipher(A1, B1, A2, B2)
    # decrypt
    Ao, Bo = computed_cipher
    result = client.decrypt(Ao, Bo)
    print(np.round(result))
