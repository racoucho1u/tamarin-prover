# Artifacts for "Adaptive Proof Strategies for Protocol Verification in Tamarin"

This repository contains two folders:
- tamarin-prover: fork of the tamarin-prover tool with integrated adaptive strategies (see "Experimenting with the tools" on how to use it)
- artifacts: python scripts necessary to reproduce the experiences described in the paper (see "Benchmarks") 

To experiment with the tools presented in this paper and reproduce the experiments, we provide a Docker container that can be started by running the following commands from this directory:
```bash
$ docker build --network=host -t tamarin:strategies -f ./Dockerfile .
$ docker run -it -v "$PWD":/workspace/tamarin-prover tamarin:strategies
```

## Experimenting with the tools
To use the examples presented in this section, move to tamarin-prover/tamarin-prover.
```bash
% cd tamarin-prover
``` 
We suggest using the toy example `SourceOfUniqueness.spthy` (provided in the tamarin-prover folder) for testing the tool as it gives fast proofs. It can however be replaced by any tamarin theory file (many can be found in the tamarin-prover/example folder).

### Tamarin strategies
This version of tamarin-prover provides five new strategies in addition to the usual behavior of the tool. They can be triggered with the flag `--strategy[=STRATEGY]` in the command line. By default, no strategy is used and tamarin uses its usual behavior. 

To use default Tamarin behavior, run the following command (note that this example do not finish with the default behavior, use CTRL-C to kill it):
```bash
% tamarin-prover --prove SourceOfUniqueness.spthy
```

To try our strategies, use the following options:
- Escape (Deprioritize goals in loop): 
```bash
% tamarin-prover --prove --strategy=Escape SourceOfUniqueness.spthy
```
- Probabilistic (Choose a problematic goal with decreasing probability. The seed of the PRNG used to choose whether or not to use a goal can be set with the optional flag `--seed[=Int]`):
```bash
% tamarin-prover --prove --strategy=Proba SourceOfUniqueness.spthy
% tamarin-prover --prove --strategy=Proba --seed=12 SourceOfUniqueness.spthy
```
- Backtrack: Backtracking to the goal before the loop
```bash
% tamarin-prover --prove --strategy=Backtrack SourceOfUniqueness.spthy
```
- BackAndAvoid: Backtracking and deprioritizing the goals responsible for backtracking
```bash
% tamarin-prover --prove --strategy=BackAndAvoid SourceOfUniqueness.spthy
```
- CollectAndRestart: Deprioritize branches rather than goals
```bash
% tamarin-prover --prove --strategy=CollectAndRestart SourceOfUniqueness.spthy
``` 

### Tactic generation
In order to generate tactics, tamarin-prover needs to run with one of the five strategies listed above. The default behavior does not detect loop and can as such not export 'problematic' goals. To activate the goal export during a proof, use the flag `--exportGoals`. 
With this option set, tamarin-prover will print 'problematic' goals in the terminal. They can be redirected to a file and compiled in a tactic using the commands below. The tactic can then be pasted in the original theory file and used to retry the proof.
```bash
% tamarin-prover --prove --strategy=Escape --exportGoals SourceOfUniqueness.spthy 2> exportGoals.spthy
% python3 exportTactic.py exportGoals.spthy 
```
In order to automated this process, we also provide the script `tacticGeneration.py`. It takes as parameters the theory file as well as the lemma to be proven.  By default, this script will try to prove the lemma with the strategy Escape using a timeout of one hour. If the proof succeed, the process stops, otherwise, the script generates a tactic from the exported goals and retries the proof with the generated tactic. By default, this process is repeated two times (3 proofs attemps total, first one with no tactic and two times with generated tactics). The timeout parameter can be modified with the option `--timeout=[Int]` and the attempts number with the parameter `--bound=[Int]` (by default it is set to 3). Users can also specify the usual Tamarin options (heuristic, strategy...) with the usual syntax (eg. `--strategy=Proba`).
```bash
#Example with a timeout of 1s. The first attempt should fail but the second should finish in less than a second.
% source /opt/venv/bin/activate
% python3 tacticGeneration.py SourceOfUniqueness.spthy uniqueness --strategy=Proba --timeout=1
```


## Benchmarks (small scale)

In order to run the benchmarks, go in the artifacts folder:
```bash
% cd /workspace/tamarin-prover/artifacts
```
We distinguish two benchmarks: benchmark of the strategies (can be found under `strategiesBenchmark`) and benchmark of the tactic generation (can be found under `tacticGeneration`).

The results and experiments we present in the paper required around a week of running parallelized on three servers. For the sake of reproducibility, we present in this section a small scale version of the benchmark to illustrate the process. Please, note that the time constraint of 24 hours means we can only test a very small number of lemmas. Thus, the statistical results in the example are not be exploitable.


If the reader still wanted to rerun the full benchmark or look at the results we provide, we refer them to the next section (Benchmark, paper version).  

### Strategies benchmark (strategiesBenchmark folder)

