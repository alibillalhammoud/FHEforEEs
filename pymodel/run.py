import numpy as np
from BFV_config import BFVSchemeConfiguration
from BFV_model import BFVSchemeClient, BFVSchemeServer


if __name__ == "__main__":
    t = 257 #65537 # prime number, t%(2n)=1
    n = 8 # power of 2
    desired_q_numbits = 100 # q >> t, t divides q (and is an even multiple of t), q must be 300+ bits for practical security
    vector1 = np.array([1, 2, 3 ,4 ,5 ,6, 7, 8] )#+ 120*[1])
    vector2 = np.array([2, 3, 4 ,5 ,4 ,3, 2, 3] )#+ 120*[1])
    plaintext = np.array([1,2,3,4,5,6,7,8])
    # setup
    config = BFVSchemeConfiguration(t, desired_q_numbits, n, False)
    print("choosen q was",config.q)
    print("\n\n\n")
    client = BFVSchemeClient(config)
    server = BFVSchemeServer(config)
    # encrypt messages
    cipher1 = client.encrypt(vector1)
    cipher2 = client.encrypt(vector2)
    A1, B1 = cipher1
    A2, B2 = cipher2

    rlev = client.relin_keys
    # run tests
    #computed_cipher_ctptadd = server.add_cipherplain(A1, B1, plaintext)    # WORKING!!!
    #computed_cipher_ctctadd = server.add_ciphercipher(A1, B1, A2, B2)      # WORKING!!!
    #computed_cipher_ctptmul = server.mul_cipherplain(A1, B1, plaintext)    # WORKING!!!
    computed_cipher_ctctmul = server.mul_ciphercipher(A1, B1, A2, B2, rlev)
    # decrypt
    Ao, Bo = computed_cipher_ctctmul
    result = client.decrypt(Ao, Bo)
    print(type(result[0]))
    print(result)
    #print(result.astype(np.int64))

