'''
 # @ Author: German Cano Quiveu, germancq@dte.us.es
 # @ Create Time: 2020-06-25 22:20:02
 # @ Modified by: Your name
 # @ Modified time: 2020-06-25 22:20:16
 # @ Description:
 '''

import LFSR
import math
import struct
import numpy as np

S_box = [0xE,0xD,0xB,0x0,0x2,0x1,0x4,0xF,0x7,0xA,0x8,0x5,0x9,0xC,0x3,0x6]

class Spongent:

    def __init__(self,n,c,r,R) :
        self.n = n
        self.c = c
        self.r = r
        self.R = R
        self.b = r + c
        self.state = 0
        self.initialize_lCounter()
        self.mask = 0xFFFF
        self.padding = 0x8000
        if(self.r == 8):
            self.mask = 0xFF
            self.padding = 0x80
         
        
        
    def feed_data(self,block_value,state):
        if(self.r == 16):
            block_value = (block_value >> 8) | ((block_value & 0XFF) << 8) 
        state = block_value ^ state
        state = self.permutation(state)
        return state


    def squeezing_phase(self,state):
        state = self.feed_data(self.padding,state)
        result = 0
        self.squeezing_results = []
        self.squeezing_states = []
        for i in range(0, int(self.n/self.r)):
           value = state & self.mask
           if(self.r == 16):
               value = (value >> 8) | ((value & 0XFF) << 8)   
           result = value | result   
           self.squeezing_results.append(result)
           result = result << self.r
           self.squeezing_states.append(state)
           #print(hex(result))  
           state = self.permutation(state)

        return result>>self.r

    def initialize_lCounter(self):
        size = math.ceil(math.log2(self.R))
        
        initial_state_options = {
            88: 0x5,
            128: 0x7A,
            160: 0x45,
            224: 0x01,
            256: 0x9E
        }

        feedback_coefficients_options = {
            88: 0x61,
            128: 0xC1,
            160: 0xC1,
            224: 0xC1,
            256: 0x11D
        }

        self.initial_lCounter_state = initial_state_options.get(self.n,0x0)
        feedback_coefficients = feedback_coefficients_options.get(self.n,0x0)

        self.lCounter = LFSR.LFSR(size,self.initial_lCounter_state,feedback_coefficients)


    def permutation(self,state):
        self.lCounter.set_state(self.initial_lCounter_state)
        for i in range (0,self.R):
            state = self.iteration_permutation(state)
            #print(hex(state))
            
        return state

    def iteration_permutation(self,state):
        reverse_counter = self.reverse_bits(self.lCounter.get_state(),self.lCounter.n)

        state = state ^ (reverse_counter << (self.b - self.lCounter.n)) ^ self.lCounter.get_state()
        

        self.lCounter.step() 
        
        state = self.sBoxLayer(state)   
        
        state = self.pLayer(state)
        
        return state    
    
    def reverse_bits(self,data,bits):
        result = 0
        for i in range (0,bits):
           result = (((data>>(bits-i-1)) & 0x1))<<i | result
        return result   
                    
    def sBoxLayer(self,state):
        new_state = 0
        for i in range(0,int(self.b/4)):
            index = (state >> 4*i) & 0xF    
            new_state = (S_box[index]<<4*i) | new_state
        
        return new_state   
        
    def pLayer(self,state):
        new_state = 0
        for i in range (0,self.b): 
            bit_pos = int(i * (self.b/4)) % (self.b-1)
            if(i == self.b-1):
                bit_pos = i
            value_bit = (state >> i) & 0x1
            new_state = (value_bit << bit_pos) | new_state
            
        return new_state
                

                


if __name__ == "__main__":
    #print()   
    r = 8 
    spongent_impl = Spongent(88,80,r,45)
    
    message = 0#0x7d5e997271ef4ea2
    print(message)
    print(hex(message))
    for t in range(1,2):
        len_msg = 8 * t
        mask = 0xFFFF
        #padding = 0x8000
        if(r == 8):
            mask = 0xFF
            #padding = 0x80
        j = int(len_msg/r)
        spongent_state = 0
        for i in range(0,j):
            data_chunk = 0#(message >> (r*(j-i-1))) & mask
            spongent_state = spongent_impl.feed_data(data_chunk,spongent_state)
            print(hex(spongent_state))
            
        #spongent_state = spongent_impl.feed_data(padding,spongent_state)
        hash_value = spongent_impl.squeezing_phase(spongent_state)

        print(j)
        print(hex(hash_value))
        

        