*Requirements:*  we suppose the small benchmark will be run on a laptop. Therefore, we only require 4 cores and 30G of memory. 
#### Running the benchmark
To run the benchmark, we use batch-tamarin, a wrapper that enables batch executions. To execute the benchmark, run:
```bash
% cd /workspace/tamarin-prover/artifacts/strategiesBenchmark
% batch-tamarin run recipe_strategy_benchmark_fast.json
```
The results of the analysis are then stored under the `result_strategiesBenchmark` folder.


#### Analysing the results
To analyse the results of these benchmark (and generate the graph and table presented in the paper), one can use the scripts available in the strategiesBenchmark/resultsAnalysisScripts folder. Run the following:
```bash
% source /opt/venv/bin/activate
% python3 resultsAnalysisScripts/analyseResultsBatchTamarinMergedVersion.py result_strategiesBenchmark_fast/execution_report.json
% python3 resultsAnalysisScripts/results.py result_strategiesBenchmark_fast/execution_report_extracted.json
```
Results of the analysis (tables and graphes) are generated in `results/result_strategiesBenchmark_fast`.

The results discussed in Section 4 can already be found in strategiesBenchmark/resultsAnalysisScripts/results. The 6 subfolders come from the parallelization of the benchmark on three servers, as discussed in the paper. The results_merged folder contains the merged results of the 5 sub-experiments.

Note: this version of the results will not include the results from the tactic generation benchmark.

### Tactic generation benchmark (tacticGenerationBenchmark folder)

The goal of this benchmark is to see if tactic generation allows us to prove lemmas that none of the strategies managed to prove. The list of these lemmas has been extracted by the results.py step at the previous step. It is provided in the `lemmaToTactic.txt` file that can be found under the `tacticGenerationBenchmark` folder.

#### Running the benchmark
To run the tactic generation benchmark as presented in the paper, run the following commands 
```bash 
% cd /workspace/tamarin-prover/artifacts/tacticGenerationBenchmark
% source /opt/venv/bin/activate
% python3 tacticGenBench.py -p=1 lemmaToTactic_fast.txt
``` 
The results will be stored under the `tacticGeneration/results` folder. The script results give a textual summary of the lemmas proved (or failed) by the benchmark while the other files store the proofs and attack traces that have been reached for each lemma.

#### Analysing the results

To extract information from these results, run the following:
```bash
% python3 resultsScripts/resultsTacticGen.py tacticGeneration/results/scriptResult_fast --output=data_fast.json
``` 
It will generate the file data.json. This script uses the `result_strategiesBenchmark_merged.json` file that contains the results of the strategies benchmark and adds the results of the tactics generation benchmark.
To analyse the results, run 
```bash
% python3 resultsScripts/results.py data_fast.json
```
It will use the data.json file present (discussed above) in the folder to generate the tables and graphs shown in the paper. They can be found under `results`.

## Benchmarks (paper version)

### Finding the results of the paper

If the reader is only interested in finding the results of our experiment, they will be able to find them under the following directories:

- For the strategy benchmark: /workspace/tamarin-prover/artifacts/strategiesBenchmark/results_fullscale
    - The subfolders `result_strategiesBenchmark_server_X` each contains a subset of the experience results. They are multiple because we did split the experiment in 5 batches across 3 servers. The denomination server_X_Y indicates that the Yth subset of the experiment has been run on server X.
    - The folder `tables_and_graphs` contains the analysis of the experiments has generated by the script `results.py`. The name of the table indicates where they appear in the paper. No results of tactic generation are integrated in these tables.
 
- For the tactic generation benchmark:  /workspace/tamarin-prover/artifacts/tacticGenerationBenchmark/results_fullscale
    - The file `scriptResults` gives the output of the script `tacticGenBench.py`
    - The folder `tables_and_graphs` contains the analysis of the experiments has generated by the script `results.py`. The name of the table indicates where they appear in the paper.



### Running the full scale strategy benchmark

*Requirements:*  We assume the full benchmark would be run on a server and therefore require 40 cores and 400G.

The full benchmark is run following the same steps as the small-scale benchmark. Execute the following commands:

```bash
% cd /workspace/tamarin-prover/artifacts/strategiesBenchmark
% batch-tamarin run recipe_strategy_benchmark.json
```
The results of the analysis are then stored under the `result_strategiesBenchmark` folder.

For the results analysis:
```bash
% source /opt/venv/bin/activate
% python3 resultsAnalysisScripts/analyseResultsBatchTamarinMergedVersion.py result_strategiesBenchmark/execution_report.json
% python3 resultsAnalysisScripts/results.py result_strategiesBenchmark/execution_report_extracted.json
```

### Running the full scale tactic benchmark

*Requirements:*  We assume the full benchmark would be run on a server and therefore require 40 cores and 400G.

The full benchmark is run following the same steps as the small-scale benchmark. Execute the following commands:
```bash 
% cd /workspace/tamarin-prover/artifacts/tacticGenerationBenchmark
% source /opt/venv/bin/activate
% python3 tacticGenBench.py -p=10 lemmaToTactic.txt
``` 

For the results analysis:
```bash
% source /opt/venv/bin/activate
% python3 resultsScripts/resultsTacticGen.py tacticGeneration/results/scriptResult --output=data_full.json
% python3 resultsScripts/results.py data_full.json
``` 