import sys
import binascii
import collections
from os import listdir
from os.path import isfile, join, basename



def main():		
	with open(sys.argv[1],"wb") as output_file:
		onlyfiles = [f for f in listdir(sys.argv[2]) if isfile(join(sys.argv[2], f))]
		for file_a in onlyfiles:
			#s = sys.argv[3] + file_a.basename() + "\n"
			output_file.write(sys.argv[3]+file_a+"\n")	


if __name__ == "__main__":
    main()
