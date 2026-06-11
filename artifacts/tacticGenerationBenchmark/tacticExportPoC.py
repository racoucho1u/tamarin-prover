from collections import Counter
import sys
# import manipulateFile as mf

filename = "source"
spthyFile = "SourceOfUniqueness.spthy"

def prettyPrintTactic(tactic,filename):
	tacticRough = tactic.split("tactic:")[1]
	deprios = tacticRough.replace("---","\n")
	lemma_name_file = filename.split('.')[0].split("/")[-1]
	tactic = "\ntactic: "+lemma_name_file+"\n"+deprios+"\n\n"
	print(tactic)

def prettyPrintDeprioTactic(sortedDic):
	s = "tactic:"
	for i in sortedDic:
		if i != "End of branch\n":
			goal = i.replace('"','')
			s += "deprio: ---"
			s += "allGoal \""+goal[:-1]+"\"---"	
	return(s)

def prettyPrintPrioTactic(sortedDic):
	s = "tactic: oui\n"
	for i in reversed(sortedDic):
		if i != "End of branch\n":
			goal = i.replace('"','')
			s += "prio: \n"
			s += "\tallGoal \""+goal[:-1]+"\"\n"	
	return(s)

def extractTacticsFile(filename):
	goals = []
	try:
		with open(filename, 'r') as f:
			lines = f.readlines()
			for l in lines:
				lsplit = l.split("---")
				if len(lsplit) > 1:
					goals.append(lsplit[2])
	except Exception:
		# with open ("debugFile",'a') as df:
		# 	df.write(f"Tactic generation error: {filename}\n")
		return "Error", []
			
	iterationDic = Counter(goals)
	sortedT = {k: v for k, v in sorted(iterationDic.items(), key=lambda item: item[1])}
	# print(sortedT)
	tactic = ""
	if sortedT:
		tactic = prettyPrintDeprioTactic(sortedT)
	return(tactic)

def extractTacticsParams(lines):
	goals = []
	tactic = ""
	for l in lines:
		lsplit = l.split("---")
		if len(lsplit) > 1:
			goals.append(lsplit[2])
	if len(goals)>0:
		iterationDic = Counter(goals)
		sortedT = {k: v for k, v in sorted(iterationDic.items(), key=lambda item: item[1])}
		tactic = prettyPrintDeprioTactic(sortedT)
	return(tactic)

if __name__ == "__main__":
	if len(sys.argv) > 1:
		filename = sys.argv[1]
		tactic = extractTacticsFile(filename)
		prettyPrintTactic(tactic,filename)
	else:
		print("Error: use python3 tacticExportPoC.py filenameWithRawData.spthy")
	