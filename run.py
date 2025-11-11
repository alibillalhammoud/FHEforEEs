import numpy as np
from BFV_config import BFVSchemeConfiguration
from BFV_model import BFVSchemeClient, BFVSchemeServer


if __name__ == "__main__":
    t = 65537
    n = 8 
    q = t*9000000000 # q >> t, t divides q, q must be around 300-330 bits for practical security
    vector1 = np.array([1, 2, 3 ,4 ,5 ,6, 7, 8] )#+ 120*[1])
    vector2 = np.array([2, 3, 4 ,5 ,4 ,3, 2, 3] )#+ 120*[1])
    plaintext = np.array([1,2,3,4,5,6,7,8])
    #plaintext = np.array(8*[2])

    # setup
    config = BFVSchemeConfiguration(t, q, n, False)
    client = BFVSchemeClient(config)
    server = BFVSchemeServer(config)
    # encrypt messages
    cipher1 = client.encrypt(vector1)
    cipher2 = client.encrypt(vector2)
    A1, B1 = cipher1
    A2, B2 = cipher2
    #print(f"cipher 1\n{cipher1}\n")
    #print(f"cipher 2\n{cipher2}\n")
    computed_cipher = server.add_ciphercipher(A1, B1, A2, B2)
    #print(f"cipher 1+cipher 2\n{computed_cipher}\n")
    computed_cipherm = server.mul_cipherplain(A1, B1, plaintext)
    # decrypt
    Ao, Bo = computed_cipherm
    result = client.decrypt(Ao, Bo)
    print(result.astype(np.int64))

