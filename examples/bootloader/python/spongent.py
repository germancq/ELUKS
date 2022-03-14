# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    spongent.py                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: germancq <germancq@dte.us.es>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/12/02 13:14:32 by germancq          #+#    #+#              #
#    Updated: 2019/12/02 13:14:47 by germancq         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

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
        

    def generate_hash(self,message, len_msg=0):
        self.initialization_phase(message,len_msg)
        s = self.absorbing_phase()
        #print(hex(s))
        return self.squeezing_phase(s)


    def initialization_phase(self,message,len_msg=0):
        #padding message with 1 
        message = message << 1
        message = message | 0x1
        #fill with zeros until r multiple
        bit_len_msg = len_msg + 1
        if len_msg == 0:
            bit_len_msg = math.floor(math.log2(message)) + 1

        #print(bit_len_msg)
        n = bit_len_msg % self.r
        message = message << (self.r - n)
        #cut into blocks of r bits
        #print(hex(message))
        self.padded_msg = message
        self.m = []
        self.mask = 0xFFFF
        if(self.r == 8):
            self.mask = 0xFF

        
            
        for i in range(0,int(bit_len_msg/self.r)+1):
            message_part = ((message >> (self.r * i)) & self.mask)      
            if(self.r == 16):
                message_part = (message_part >> 8) | ((message_part & 0XFF) << 8)         
            self.m.append(message_part) 
        
        
        

    def absorbing_phase(self):
        state = 0
        
        self.absorbing_before_p_states=[]
        self.absorbing_after_p_states=[]
        for i in range(0,len(self.m)):
            block_value = self.m[len(self.m)-1-i]
            print(hex(block_value))
            state = state ^ block_value
            self.absorbing_before_p_states.append(state)
            #print('------------------')
            #print(hex(state))
            #print('------------------')
            state = self.permutation(state)
            #print('***********************')
            #print(hex(state))
            #print('***********************')
            self.absorbing_after_p_states.append(state)

            
            
        return state   
        


    def squeezing_phase(self,state):
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
    spongent_impl = Spongent(88,80,8,45)
    
    message = 0x7d5e997271ef4ea2
    print(message)
    print(hex(message))

    hash_value = spongent_impl.generate_hash(message,64)
    
    print(hash_value)
    print(hex(hash_value))