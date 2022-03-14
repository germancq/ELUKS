# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    keyDerivationFunction.py                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: germancq <germancq@dte.us.es>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/10/17 15:49:52 by germancq          #+#    #+#              #
#    Updated: 2021/10/20 12:16:21 by germancq         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

import importlib
import sys
import spongent


class KDF:
    def __init__ (self,count,salt,user_password,N=128,c=128,r=8,R=70,salt_len=64,user_password_len=32,count_len=32):

        #count_len + user_password_len + salt_len <= N
        
        self.count = count #valores de 32 bits
        self.salt = salt 
        self.user_password = user_password 
        self.N = N
        self.hash_function = spongent.Spongent(N,c,r,R)
        self.salt_len = salt_len
        self.count_len = count_len
        self.user_password_len = user_password_len
        self.data_in_len = salt_len+user_password_len+count_len
        


    def generate_derivate_key(self):
        
        x_i = (self.user_password << (self.count_len+self.salt_len)) + (self.salt << self.count_len) + self.count
        #print(hex(x_i))
        for i in range(0,self.count):
            x_i = self.hash_function.generate_hash(x_i,self.data_in_len)
            #print(hex(i))

        return x_i

if __name__ == "__main__":
    kdf_impl = KDF(20,0x123456789ABCDEF0,0xAAAA)   
    kdf_value = kdf_impl.generate_derivate_key()
    #print(hex(kdf_value))