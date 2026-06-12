import json
import plot
import sys
import csv
from pathlib import Path

def printPretty(dirname,fstline,nbTypes,resS,respS,filename):
    for i in range(len(fstline)):
        fstline[i] = fstline[i].ljust(14)
    fstline = "".join(fstline)
    with open(f"results/{dirname}/{filename}",'w') as f:
        f.write(fstline+"\n")
        for t in range(len(nbTypes)):
            for i in range(len(resS[t])):
                resS[t][i] = str(resS[t][i]).ljust(13)
                respS[t][i] = str(respS[t][i]).ljust(13)
            f.write(labels[t].ljust(14)+" "+str(nbTypes[t]).ljust(14)+"  ".join(resS[t])+"\n")
            f.write("  %".ljust(14)+" ".ljust(15)+"  ".join(respS[t])+"\n")

def printExcel(rowsName,nbTypes,resS,respS):
    res = []
    for t in range(len(nbTypes)):
        res.append([labels[t],nbTypes[t]]+resS[t])
        res.append(["%",""]+respS[t])
    res.append([])
    with open("tables.csv", 'a') as csvfile: 
        # creating a csv writer object 
        csvwriter = csv.writer(csvfile) 
        # writing the fields 
        csvwriter.writerow(rowsName) 
        # writing the data rows 
        csvwriter.writerows(res)

def printLatex(fstline,nbTypes,resS,respS):
    print(fstline)
    # print("Type lemmas & Nb lemmas & Develop & Escape & Backtracking & BackAndAVoid & Probabilistic & CollectAndRestart & All strats & All strats+tact\\\\")
    for t in range(len(nbTypes)):
        print(labels[t]+" & "+str(nbTypes[t])+" & "+" & ".join(resS[t])+"\\\\")
        # print("    & %    & "+" & ".join(respS[t])+" \\\\")

def printStratResults(dirname,resp,noBaseLine,noExists):
    if noBaseLine:
        printableData = [[] for i in resp[0][:-1]]
        for i in range(len(printableData)):
            for j in range(len(resp)):
                printableData[i].append(resp[j][i])
        strats = ["Escape","Backtracking","BackAndAvoid","Probabilistic","CollectAndRestart","Combined\n strategies"]
        # plot.generatePlotNoBaseline(printableData,strats,labels,saveFile="graphs/resByTypeNoBaseline.png")
    else:
        printableData = [[] for i in resp[0][:-1]]
        for i in range(len(printableData)):
            for j in range(len(resp)):
                printableData[i].append(resp[j][i])
        strats = ["Baseline","Escape","Backtracking","BackAndAvoid","Probabilistic","CollectAndRestart","Combined\n strategies"]
        plot.generatePlotGeneral(printableData,strats,labels,saveFile=f"results/{dirname}/resByType.png")

def printTacticResults(resp):
    printableData = [[] for i in resp[0][:-1]]
    for i in range(len(printableData)):
        for j in range(len(resp)):
            printableData[i].append(resp[j][i])
    strats = ["Baseline","Combined strategies","Combined strategies\nwith tactic generation"]
    # plot.generatePlotGeneral(printableData,strats,labels,saveFile="graphs/resTacticGen.png")

def notNullPourcentage(num,den):
    if den > 0:
        return(round(num*100/den,2))
    else:
        return 0

