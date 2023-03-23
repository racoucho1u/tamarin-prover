import csv
import os
from os.path import exists
import re

cases = ["develop","escapeLoop","backtracking","blackListing","smartverif"]
fields = ["Filename","develop","escapeLoop","backtracking","blackListing","smartverif"]

rows = []
names = []

def filename(file):
	tab = re.split(r'\t',file)[1]
	return(os.path.splitext(tab)[0])

def split(line):
	return(line.split(",")[1][:-1])

inputfile = "files_to_benchmark/inputscript_filesToBenchmark.txt"
if (exists(inputfile)):
	with open(inputfile, mode ='r') as file:
		lines = file.readlines()
		names = map(filename,lines)
		rows.append(list(names))
else:
	quit()

for case in cases:

	resFile = f"files_to_benchmark/recapfile_{case}.csv"
	row = [[] for i in range(83)]

	if (exists(resFile)):
		with open(resFile, mode ='r') as file:
			lines = file.readlines()[-83:]

			if (not f"New try {case}\n" in resFile):
				
				row = map(split,lines)
	rows.append(list(row))

res = map(list,zip(*rows))

result = "ouiii.csv"
with open(result, 'w') as csvfile: 
    # creating a csv writer object 
    csvwriter = csv.writer(csvfile) 
        
    # writing the fields 
    csvwriter.writerow(fields) 
        
    # writing the data rows 
    csvwriter.writerows(res)
			


