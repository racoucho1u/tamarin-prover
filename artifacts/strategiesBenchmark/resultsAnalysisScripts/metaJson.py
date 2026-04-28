import json
import pandas as pd

input_file = "analysisRes.ods"
metaSheet = pd.read_excel(input_file, engine="odf", sheet_name='metaData')
columnsMeta  = list(metaSheet.columns.ravel())

lemmas    = metaSheet[columnsMeta[0]].tolist()
typeL     = metaSheet[columnsMeta[2]].tolist()
oracle    = metaSheet[columnsMeta[3]].tolist()
oracleSt  = metaSheet[columnsMeta[4]].tolist()
dirnames  = metaSheet[columnsMeta[5]].tolist()
macros    = metaSheet[columnsMeta[6]].tolist()
diff	  = metaSheet[columnsMeta[7]].tolist()

dicts = []

i = 0
while i < len(lemmas):
	if (isinstance(oracle[i], float)):  # nan is considered as a float
		print(oracle[i],isinstance(oracle[i], float))
		if i > 1:  						# first file already has been treated
			dicts.append(bufDictFile)
		bufDictFile = {
			"filename": lemmas[i],
			"dirname": dirnames[i],
			"lemmas": [] 
		}
		print
	else:
		bufDictLemma = {
			"lemmaName": lemmas[i],
			"macro": macros[i],
			"type": typeL[i],
			"diff": isinstance(diff[i],int),
			"oracle": oracle[i],
			"oracleStatus": oracleSt[i]
		}
		bufDictFile["lemmas"].append(bufDictLemma)
	i += 1

dicts.append(bufDictFile)
finalDict = {
	"dicts": dicts
}
with open("metaData.json", "w") as outfile:
	json.dump(finalDict, outfile,indent=4)