def analysisGen(dirname,onlyTarget,noBaseLine,noExists):
    res, resp = [[],[],[],[],[],[]], [[],[],[],[],[],[]]
    resS, respS = [[],[],[],[],[],[]], [[],[],[],[],[],[]]

    strategies = strat #[:-1]
    if noBaseLine:
        strategies = strat[1:]
    for s in strategies:
        nbTypes = []
        for i in range(len(types)):
            f, tp = 0, 0
            for lm in lemma[s]['lemmas']:
                lmName = "--".join(lm.split("--")[:-1])+"--merged"
                st = lemma[s]['lemmas'][lm]['status']
                t = lemma[s]['lemmas'][lm]['lemma_type']
                if (types[i] in t and selectLemma(onlyTarget,noBaseLine,noExists,s,lmName)):
                    tp += 1
                    if (st == "completed"):
                        f += 1
            p = 0
            nbTypes.append(tp)
            res[i].append(f)
            if tp > 0:
                p = f*100/tp
                resp[i].append(round(p,2))
                resS[i].append(str(f)+" ["+str(round(p,2))+"]")
                respS[i].append(str(round(p,2)))
            else:
                resp[i].append(round(p,2))
                resS[i].append("-")
                respS[i].append("-")

    #Combined results 
    counterByTypeStrat,counterByTypeStratAndTacticGen = byCaseStudyAllTactic(onlyTarget,noExists, noBaseLine)
    resDvp = []
    for t in range(len(types)):
        p = 0
        if nbTypes[t]>0:
            p = counterByTypeStrat[t]*100/nbTypes[t]
        res[t].append(counterByTypeStrat[t])
        resp[t].append(round(p,2))
        resS[t].append(str(counterByTypeStrat[t])+" ["+str(round(p,2))+"]")
        respS[t].append(str(round(p,2)))

        if nbTypes[t]>0:
            p = counterByTypeStratAndTacticGen[t]*100/nbTypes[t]
        res[t].append(counterByTypeStratAndTacticGen[t])
        resp[t].append(round(p,2))
        resS[t].append(str(counterByTypeStratAndTacticGen[t])+" ["+str(round(p,2))+"]")
        respS[t].append(str(round(p,2)))

        resDvp.append(res[t][0])

    if noBaseLine:
        #Printing general results
        fstline = ["Type lemmas","Nb lemmas","Escape","Backtrack","BackAndAvoid","Proba","CollectAndRestart","All strats", "All strats+tact"]
        printPretty(dirname,fstline,nbTypes,resS,respS,"table2_strategiesresults")
        # printExcel(fstline,nbTypes,resS,respS)
        #printLatex(fstline,nbTypes,resS,respS)
                
        #Ploting results
        printStratResults(dirname,resp,noBaseLine,noExists)

    

    else:
        #Printing general results
        fstline = ["Type lemmas","Nb lemmas", "Develop","Escape","Backtrack","BackAndAvoid","Proba","CollectAndRestart","All strats","All strats+tact"]
        printPretty(dirname,fstline,nbTypes,resS,respS,"appendix_strategiesComparedToBaseline")
        # printExcel(fstline,nbTypes,resS,respS)
        #printLatex(fstline,nbTypes,resS,respS)
                
        #Ploting results
        printStratResults(dirname,resp,noBaseLine,noExists)

        #Tactic generation analysis
        generalTable,generalTableProportion = [], []
        for i in range(len(nbTypes)):
            improvementProp = counterByTypeStratAndTacticGen[i]-resDvp[i]
            generalTable.append([str(resDvp[i])+" ["+str(notNullPourcentage(resDvp[i],nbTypes[i]))+"]",str(counterByTypeStrat[i])+" ["+str(notNullPourcentage(counterByTypeStrat[i],nbTypes[i]))+"]",str(counterByTypeStratAndTacticGen[i])+" ["+str(notNullPourcentage(counterByTypeStratAndTacticGen[i],nbTypes[i]))+"]",str(improvementProp)+" [+"+str(notNullPourcentage(counterByTypeStratAndTacticGen[i]-resDvp[i],resDvp[i]))+"]"])
            generalTableProportion.append([str(notNullPourcentage(resDvp[i],nbTypes[i])),str(notNullPourcentage(counterByTypeStrat[i],nbTypes[i])),str(notNullPourcentage(counterByTypeStratAndTacticGen[i],nbTypes[i])),"-"])
        fstline = ["Type lemmas","Nb lemmas","All strats","All strats+tact","Improvement"]
        printPretty(dirname,fstline,nbTypes,generalTable,generalTableProportion,"table5_combinedResults")
        # printLatex(fstline,nbTypes,generalTable,generalTableProportion)
        printTacticResults(generalTableProportion[:][:])
        
