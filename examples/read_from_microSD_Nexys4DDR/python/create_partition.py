'''
 # @ Author: German Cano Quiveu, germancq
 # @ Create Time: 2021-10-14 17:27:49
 # @ Modified by: German Cano Quiveu, germancq
 # @ Modified time: 2021-10-14 17:27:55
 # @ Description:
 '''
import os
import sys
import math
from random import SystemRandom
import importlib
import random
import sys
import keyDerivationFunction
import present_ctr
import hmac_spongent_iter

SIZE_BLOCK = 512
ELUKS_SIGNATURE = 0xAABBCCDDEEFF
USER_PASSWORD_FPGA = 0x1122334455667788
ACTIVATE_SIGNATURE = 0x22446688

N_candidates =        [88,128,160,224,256]
r_candidates =        [8,8,16,16,16]
c_candidates =        [80,128,160,224,256]
R_candidates =        [45,70,90,120,140]

OPTION_HASH = 0
OPTION_KDF = 0

N = N_candidates[OPTION_HASH]
r = r_candidates[OPTION_HASH]
c = c_candidates[OPTION_HASH]
R = R_candidates[OPTION_HASH]

N_kdf = N_candidates[OPTION_KDF]
r_kdf = r_candidates[OPTION_KDF]
c_kdf = c_candidates[OPTION_KDF]
R_kdf = R_candidates[OPTION_KDF]

BLOCK_LEN = 64
DIGEST_LEN = N_kdf
KEY_LEN = 80
SALT_LEN = 64
PSW_LEN = 64
COUNT_LEN = 32
COUNT_VALUE = (2**5) - 1
USER_BLOCKS_NUM_BITS = 32


def main() :
    file_to_encrypt = os.path.isfile(sys.argv[2])
    new_file = os.path.isfile(sys.argv[1])
    
    if not file_to_encrypt:
        print("File not exist")  
    else :
       if not new_file:
            os.mknod(sys.argv[1]) # create file
            str_cmd = "touch %s" % (sys.argv[1])
            os.system(str_cmd)       
       
       with open(sys.argv[1],"r+b") as new_file: 
           with open(sys.argv[2],"r+b") as file_to_encrypt: 
               
               size_raw_data_bytes = os.stat(file_to_encrypt.fileno()).st_size
               raw_blocks = math.ceil(size_raw_data_bytes/SIZE_BLOCK)
               
                              
               master_key,mk_count,mk_salt,mk_digest,master_IV = cryptography_values()
               
               
               write_user_data(new_file,file_to_encrypt,master_key,master_IV,raw_blocks)

               mk_hmac = create_hmac_digest(new_file,master_key,raw_blocks)
               
               create_luks_block(new_file,mk_digest,mk_count,mk_salt,mk_hmac,master_IV,raw_blocks)

               create_key_slot(new_file,master_key,mk_salt,USER_PASSWORD_FPGA,0)
               
               offset = 10
               write_original_file(new_file,file_to_encrypt,raw_blocks,offset)

               
           

def write_original_file(new_file,file_to_encrypt,raw_blocks,offset):
    file_to_encrypt.seek(0)
    offset_data = raw_blocks+1+offset
    print('total raw blocks:')
    print(raw_blocks)
    print('offset raw data:')
    print(offset_data)
    new_file.seek(offset_data*SIZE_BLOCK)
    new_file.write(file_to_encrypt.read())

def create_hmac_digest(new_file,master_key,raw_blocks):    
    new_file.seek(1*SIZE_BLOCK)
    i = 0
    hmac_impl = hmac_spongent_iter.HMAC_Spongent_iter(master_key,N,c,r,R)
    hmac_impl.begin_hmac()
    while i < int((raw_blocks*512)/int(r/8)) :
        if i%1024 == 0:
            print(i)
        data_chunk = int.from_bytes(new_file.read(int(r/8)),byteorder='big')
        hmac_impl.feed_data(data_chunk)
        i = i+1
    print('end_feed_data')
    mk_hmac = hmac_impl.stop_feed()
    return mk_hmac    

def cryptography_values() :
    cryptogen = SystemRandom()
    
    master_key = cryptogen.randrange(2**KEY_LEN)  
    master_key_count = COUNT_VALUE
    master_key_salt = cryptogen.randrange(2**SALT_LEN)

    master_IV = cryptogen.randrange(2**BLOCK_LEN)

    kdf_inst = keyDerivationFunction.KDF(master_key_count,master_key_salt,master_key,N_kdf,c_kdf,r_kdf,R_kdf,SALT_LEN,KEY_LEN,COUNT_LEN)
    mk_digest = kdf_inst.generate_derivate_key()

    return (master_key,master_key_count,master_key_salt,mk_digest,master_IV)

