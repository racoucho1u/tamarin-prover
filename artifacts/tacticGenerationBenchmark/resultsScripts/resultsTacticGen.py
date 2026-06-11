import os
from enum import Enum
from dataclasses import dataclass, asdict
import json

####################################
# Analyse the results of the tactic
# generation benchmark from the 
# scriptResult file
####################################



def parse_tactic_gen(strat_dict,strategy_name,folder):
    with open (folder+"/scriptResult") as tacGen:
        lines = tacGen.readlines()
        for l in lines:
            #Cases where a proof has been reached
            if l != '\n':
                if '{' in l:
                    splitLine = l.split(' ')
                    lemma_name = splitLine[2].split('\t')[0]
                    theory_file = splitLine[3].split('/')[-1].split('.')[0]
                    theory_dir	= splitLine[3].split('/')[-2]
                    tactic = splitLine[-1][1:-3]
                    reason = "proved"
                    # print(f"{lemma_name} {theory_file} {theory_dir} {tactic}")
                else:
                    splitLine = l.split(' ')
                    # print(splitLine)
                    lemma_name = splitLine[3].split('\t')[0]
                    theory_file = splitLine[4].split('/')[-1].split('.')[0]
                    # print(splitLine[4])
                    # print(l)
                    theory_dir	= splitLine[4].split('/')[-2]
                    tactic = ""
                    reason = ' '.join(splitLine[5:])[:-2]
                    # print(f"{lemma_name} {theory_file} {theory_dir} {tactic}")
            partialLemmaName = f"{theory_file}__{strategy_name}--{lemma_name}--merged"
            for l in strat_dict[strategy_name]['lemmas']:
                if partialLemmaName in l:
                    theory_and_lemma = l
            strat_dict[strategy_name]['lemmas'][theory_and_lemma]['tactic'] = tactic
            strat_dict[strategy_name]['lemmas'][theory_and_lemma]['reason'] = reason


if __name__ == "__main__":

    with open('result_strategiesBenchmark_merged.json', 'r') as file:
        strat_dict = json.load(file)

        parse_tactic_gen(strat_dict,"escape","../tacticGeneration/results")
        

        with open('data.json', 'w') as file:
            json.dump(strat_dict, file,indent=4)