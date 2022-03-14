# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    LFSR.py                                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: germancq <germancq@dte.us.es>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/12/05 16:16:32 by germancq          #+#    #+#              #
#    Updated: 2019/12/10 17:07:09 by germancq         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

'''
    Linear Feedback Shift Register
        size: n bits

'''
class LFSR :

    def __init__(self,n,initial_state,feedback_coefficient) :
        #print()
        self.n = n
        self.state = initial_state
        self.fc = feedback_coefficient

    def set_state(self,state) :
        self.state = state

    def get_state(self):
        return self.state

    def step(self) :
        bits_selected = self.state & (self.fc >> 1)
        output_bit = 0
        for i in range(0,self.n):
            output_bit = output_bit ^ ((bits_selected >> i) & 0x1)  

        self.state = self.state << 1
        self.state = (output_bit & 0x1) | (self.state & ((2**self.n)-2))