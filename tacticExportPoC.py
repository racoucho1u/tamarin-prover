from collections import Counter
# import manipulateFile as mf

filename = "source"
spthyFile = "SourceOfUniqueness.spthy"



def prettyPrintDeprioTactic(sortedDic):
	s = "tactic:"
	for i in sortedDic:
		if i != "End of branch\n":
			goal = i.replace('"','')
			s += "deprio: ---"
			s += "\tallGoal \""+goal[:-1]+"\"---"	
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
	with open(filename) as f:
		lines = f.readlines()
		for l in lines:
			lsplit = l.split("---")
			if len(lsplit) > 1:
				goals.append(lsplit[2])
	iterationDic = Counter(goals)
	sortedT = {k: v for k, v in sorted(iterationDic.items(), key=lambda item: item[1])}
	print(sortedT)
	tactic = prettyPrintDeprioTactic(sortedT)
	print(tactic)

def extractTacticsParams(lines):
	goals = []
	for l in lines:
		lsplit = l.split("---")
		if len(lsplit) > 1:
			goals.append(lsplit[2])
	iterationDic = Counter(goals)
	sortedT = {k: v for k, v in sorted(iterationDic.items(), key=lambda item: item[1])}
	tactic = prettyPrintDeprioTactic(sortedT)
	return(tactic)

# if __name__ == __main__:
# 	extractTacticsFile(filename)