def byCaseStudyAllTactic(onlyTarget,noExists, noBaseLine):
    #Results if we all my strats and tacticGeneration 
    counterByTypeStrat, counterByTypeStratAndTacticGen = [], []
    for i in range(len(types)):
        counterTypeStrat, counterTypeStratTactic = 0, 0
        for lm in lemmaNames:
            provedStrat, proveTactic = False,False
            for s in strat:
                lmName = lm.replace("_original-",f"_{s}-")+"--merged"
                dir = lemma[s]['lemmas'][lmName]['theory_dir']	
                if not dir=="emv":
                    ty = lemma[s]['lemmas'][lmName]['lemma_type']
                    if (types[i] in ty and selectLemma(onlyTarget,noBaseLine,noExists,s,lm)):
                        st = lemma[s]['lemmas'][lmName]['status']
                        ta = lemma[s]['lemmas'][lmName]['tactic']			
                        if (st == "completed"):
                            provedStrat = True
                        if (ta != ""):
                            proveTactic = True
                    
            if provedStrat:
                counterTypeStrat += 1
            if provedStrat or proveTactic:
                counterTypeStratTactic +=1 
        counterByTypeStrat.append(counterTypeStrat)
        counterByTypeStratAndTacticGen.append(counterTypeStratTactic)
    return(counterByTypeStrat,counterByTypeStratAndTacticGen)

def onlyU(listStatus,idx):
	for j in range(len(listStatus)):
		if j != idx and listStatus[j] == "completed":
			return False
	return True

def noneProven(lm,listStatus,consType):
    if consType != "":
        return ()
    #Return True if the lemma is not proven by any strategy
    for j in range(len(listStatus)):
        if listStatus[j] == "completed":
            return ()
    with open("lemmaToTactic.txt", 'a') as lemmaToTactic: 
        lemmaToTactic.write(f"{lm}\n")
	


def compareN(dirname,onlyTarget,noExists,consType,label,indexes):
    strt = []
    for i in indexes:
        strt.append(strat[i])
    timeComp = [0 for i in range(len(strt))]
    finished = [0 for i in range(len(strt))]
    times = [0 for i in range(len(strt))]
    only = [0 for i in range(len(strt))]
    totTime = [0 for i in range(len(strt))]
    casesConsidered = 0
    #consType = "0"
    for lm in lemmaNames:
        status, lemmaTimes = [], []
        if selectLemma(onlyTarget,False,noExists,strt[0],lm):
            for s in strt: 
                lmName = lm.replace("_original-",f"_{s}-")+"--merged"

                status.append(lemma[s]['lemmas'][lmName]['status'])
                lemmaTimes.append(lemma[s]['lemmas'][lmName]['time'])
            t = lemma[strt[0]]['lemmas'][lm+"--merged"]['lemma_type']
            if consType in t:
                allFinished = True
                for st in status:
                    if st != "completed":
                        allFinished = False
                        break
                if allFinished:
                    casesConsidered += 1	
                    timeComp[min( (v, i) for i, v in enumerate(lemmaTimes) )[1]] += 1
                    for j in range(len(lemmaTimes)):
                        totTime[j] += lemmaTimes[j]
                for k in range(len(status)):
                    if status[k] == "completed":
                        finished[k] += 1
                        if onlyU(status,k):
                            only[k] += 1
                noneProven(lmName,status,consType)
            t = lemma[strt[0]]['lemmas'][lm+"--merged"]['lemma_type']
    rtotTime = []
    for k in range(len(indexes)):
        # print(f"{strt[k]} faster in {timeComp[k]} cases")
        # print(f"{strt[k]} only in {only[k]} cases")
        # print(f"{strt[k]} total time: {round(totTime[k],2)}")
        rtotTime.append(str(round(totTime[k],2)))

    with open(f"results/{dirname}/table3_timecomp",'a') as f:
        f.write(f"{label}\n")
        f.write("\\textbf{Only} & "+" & ".join(list(map(str,only)))+"\\\\\n")
        f.write("\\textbf{Faster} & "+" & ".join(list(map(str,timeComp)))+"\\\\\n")
        f.write("\\textbf{Total time (s)} & "+" & ".join(rtotTime)+"\\\\\n\n")

