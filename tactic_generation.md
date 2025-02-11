# External script for tactic generation

Idea of the project: when a proof times out or is killed, the user is left with no additional information on what happend during the proof. The idea of this project is to use the loop detection mechanism implemented in several approaches (escape, proba,...) to extract problematic goals as the proof goes. If it fails in the end, these goals are then used to generate a tactic summarizing this information.
For now, we need to use external scripts because when Tamarin gets killed (runs out of memory), it is the only way to retrieve the information.

**Requirements** The python scripts are Tamarin version agnostics. They will use what ever version is called when using the command `tamarin-prover`. However, in order to generate tactics, the Tamarin version needs to have the loop detection mechanism implemented and to export the detected goals with the following format: `trace ("---"++show depth++"---"++show (cleanGoal g))`.

## Structure of the project

There are three python files required:
* **manipulateFile.py**: Main file. Tries to prove the lemma passed as parameter (with the newest tactic) until it is proven, the maximal number of proof attempts have been reached or the tactic generated in an attempt is the same as the previous generated tactic (no new insight gained). It is also responsible for adding the newest generated tactic in the spthy file. Use: 
```
python3 manipulateFile.py spthy_file lemma_name [-b,--bound,--heuristic,--timeout]
```
* **tamarin_wrapper.py**: Wrapper for calling Tamarin, slightly modified version of the same script in [Tamarin Lemmas](https://projects.cispa.saarland/alexander.dax/tamarinlemmas).
* **tacticExportPoC.py**: Files with the functions to generated tactics.

## Generation of tactics

#### 

## ToDos:
- [] Allow the analysis of multiple lemmas
- [] Sanity check the parameters in manipulateFile.py
- [] Mechanism to deal with the tactics when no goal has been exported
- [] Remove file export from tamarin_wrapper / make a better logging system