def create_luks_block(new_file,mk_digest,mk_count,mk_salt,mk_hmac,mk_IV,raw_blocks):
    new_file.seek(0)
    new_file.write(ELUKS_SIGNATURE.to_bytes(6,byteorder='little'))
    new_file.write(mk_digest.to_bytes(int(DIGEST_LEN/8),byteorder='little'))
    new_file.write(mk_count.to_bytes(int(COUNT_LEN/8),byteorder='little'))
    new_file.write(mk_salt.to_bytes(int(SALT_LEN/8),byteorder='little'))
    new_file.write(mk_hmac.to_bytes(int(N/8),byteorder='little'))
    new_file.write(mk_IV.to_bytes(int(BLOCK_LEN/8),byteorder='little'))
    new_file.write(raw_blocks.to_bytes(int(USER_BLOCKS_NUM_BITS/8),byteorder='little'))


def create_key_slot(new_file,master_key,master_key_salt,user_password,n_slot):
    cryptogen = SystemRandom()
    ks_salt = cryptogen.randrange(2**SALT_LEN)
    ks_count = COUNT_VALUE
    kdf_inst = keyDerivationFunction.KDF(ks_count,ks_salt,user_password,N_kdf,c_kdf,r_kdf,R_kdf,SALT_LEN,KEY_LEN,COUNT_LEN)
    ks_digest = kdf_inst.generate_derivate_key()

    key_IV = cryptogen.randrange(2**BLOCK_LEN)

    key_slot_pass = ks_digest & ((2**(KEY_LEN)) - 1)
    pwd_encrypted = 0
    LOOP_COUNT = math.ceil(KEY_LEN/BLOCK_LEN)
    PWD_ENCRYPT_LEN = LOOP_COUNT * BLOCK_LEN
    present_impl = present_ctr.Present_CTR(key_slot_pass,key_IV)

    print(hex(key_IV))
    print(hex(key_slot_pass))

    for i in range(0,LOOP_COUNT):
        plaintext = shift_rigth_data(master_key,i*BLOCK_LEN,KEY_LEN)
        plaintext = plaintext & ((2**BLOCK_LEN)-1)
        print(hex(plaintext))
        ciphertext = present_impl.encryption_decryption(plaintext,i)
        print(hex(ciphertext))
        pwd_encrypted = (ciphertext<<(i*BLOCK_LEN)) + pwd_encrypted 
    
    offset_luks_blok = 6+int((DIGEST_LEN+COUNT_LEN+SALT_LEN+N+BLOCK_LEN+USER_BLOCKS_NUM_BITS)/8)
    size_key_slot = 4 + int((COUNT_LEN+SALT_LEN+PWD_ENCRYPT_LEN+N+BLOCK_LEN)/8)

    new_file.seek(offset_luks_blok + (n_slot*size_key_slot))    
    new_file.write(ACTIVATE_SIGNATURE.to_bytes(4,byteorder='little'))
    new_file.write(ks_count.to_bytes(int(COUNT_LEN/8),byteorder='little'))
    new_file.write(ks_salt.to_bytes(int(SALT_LEN/8),byteorder='little'))
    print(hex(pwd_encrypted))
    print(int(PWD_ENCRYPT_LEN/8))
    new_file.write(pwd_encrypted.to_bytes(int(PWD_ENCRYPT_LEN/8),byteorder='little'))  
    new_file.write(key_IV.to_bytes(int(BLOCK_LEN/8),byteorder='little'))   
        
             
def write_user_data(new_file,file_to_encrypt,master_key,master_IV, raw_blocks):
    present_impl = present_ctr.Present_CTR(master_key,master_IV)
    #bytes_size = os.stat(file_to_encrypt.fileno()).st_size
    #bytes_to_encrypt = SIZE_BLOCK * math.ceil(bytes_size/SIZE_BLOCK)
    bytes_to_encrypt = (raw_blocks*512)
    file_to_encrypt.seek(0)
    new_file.seek(1*SIZE_BLOCK)
    print(bytes_to_encrypt)
    i = 0
    j = 0
    zero = 0
    while i < bytes_to_encrypt :
        x = int.from_bytes(file_to_encrypt.read(int(BLOCK_LEN/8)),byteorder='little')
        #print(hex(x))
        y = present_impl.encryption_decryption(x,j)
        new_file.write(y.to_bytes(int(BLOCK_LEN/8),byteorder='little'))
        i = i + int(BLOCK_LEN/8)
        j = j+1

    
        



def from_bytes (data, big_endian = False):
    if isinstance(data, str):
        data = bytearray(data)
    if big_endian:
        data = reversed(data)
    num = 0
    for offset, byte in enumerate(data):
        num += byte << (offset * 8)
    return num


def shift_rigth_data(data,shr,bits_len):
    shift_data =  data >> shr
    rotated_bits = data & ((2**shr)-1)
    return (rotated_bits << (bits_len-shr)) + shift_data 


if __name__ == "__main__":
    main()