def compare(onlyTarget,noExists,consType,i1,i2):
    s1, s2 = strat[i1], strat[i2]
    t1B, t2B = 0, 0
    pt1B, pt2B = [], []
    t1, t2 = 0, 0
    o1, o2 = 0, 0
    casesConsidered = 0
    #consType = "0"
    for lm in lemmaNames:
        if selectLemma(onlyTarget,False,noExists,strat[0],lm):
            lm1, lm2 = lm.replace("_original-",f"_{s1}-")+"--merged", lm.replace("_original-",f"_{s2}-")+"--merged"
            st1, st2 = lemma[s1]['lemmas'][lm1]['status'],lemma[s2]['lemmas'][lm2]['status']
            t = lemma[s1]['lemmas'][lm1]['lemma_type']
            if consType in t:
                if (st1 == "completed") and (st2 == "completed"):
                    casesConsidered += 1
                    t1 = lemma[s1]['lemmas'][lm1]['time']
                    t2 = lemma[s2]['lemmas'][lm2]['time']	
                    if t1 < t2:
                        t1B += 1
                        pt1B.append(t2/t1)
                    else:
                        t2B += 1
                        pt2B.append(t1/t2)
                if (st1 == "completed") and (st2 != "completed"):
                    o1 += 1
                if (st1 != "completed") and (st2 == "completed"):
                    o2 += 1

    howmuch1,howmuch2 = "-","-"
    if len(pt1B) != 0:
       howmuch1 = round(sum(pt1B)/len(pt1B),2)
    if len(pt2B) != 0:
        howmuch2 = round(sum(pt2B)/len(pt2B),2)
    return(f"{o1} & {o2}",f"{t1B} & {t2B}",f"{howmuch1} & {howmuch2}",casesConsidered,notNullPourcentage(t1B,casesConsidered),notNullPourcentage(t2B,casesConsidered))

def compare2by2(dirname,onlyTarget,noExists,t,stratToComp):
    only, faster, howmuch = [],[],[]
    for i in stratToComp:
        only2, faster2, howmuch2, casesConsidered, prop1faster,prop2faster = compare(onlyTarget,noExists,t,i,0)
        only.append(only2)
        faster.append(faster2)
        howmuch.append(howmuch2)
        # print(i,casesConsidered,prop1faster,prop2faster)

    with open(f"results/{dirname}/table3_timecomp",'a') as f:
        f.write("\\textbf{Only} & "+" & ".join(only)+" \\\\\n")
        f.write("\\textbf{Faster} & "+" & ".join(faster)+" \\\\\n")
        f.write("{\\small \\textbf{How much faster}} & "+" & ".join(howmuch)+" \\\\\n\n")

def sort_by_indexes(lst, indexes, reverse=False):
  return [val for (_, val) in sorted(zip(indexes, lst), key=lambda x: \
          x[0], reverse=reverse)]

def tieBreaker(onlyTarget,noExists,consType,indexes):
    # print("tiebreaking",consType,indexes)
    strt = []
    for i in indexes:
        strt.append(strat[i])
    timeComp = [0 for i in range(len(strt))]
    for lm in lemmaNames:
        if selectLemma(onlyTarget,False,noExists,strat[0],lm):
            status, lemmaTimes = [], []
            for s in strt:
                lmName = lm.replace("_original-",f"_{s}-")+"--merged"
                status.append(lemma[s]['lemmas'][lmName]['status'])
                lemmaTimes.append(lemma[s]['lemmas'][lmName]['time'])
            lmName = lm.replace("_original-",f"_{strt[0]}-")+"--merged"
            t = lemma[strt[0]]['lemmas'][lmName]['lemma_type']
            if consType in t:
                allFinished = True
                for st in status:
                    if st != "completed":
                        allFinished = False
                        break
                if allFinished:	
                    timeComp[min( (v, i) for i, v in enumerate(lemmaTimes) )[1]] += 1
    # print(indexes)
    # print(timeComp)
    return(sort_by_indexes(indexes,timeComp,True))  

