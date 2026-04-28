import re
import tacticGenerationMerged as mf
import argparse
import os

def generateInputFile(filename, diff, lemmaFile, diir, benchmarkcase, constructedInput,log):
	inputs = []
	lemmas = []

	fi = f"files_to_benchmark/input_lemmas_tacticGen/{lemmaFile}"
	# fi = f"files_to_benchmark/input_lemmas_tacticGen/{lemmaFile}"

	with open(fi) as f:
			lines = f.readlines()
			for line in lines:
				if line[0] != "#":

					lemma = re.sub(r"\s+$", "", line, 0, re.MULTILINE)
					lemmas.append(lemma)
	with open(constructedInput,'a') as ci:
		for lemma in lemmas:
			ci.write(f"{diir}\t{filename}\t{lemma}\t{diff}\n")
			inputs.append((filename, diff, lemma, diir,benchmarkcase,log))
	return(inputs)

if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Benchmark for tactic generation"
    )
    parser.add_argument("--strategy",type=str, default="Escape", help="strategy to use for the proof attempt")
    args = parser.parse_args()
    strategy = args.strategy

    benchmarkCase = "tacticGeneration/tamarin-prover"
    # file = "files_to_benchmark/input_lemmas_tacticGen.txt"
    # constructedInput = "files_to_benchmark/currentLemmaInput"
    # log = "files_to_benchmark/log"
    file = "files_to_benchmark/input_lemmas_tacticGen.txt"
    constructedInput = "files_to_benchmark/currentLemmaInput"
    log = "files_to_benchmark/log"

    parallel_input=[]
    with open(file) as f:
        lines = f.readlines()
        inputsRough,inputs = [],[]
        for line in lines:
            if line[0] != "#":
				#params = filename,setDiff,lemma,caseStudy,benchmarkCase,log
                params = re.split(r'\t',line)
                print(params)
                #print(parseAndRun((params[1], params[0], params[2][:-1], benchmarkCase, recapFile)))
                inputsRough.append((params[1], params[0], params[2], params[3][:-1], benchmarkCase))
                inputs = generateInputFile(params[1], params[0], params[2], params[3][:-1], benchmarkCase, constructedInput, log)
				
                for i in inputs:
                    diff = False
                    filename,setDiff,lemma,caseStudy,benchmarkCase,log = i
                    theoryfile = f"files_to_benchmark/{caseStudy}/{filename}"
                    # theoryfile = f"files_to_benchmark/{caseStudy}/{filename}"
                    if setDiff == "TRUE":
                        diff = True
                    parallel_input.append([theoryfile,lemma,"",strategy,3,"s",6000,diff])
                    # print(theoryfile,lemma,bool(setDiff))

    if not os.path.isdir('tacticGeneration'):
        os.mkdir('tacticGeneration')
    if not os.path.isdir('tacticGeneration/results'):
        os.mkdir('tacticGeneration/results')
    if not os.path.isdir('tacticGeneration/tacticBatch'):
        os.mkdir('tacticGeneration/tacticBatch')
    if not os.path.isdir('tacticGeneration/generatedTactics'):
        os.mkdir('tacticGeneration/generatedTactics')

    mf.parallelProving(parallel_input,6)
                    # mf.proveUntil(theoryfile,lemma,diff=bool(setDiff))
				
