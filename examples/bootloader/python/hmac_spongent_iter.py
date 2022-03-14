'''
 # @ Author: German Cano Quiveu, germancq@dte.us.es
 # @ Create Time: 2020-07-09 14:57:23
 # @ Modified by: Your name
 # @ Modified time: 2020-07-09 14:57:25
 # @ Description:
 '''

import os
import sys
import spongent_iter

class HMAC_Spongent_iter:

    def __init__(self,key,n,c,r,R):
        self.key = key
        self.n = n
        self.r = r
        self.hash_function = spongent_iter.Spongent(n,c,r,R)
        self.ipad = self.generate_bit_pattern('00110110',n)
        self.opad = self.generate_bit_pattern('01011100',n)
        self.spongent_state = 0
        self.h_1 = 0
        self.mask = 0xFFFF
        if(self.r == 8):
            self.mask = 0xFF
        self.result = 0    

    def generate_bit_pattern(self,pattern,len) :
        #pattern is a bit string of 8 bits
        str_result = ''
        number_steps = int(len/8)

        for _ in range(0,number_steps):
            str_result = str_result + pattern

        return int(str_result, 2) 

    def begin_hmac(self):
        self.S_i = self.ipad ^ self.key
        j = int(self.n/self.r)
        self.spongent_state = 0
        for i in range (0,j):
            data_chunk = (self.S_i >> (self.r*(j-i-1))) & self.mask
            #print(hex(data_chunk))
            self.spongent_state = self.hash_function.feed_data(data_chunk,self.spongent_state)
            #print(hex(self.spongent_state))


    def feed_data(self,block_value):
        self.spongent_state = self.hash_function.feed_data(block_value,self.spongent_state)

    def stop_feed(self):
        self.S_o = self.opad ^ self.key   
        self.h_1 = self.hash_function.squeezing_phase(self.spongent_state)
        self.spongent_state = 0
        j = int(self.n/self.r)
        for i in range (0,j):
            data_chunk = (self.S_o >> (self.r*(j-i-1))) & self.mask
            self.spongent_state = self.hash_function.feed_data(data_chunk,self.spongent_state)
        for k in range (0,j):
            data_chunk = (self.h_1 >> (self.r*(j-k-1))) & self.mask
            self.spongent_state = self.hash_function.feed_data(data_chunk,self.spongent_state)  
        self.result =  self.hash_function.squeezing_phase(self.spongent_state)
        return self.result    



if __name__ == "__main__":
    key = 0x1122334455667788
    msg = 0x8B92
    expected = 0xf77c3b3a062d62bb08dde9
    for t in range (0,0x10000):
        
        msg = 0x0000
        print(hex(msg))
        for k in range (1,3):
            #print(k)
            len_msg = 8*k#64
            r = 8
            j = int(len_msg/r)

            hmac_impl = HMAC_Spongent_iter(key,88,80,r,45)
            hmac_impl.begin_hmac()
            for i in range(0,j):
                data_chunk = (msg >> (r*(j-i-1))) & hmac_impl.mask
                print(hex(data_chunk))
                hmac_impl.feed_data(data_chunk)
            result = hmac_impl.stop_feed()
            print(hex(result))
            if(expected == result):
                print(hex(result))
                print(hex(msg))
                break

        if(expected == result):
                break