def untieRanking(onlyTarget,noExists,type,scores,ranking):
    sortedScores = sorted(scores,reverse=True)
    if len(sortedScores)>1 and sortedScores[0]>0:
        i = 0
        while (i+1) < len(sortedScores) and sortedScores[i+1] == sortedScores[0]:
            i += 1
        if i > 0:
            ranking[0:i+1] = tieBreaker(onlyTarget,noExists,type,ranking[0:i+1])
    return(ranking)

def generalRanking(onlyTarget,noExists,type,stratsIdx):
    strtScore = [0 for i in range(len(stratsIdx))]
    for lm in lemmaNames:
        if selectLemma(onlyTarget,False,noExists,strat[0],lm):
            for si in range(len(stratsIdx)): 
                s = strat[stratsIdx[si]]
                lmName = lm.replace("_original-",f"_{s}-")
                if not "merged" in lmName:
                    lmName = lmName+"--merged"
                st = lemma[s]['lemmas'][lmName]['status']
                t = lemma[s]['lemmas'][lmName]['lemma_type']
                if type in t and st == "completed":
                    strtScore[si] += 1
    ranking = sort_by_indexes(stratsIdx,strtScore,True)
    return(untieRanking(onlyTarget,noExists,type,strtScore,ranking))



def proveUnique(onlyTarget,noExists,type,stratTested,ref):
    score = 0
    for lm in lemmaNames:
        if selectLemma(onlyTarget,False,noExists,strat[0],lm):
            unique = False
            lmName = lm.replace("_original-",f"_{strat[stratTested]}-")+"--merged"
            st = lemma[strat[stratTested]]['lemmas'][lmName]['status']
            t = lemma[strat[stratTested]]['lemmas'][lmName]['lemma_type']
            if type in t: 
                if st == "completed":
                    unique = True
                    for s in ref:
                        lmName = lm.replace("_original-",f"_{strat[s]}-")+"--merged"
                        if (lemma[strat[s]]['lemmas'][lmName]['status'] == "completed"):
                            unique = False
            if unique:
                score += 1
    return(score)
                    
def uniquenessRanking(onlyTarget,noExists,type,toberanked,ref):
    uniquenessScore, uranking = [], []
    for s in toberanked:
        uniquenessScore.append(proveUnique(onlyTarget,noExists,type,s,ref))
    uranking = sort_by_indexes(toberanked,uniquenessScore,True)
    uranking = untieRanking(onlyTarget,noExists,type,uniquenessScore,uranking)
    return(uranking,sorted(uniquenessScore,reverse=True))

def fastest(onlyTarget,noExists,consType,ranking):
    return(tieBreaker(onlyTarget,noExists,consType,ranking)[0])

def workflowEfficience(onlyTarget,noExists,type,ranking):
    score, casesConsidered = 0, 0
    for lm in lemmaNames:
        if selectLemma(onlyTarget,False,noExists,strat[0],lm):
            proved = False
            lmName = lm.replace("_original-",f"_{strat[0]}-")+"--merged"
            t = lemma[strat[0]]['lemmas'][lmName]['lemma_type']
            if type in t:
                casesConsidered += 1
                for si in ranking:
                    s = strat[si]
                    lmName = lm.replace("_original-",f"_{s}-")+"--merged"
                    st = lemma[s]['lemmas'][lmName]['status']
                    if (st == "completed"):
                        proved = True
                if proved:
                    score += 1
    return(casesConsidered,score)

def resultApproach(onlyTarget,noExists,type,s):
    score = 0
    for lm in lemmaNames:
        if selectLemma(onlyTarget,False,noExists,strat[0],lm):
            lmName = lm.replace("original",strat[0])+"--merged"
            t = lemma[strat[0]]['lemmas'][lmName]['lemma_type']
            if type in t:
                lmName = lm.replace("_original-",f"_{strat[s]}-")+"--merged"
                if (lemma[strat[s]]['lemmas'][lmName]['status'] == "completed"):
                    score += 1
    return(score)

