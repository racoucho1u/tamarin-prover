import json

####################################
# Merge the results from the 
# the different servers results
# for final strategies benchmark
# Works on extracted results 
# (see results.py script.py)
####################################

if __name__ == "__main__":

    mergedFile = "execution_report_extracted_merged.json"
    extractedResultsFiles = "execution_report_extracted.json"

    resultsDir = ["server_1_1","server_1_2","server_2_1","server_2_2","server_3"]
    resultsDirPrefix = "../results/result_strategiesBenchmark_"
    resultsDirSuffix = "/execution_report_extracted.json"

    with open(resultsDirPrefix+resultsDir[0]+resultsDirSuffix,'r') as file:
        finalDict = json.load(file)
    strat = ["original","escape","backtrack","backAndAvoid","proba","collectAndRestart"]

    for d in resultsDir[1:]:
        with open(resultsDirPrefix+d+resultsDirSuffix,'r') as file:
            res =json.load(file)
            for s in strat:
                stratPartialRes = res[s]['lemmas']
                # print(stratPartialRes)
                # for r in stratPartialRes:
                finalDict[s]['lemmas'].update(stratPartialRes)
    
        with open(resultsDirPrefix+"merged.json",'w') as file:
            json.dump(finalDict,file,indent=4)