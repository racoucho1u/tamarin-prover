import sys
import argparse
import os
import subprocess
from collections import Counter

WRAPPER_PATH = "tamarin_wrapper.py"

def prettyPrintDeprioTactic(sortedDic):
	s = "tactic:"
	for i in sortedDic:
		if i != "End of branch\n":
			goal = i.replace('"','')
			s += "deprio: ---"
			s += "allGoal \""+goal[:-1]+"\"---"	
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
	tactic = ""
	if sortedT:
		tactic = prettyPrintDeprioTactic(sortedT)
	return(tactic)

def add_tactic_to_file(filename,tacticFile):
    inserTactic = "\n#include \""+tacticFile+"\"\n"
    with open(filename, "r") as f:
        contents = f.readlines()

    last_line = len(contents)-1
    while (not 'end' in contents[last_line]) and (last_line>0):
        if ("tacticGeneration/generatedTactics/" in contents[last_line]):
            contents.remove(contents[last_line])
        last_line -= 1
        
    contents.insert(last_line-1, inserTactic)

    with open(filename, "w") as f:
        contents = "".join(contents)
        f.write(contents)

def tamarin_wrapper_call(arg_list, time_out=6000):
    return subprocess.Popen(
        ["python3", WRAPPER_PATH]
        + arg_list
        + [
            "-t",
            str(time_out),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).communicate()

def prove_with_tactic(filename,lemma_name,macro,strategy,heuristic,tactic_nb,diff,timeout=6000):

    outputFile = filename.split("/")[-1]
    lemma_name_file = lemma_name.split(" ")[0]
    diffFlag = ""
    if diff != False:
        diffFlag = "--diff"
    print([filename, "-s", f"--lemma={lemma_name}",f"--tam=--heuristic={heuristic} {macro} --strategy={strategy} --exportGoals {diffFlag} --output=tacticGeneration/results/{strategy}_{lemma_name_file}_{outputFile}  2>> tacticGeneration/tacticBatch/{strategy}_{lemma_name_file}_{outputFile}"])
    out, err = tamarin_wrapper_call([filename, "-s", f"--lemma={lemma_name}",f"--tam=--heuristic={heuristic} {macro} --strategy={strategy} --exportGoals {diffFlag} --output=tacticGeneration/results/{strategy}_{lemma_name_file}_{outputFile}  2>> tacticGeneration/tacticBatch/{strategy}_{lemma_name_file}_{outputFile}"],timeout)
    if err:
        print(
            "Sanity check failed for: "
            + filename
            + ", lemma name: "
            + lemma_name
            + "\nError: "
            + err.decode(),
            file=sys.stderr,
        )
        # q.put("Sanity check failed for: "
        #     + filename
        #     + ", lemma name: "
        #     + lemma_name
        #     + "\nError: "
        #     + err.decode())
        sys.exit(1)

    for line in out.decode().rstrip().split("\n"):
        # Successful calls to the wrapper should produce a triple (data, status,time)
        # while timedout calls should produce the tuple (data, status,time,tactic)
        # not sure yet how the killed proofs are handled

        data = line.split(" ")
        # total_time += float(data[2])
        
        try:
            tactic = extractTacticsFile(f"tacticGeneration/tacticBatch/{strategy}_{lemma_name_file}_{outputFile}")
            if tactic != "":   
                tacticRough = tactic.split("tactic:")[1]
                deprios = tacticRough.replace("---","\n")
                tactic = "\ntactic: "+lemma_name_file+"_"+str(tactic_nb)+"\n"+deprios+"\n\n"
                # print(tactic)
                tacticFile = f"tacticGeneration/generatedTactics/{strategy}_{lemma_name_file}_{outputFile}"
                print(os.path.isfile(tacticFile))
                if not os.path.isfile(tacticFile):
                    add_tactic_to_file(filename,tacticFile)
                with open (tacticFile,'a') as f:
                    f.write(tactic)
                    f.write("\n")

        except Exception:
            with open ("tacticGeneration/debugFile",'a') as df:
                df.write(f"Tactic generation error: {filename}\n")
            tactic = "Error in generation"

        return(data[:4],tactic)

def proveUntil(file_path, lemma, macro, strategy, bound=3, heuristic="s", timeout=15, diff=False):
    tactic,tactic_updated, heuristic_old = "","new","old"
    proof_attempt = 0
    proved = False
    while proof_attempt<bound and tactic_updated != "Error in generation":
        if tactic == tactic_updated and tactic != "":
            break 
        if tactic_updated == "":
            heuristic = heuristic_old
        print(f"Proving {lemma} ({file_path}) with heuristic: {heuristic}, timeout: {timeout}")
        tactic = tactic_updated
        status, tactic_updated = prove_with_tactic(file_path,lemma,macro,strategy,heuristic,proof_attempt,diff,timeout)
        timeout *= 2
        if 'True' in status or 'False' in status:
            proved = True
            print(f"Prove lemma {lemma} (file:{file_path}) with heuristic: {heuristic}.\n")
            # q.put(f"Prove lemma {lemma} (file:{file_path}) with heuristic: {heuristic}.\n")
            # with open('results/scriptResult', 'a') as r:
            #     r.write(f"Prove lemma {lemma} (file:{file_path}) with heuristic: {heuristic}.\n")
            break
        heuristic_old = heuristic
        heuristic = "{"+lemma+"_"+str(proof_attempt)+"}"
        proof_attempt += 1
    if not proved:
        if (proof_attempt==bound):
            print(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): attempts bound reached ({bound}).\n")
            # q.put(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): attempts bound reached ({bound}).\n")
            # with open(f'results/scriptResult_{lemma}_{filepath}', 'a') as r:
            #     r.write(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): attempts bound reached ({bound}).\n")
        else:
            if tactic == tactic_updated:
                print(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): no tactic no longer changing.\n")
                # q.put(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): no tactic no longer changing.\n")
                # with open(f'results/scriptResult_{lemma}_{filepath}', 'a') as r:
                #     r.write(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): no tactic no longer changing.\n")
            else:
                if (tactic == tactic_updated and not proved) or tactic_updated == "":
                    print(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): new tactic empty.\n")
                    # q.put(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): new tactic empty.\n")
                    # with open(f'results/scriptResult_{lemma}_{filepath}', 'a') as r:
                    #     r.write(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): new tactic empty.\n")
                else:
                    if (tactic_updated == "Error in generation"):
                        print(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): problem in the tactic generation.\n")
                        # q.put(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): problem in the tactic generation.\n")
                    else:
                        print(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): unclear reason.\n")
                        # q.put(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): unclear reason.\n")
                    # with open(f'results/scriptResult_{lemma}_{filepath}', 'a') as r:
                    #     r.write(f"Cannot prove lemma {lemma} (file:{file_path}) after {proof_attempt} attempts (timeout={timeout}s): unclear reason.\nbound:{bound}, tactic={tactic}, tacticUpdated={tactic_updated}END")
  

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Tries to prove a lemma given a heuristic, \
                                        if proof fails, generate a tactic and tries again with it."
    )
    parser.add_argument("file", help="path to target file, can be a spthy file or a batch-tamarin recipe")
    parser.add_argument("lemma", help="lemma that need to be proven",)
    parser.add_argument("--strategy",type=str, default="Escape", help="strategy to use for the proof attempt")
    parser.add_argument("-b", "--bound", type=int, default=3, help="max number of proof attempt")
    parser.add_argument("-m", "--macro", type=str, default="", help="macro to use in the proof attempt (equivalent of tamarin -D option)")
    parser.add_argument("--heuristic", type=str, default="s", help="heuristic to use as the default for first attempt")
    parser.add_argument("--timeout", type=int, default=6000, help="timeout in s, default:6000")
    parser.add_argument("--diff", action='store_true', help="set if diff protocol")

    args = parser.parse_args()
    file_path = args.file
    lemma = args.lemma
    strategy = args.strategy
    macro = args.macro
    bound = int(args.bound)
    heuristic = args.heuristic
    
    timeout = args.timeout
    diff = args.diff

    print(timeout)

    if macro != "":
        macro = "-D"+macro

    if not os.path.isdir('tacticGeneration'):
        os.mkdir('tacticGeneration')
    if not os.path.isdir('tacticGeneration/results'):
        os.mkdir('tacticGeneration/results')
    if not os.path.isdir('tacticGeneration/tacticBatch'):
        os.mkdir('tacticGeneration/tacticBatch')
    if not os.path.isdir('tacticGeneration/generatedTactics'):
        os.mkdir('tacticGeneration/generatedTactics')
    if not os.path.isdir('tacticGeneration/debugFile'):
        open('tacticGeneration/debugFile', "w")

    proveUntil(file_path, lemma, macro, strategy, bound, heuristic, timeout, diff)