def printLatexWorkflow(dirname,ref,score,terminationRate,compareBase,compareBest):
    strat = ["Develop","Escape","Backtracking","BackAndAvoid","Proba","CollectAndRestart","SmartVerif"]
    lines = [" & \\textbf{All} & \\textbf{Classic} & \\textbf{Exists} & \\textbf{Source} & \\textbf{Reuse} & \\textbf{Induction} \\\\"]
    resLen0 = len(ref[0])
    fstCol = [f"{i}. &" for i in range(1,resLen0+1)]+["\\begin{tabular}{l} \\textbf{Workflow} \\\\ \\textbf{success}\\end{tabular} & ","\\begin{tabular}{c} \\textbf{Termination rate} \\\\ \\textbf{in \\%}\\end{tabular} & ","\\begin{tabular}{c} \\textbf{Improvement in \\%} \\\\ \\textbf{(/baseline)}\\end{tabular} & ","\\begin{tabular}{c} \\textbf{Improvement in \\%} \\\\ \\textbf{(/best approach)}\\end{tabular}& "]
    prettyStrat = [[] for _ in range(len(ref))]
    for i in range(len(ref)):
        # print(ref[i])
        for j in range(len(ref[i])):
            if ref[i][j] == -1:
                s = "-"
            else:
                s = strat[ref[i][j]]
            prettyStrat[j].append(s)
    for k in range(resLen0):
        lines.append(fstCol[k]+" & ".join(prettyStrat[k])+"\\\\\n")
    lines.append(fstCol[resLen0]+" & ".join(score)+"\\\\\n")
    lines.append(fstCol[resLen0+1]+" & ".join(terminationRate)+"\\\\\n")
    lines.append(fstCol[resLen0+2]+" & ".join(compareBase)+"\\\\\n")
    lines.append(fstCol[resLen0+3]+" & ".join(compareBest)+"\\\\\n")
    with open(f"results/{dirname}/table5_workflow",'w') as f:
        for l in lines: 
            f.write(l)


def workflow(dirname,onlyTarget,noExists,stratsIdx):
    rankings, scores, terminationRates = [],[],[]
    scoresDvp, terminationsRateDvp, terminationsRateBest = [], [],[]
    for t in types:
        #Defining the ranking
        ranking = generalRanking(onlyTarget,noExists,t,stratsIdx)

        increasingCoverage = True
        toberanked, ref = ranking[1:], ranking[:1]
        while increasingCoverage and toberanked != []:
            # toberanked = generalRanking(type,toberanked)
            uranking,uscore = uniquenessRanking(onlyTarget,noExists,t,toberanked,ref)
            if max(uscore) == 0:
                increasingCoverage = False
            else:
                toberanked = uranking[1:]
                ref.append(uranking[0])
        fastst = fastest(onlyTarget,noExists,t,ref)

        #Informations about the ranking
        casesConsidered,score =workflowEfficience(onlyTarget,noExists,t,ref)
        terminationRate = notNullPourcentage(score,casesConsidered)
        scoreDvp = resultApproach(onlyTarget,noExists,t,0)
        terminationRateDvp = notNullPourcentage(scoreDvp,casesConsidered)
        scoreBest = resultApproach(onlyTarget,noExists,t,ref[0])
        terminationRateBest = notNullPourcentage(scoreBest,casesConsidered)
        rankings.append(ref)
        scores.append(score)
        terminationRates.append(terminationRate)
        scoresDvp.append(scoreDvp)
        terminationsRateDvp.append(terminationRateDvp)
        terminationsRateBest.append(terminationRateBest)

        # print(f"Strat {t}, fastest: {fastst}")

    #Printing
    maxLen = max([len(i) for i in rankings])
    rankings = [(r+ maxLen * [-1])[:maxLen] for r in rankings]

    printingScores = [f"{scores[i]} ({scoresDvp[i]})" for i in range(len(scores))]
    printingTerm = [f"{terminationRates[i]} ({terminationsRateDvp[i]})" for i in range(len(scores))]
    compareBase = [f"+{terminationRates[i]-terminationsRateDvp[i]}" for i in range(len(scores))]
    compareBest = [f"+{terminationRates[i]-terminationsRateBest[i]}" for i in range(len(scores))]

    printLatexWorkflow(dirname,rankings,printingScores,printingTerm,compareBase,compareBest)

    
       
	
