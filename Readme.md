# Artifacts for "Adaptive Proof Strategies for Protocol Verification in Tamarin"

This repository contains two folders:
- tamarin-prover: fork of the tamarin-prover tool with integrated adaptive strategies (see Experimenting with the tools on how to use it)
- artifacts: python scripts necessary to reproduce the experiences described in the paper (see Benchmarks) 

## Experimenting with the tools
All the information needed to install tamarin-prover can be found [here](https://tamarin-prover.com/install.html). To get the same version of tamarin-prover as used in this paper, you can go to the tamarin-prover subfolder of this archive and compile with the command `make`.

### Tamarin strategies
This version of tamarin-prover provides five new strategies in addition to the usual behavior of the tool. They can be triggered with the flag --strategy[=STRATEGY]. By default, no strategy is used and tamarin uses its usual behavior.
The following options are possible:
    - Escape: Deprioritize goals in loop
    - Probabilistic: Choose a problematic goal with decreasing probability. The seed of the PRNG used to choose whether or not to use a goal can be set with the optional flag `--seed[=Int]`.
    - Backtrack: Backtracking to the goal before the loop
    - BackAndAvoid: Backtracking and deprioritizing the goals responsible for backtracking
    - CollectAndRestart: Deprioritize branches rather than goals

### Tactic generation
In order to generate tactics, tamarin-prover needs to run with one of the five strategies listed above. The default behavior does not detect loop and can as such not export 'problematic' goals. To activate the goal export during a proof, use the flag `--exportGoals`. 
With this option set, tamarin-prover will write 'problematic' goals to a file under the `tacticGeneration/tacticBatch` folder. The file's name will follow the format: [strategy]_[lemma_name]_[file_name].spthy. To export this raw data as a tactic usable for a proof attempt, use the script `exportTacticPoC.py` available in the  `tacticGenerationBenchmark` folder with the command `python3 exportTacticPoC.py fileWithRawData.spthy`. The generated tactic can be pasted in the theory file and used immediately for a new attempt.

## Benchmarks

### Strategies benchmark (strategiesBenchmark folder)

We distinguish two benchmarks: benchmark of the strategies (can be found under `strategiesBenchmark`) and benchmark of the tactic generation (can be found under `tacticGeneration`).

#### Running the benchmark
Running the strategies benchmark requires the tool `batch-tamarin`. It can be installed with the following command `pip3 install batch-tamarin`.

We provide a batch-tamarin recipe to reproduce the results discussed in Section 4: `recipe_strategy_benchmark.json` as well as a binary file with the version of tamarin-prover used for our benchmark (tamarin-prover-1.4.1-2468-g300638b4). 

How to run the recipe:
 - copy the tamarin executable (tamarin-prover-1.4.1-2468-g300638b4) to [path_to_your_home]/.local/bin/
 - add the binary file to the path: export PATH=$PATH:[path_to_your_home]/.local/bin/
 - run the recipe with the command `batch-tamarin run [recipe.json]`.

The results of the analysis are then stored under the `result_strategiesBenchmark` folder.

Note: if you have installed tamarin-prover, you can also compile it with the version provided in this archive. You can then replace the path (tamarin_versions["merged"]["path"]) in the recipe file by the executable generated at the end of the make command.

#### Analysing the results
To analyse the results of these benchmark (and generate the graph and table presented in the paper), one can use the scripts available in the strategiesBenchmark/resultsAnalysisScripts folder.
First, run `python3 analyseResultsBatchTamarinMergedVersion.py [path to results folder]\execution_report.json`.
And then `python3 results.py [path to results folder]\execution_report_extracted.json`
Results are generated in a strategiesBenchmark/resultsAnalysisScripts/results subfolder.

The results discussed in Section 4 can already be found in strategiesBenchmark/resultsAnalysisScripts/results. The 6 subfolders come from the parallelization of the benchmark on three servers, as discussed in the paper. The results_merged folder contains the merged results of the 5 sub-experiments.

Note: this version of the results will not include the results from the tactic generation benchmark.

### Tactic generation benchmark (tacticGenerationBenchmark folder)

The goal of this benchmark is to see if tactic generation allows us to prove lemmas that none of the strategies managed to prove. The list of these lemmas has been extracted by the results.py step at the previous step. It is provided in the `lemmaToTactic.txt` file that can be found under the `tacticGenerationBenchmark` folder.

#### Running the benchmark
To run the tactic generation benchmark as presented in the paper, run the command `python3 tacticGenBench.py` in the tacticGenerationBenchmark folder. The results will be stored under the tacticGeneration/results folder. The script results give a textual summary of the lemmas proved (or failed) by the benchmark while the other files store the proofs and attack traces that have been reached for each lemma.

#### Analysing the results

To extract information from these results, you can run the script `python3 generateDataJson.py` that will generate the file data.json. This script uses the `result_strategiesBenchmark_merged.json` file that contains the results of the strategies benchmark and adds the results of the tactics generation benchmark.
To analyse the results, run `python3 results.py`. It will use the data.json file present (discussed above) in the folder to generate the tables and graphs shown in the paper. 

