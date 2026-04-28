import json
import sys

debug = 2


def debugPrint(msg,level):
    if debug == level:
        print(msg)

def loadData(filename):
    d = None
    with open(filename) as f:
        d = json.load(f)
        debugPrint(d,0)
    return d

def guessStratFromOptions(options):
    if "--strategy=Escape" in options:
        return "escape"
    elif "--strategy=Backtrack" in options:
        return "backtrack"
    elif "--strategy=CollectAndRestart" in options:
        return "collectAndRestart"
    elif "--strategy=BackAndAvoid" in options:
        return "backAndAvoid"
    elif "--strategy=Proba" in options:
        return "proba"
    else:
        return "original"

def retrieveResults(dataDict):
    tasks = dataDict["tasks"]
    debugPrint(json.dumps(tasks, indent=4),1)
    for t in tasks:
        subtasks = tasks[t]["subtasks"]
        debugPrint(t,3)
        for s in subtasks:
            strat = guessStratFromOptions(subtasks[s]["task_config"]["options"])
            finalDict[strat]["lemmas"][s] = {
                "name": subtasks[s]["task_config"]["lemma"],
                "theory_file": t,
                "theory_dir": "not_available",
                "lemma_type": "",
                "oracleStatus": "",
                "target": False,
                "time": subtasks[s]["task_execution_metadata"]["exec_duration_monotonic"],
                "status": subtasks[s]["task_execution_metadata"]["status"],
                "tactic": "",
                "reason": ""
            }
    filenameInfos = s.split("--")[0]
    version = filenameInfos.split("_")[4:]
    return("_".join(version))

def completeMetaData(metaData,version):
    for s in strats:
        for dicts in metaData["dicts"]:
            filename = f"{dicts["dirname"]}--{dicts["filename"]}__{s}"
            for l in dicts["lemmas"]:
                lemmaName = l["lemmaName"]
                fullName = f"{filename}--{lemmaName}--merged"
                targetLemma = False
                if "target" in l:
                    targetLemma = l["target"]
                if fullName in finalDict[s]["lemmas"]:
                    # print(json.dumps(finalDict[s]["lemmas"],indent=4))
                    finalDict[s]["lemmas"][fullName]["lemma_type"] = str(l["type"])
                    finalDict[s]["lemmas"][fullName]["oracleStatus"] = l["oracleStatus"]
                    finalDict[s]["lemmas"][fullName]["target"] = targetLemma
                else:
                    debugPrint(f"lemma {fullName} not found in finalDict",2)

            

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: python3 analyseResultBatchTamarin.py report.json")
    filename = sys.argv[1]
    if len(sys.argv) > 2:
        debug = int(sys.argv[2])

    strats = ["original","escape","backtrack","backAndAvoid","proba","collectAndRestart"]
    finalDict = {}
    for s in strats:
        finalDict[s] = {
            "name": s,
            "lemmas": {}
        }

    data = loadData(filename)
    metaData = loadData("metaData.json")
    version = retrieveResults(data)
    completeMetaData(metaData,version)
    debugPrint(finalDict,4)

    print(filename)
    resultFile = f"{'.'.join(filename.split('.')[:-1])}_extracted.json"
    with open(resultFile,"w") as f:
        json.dump(finalDict, f)
    print(f"Results extracted in {resultFile}")