def oracled(oracleStatus):
	return(oracleStatus == "1.0" or oracleStatus == "0.0")

def selectLemma(targetLemma,noBaseLine,noExists,strategy,lem):
    lmName = lem.replace("_original-",f"_{strategy}-")
    if not "merged" in lmName:
        lmName = lmName+"--merged"
    # print(json.dumps(lemma[strategy]['lemmas'],indent=4))
    n = lemma[strategy]['lemmas'][lmName]['name']
    os = lemma[strategy]['lemmas'][lmName]['oracleStatus']
    dir = lemma[strategy]['lemmas'][lmName]['theory_dir']
    target = lemma[strategy]['lemmas'][lmName]['target']
    t = lemma[strategy]['lemmas'][lmName]['lemma_type']
	
    oracledS = oracled(os)
    if targetLemma and not target:
        return False
    else:
        if noBaseLine:
            ogLemmaName = lmName.replace(strategy,"original")
            # and not lemma['original']['lemmas'][lem]['status'] == "completed"
            return(not dir=="emv" and not dir=="smartverif" and not n=="Observational_equivalence" and not lemma['original']['lemmas'][ogLemmaName]['status'] == "completed")
        if noExists:
            # print(json.dumps(lemma[strategy]['lemmas'][lmName],indent=4))
            return(not dir=="emv" and not dir=="smartverif" and not n=="Observational_equivalence" and not "1" in t) 	
        else:
            return(not dir=="emv" and not dir=="smartverif" and not n=="Observational_equivalence")
            # return(not dir=="emv" and not "smartverif" in lmName and not n=="Observational_equivalence")
    
if __name__ == "__main__":

    filename = 'data.json'
    if len(sys.argv) > 1:
        filename = sys.argv[1]
	
    with open(filename,'r') as file:
        lemma =json.load(file)
        # print(lemma)

    noBaseLine = False
    noExists = False
    onlyTarget = False

    dirname = "/".join(filename.split("/")[:-1])
    dirname = dirname.split("../")[-1]

    if onlyTarget:
        dirname = dirname+"_onlyTarget"
    if noBaseLine:
        dirname = dirname+"_noBaseLine"
    if noExists:
        dirname = dirname+"_noExists"
    # Path(f"tables/{dirname}").mkdir(parents=True, exist_ok=True)
    # Path(f"graphs/{dirname}").mkdir(parents=True, exist_ok=True)
    Path(f"results/{dirname}").mkdir(parents=True, exist_ok=True)
		
    strat = ["original","escape","backtrack","backAndAvoid","proba","collectAndRestart"]
    # labels = ["All","Classic","Exists","Diff","Source","Reuse","Induction"]
    # types = ["","0","1","2","3","4","5"]
    labels = ["All","Classic","Exists","Source","Reuse","Induction"]
    types = ["","0","1","3","4","5"]
    lemmaNames = []
    # print(json.dumps(lemma, indent=1))
    for lm in lemma[strat[0]]['lemmas']:
        lemmaNames.append("--".join(lm.split("--")[:-1]))

    
    analysisGen(dirname,onlyTarget,noBaseLine, noExists)
    #Appendix
    analysisGen(dirname,onlyTarget,not noBaseLine, noExists)

    for t in range(len(types)):
        compareN(dirname,onlyTarget,noExists,types[t],labels[t],[0,1,2,3,4,5])
        compare2by2(dirname,onlyTarget,noExists,types[t],[1,2,3,4,5])
    workflow(dirname,onlyTarget,noExists,[0,1,2,3,4,5])
        
