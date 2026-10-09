# Artifacts for "Adaptive Proof Strategies for Protocol Verification in Tamarin"

- [How to use this artifact](#how-to-use-this-artifact)
- [Experimenting with the tools](#experimenting-with-the-tools)
- [Reduced benchmark (for artifact evaluation)](#reduced-benchmark-for-artifact-evaluation)
- [Full benchmark (paper version)](#full-benchmark-paper-version)
- [Running the tool outside of Docker](#running-the-tool-outside-of-docker)

## How to use this artifact

This repository contains two folders:

- `tamarin-prover`: a fork of the Tamarin prover with the integrated adaptive strategies (see [Experimenting with the tools](#experimenting-with-the-tools) on how to use it).
- `artifacts`: the Python scripts, theory files and recipes needed to reproduce the experiments described in the paper (see [Reduced benchmark](#reduced-benchmark-for-artifact-evaluation) and [Full benchmark](#full-benchmark-paper-version)).

To experiment with the tools presented in this paper and reproduce the experiments described in Section 4, we provide a Dockerfile. The image can be built and the container started by running the following commands from the root of this repository:

```bash
docker build --network=host -t tamarin:strategies -f ./Dockerfile .
docker run -it -v "$PWD":/workspace/tamarin-prover tamarin:strategies
```

Building the image compiles Tamarin from source and can take a while. The repository is mounted in the container at `/workspace/tamarin-prover`, so every file produced in the container is also visible in this directory on the host.

**Note for Docker Desktop users (macOS/Windows):** the reduced benchmark requires 4 cores and 30 GB of memory (see below). Make sure the resources allocated to Docker Desktop (Settings → Resources) are at least that large.

## Experimenting with the tools

To use the examples presented in this section, go to the `tamarin-prover` folder of the repository (`/workspace/tamarin-prover/tamarin-prover` in the container):

```bash
cd /workspace/tamarin-prover/tamarin-prover
```

We suggest using the toy example `SourceOfUniqueness.spthy` (provided in this folder) to test the tool, as it gives fast proofs. It can however be replaced by any Tamarin theory file (many can be found in the `tamarin-prover/examples` folder).

### Tamarin strategies

This version of Tamarin provides five new strategies in addition to the usual behaviour of the tool. They are selected with the command-line flag `--strategy[=STRATEGY]`. By default, no strategy is used and Tamarin behaves as usual.

To use the default Tamarin behaviour, run the following command (note that, on this example, the proof does not terminate with the default behaviour; use Ctrl-C to stop it):

```bash
tamarin-prover --prove SourceOfUniqueness.spthy
```

To try our strategies, use the following options:

- Escape (deprioritise goals in a loop):

```bash
tamarin-prover --prove --strategy=Escape SourceOfUniqueness.spthy
```

The output should end with

```
==============================================================================
summary of summaries:

analyzed: SourceOfUniqueness.spthy

  processing time: 1.21s
  
  uniqueness (all-traces): verified (86 steps)

==============================================================================
```

indicating that the property was successfully proved (the processing time depends on the machine). Similar outputs are produced by the other strategies, detailed below.

- Probabilistic (choose a problematic goal with decreasing probability). The seed of the PRNG used to decide whether or not to use a goal can be set with the optional flag `--seed[=Int]`:

```bash
tamarin-prover --prove --strategy=Proba SourceOfUniqueness.spthy
tamarin-prover --prove --strategy=Proba --seed=42 SourceOfUniqueness.spthy
```

- Backtrack (backtrack to the goal before the loop):

```bash
tamarin-prover --prove --strategy=Backtrack SourceOfUniqueness.spthy
```

- BackAndAvoid (backtrack and deprioritise the goals responsible for the backtracking):

```bash
tamarin-prover --prove --strategy=BackAndAvoid SourceOfUniqueness.spthy
```

- CollectAndRestart (deprioritise branches rather than goals):

```bash
tamarin-prover --prove --strategy=CollectAndRestart SourceOfUniqueness.spthy
```

### Tactic generation

To generate tactics, Tamarin needs to run with one of the five strategies listed above: the default behaviour does not detect loops and therefore cannot export "problematic" goals. To activate the export of goals during a proof, use the flag `--exportGoals`.
With this option set, Tamarin prints the problematic goals on the standard error output. They can be redirected to a file and compiled into a tactic using the commands below. The tactic can then be copy-pasted into the original theory file and used to retry the proof.

```bash
tamarin-prover --prove --strategy=Escape --exportGoals SourceOfUniqueness.spthy 2> exportGoals.txt
python3 exportTactic.py exportGoals.txt
```

The tactic printed by `exportTactic.py` should be

```
tactic: exportGoals
deprio: 
allGoal "DisjG (Disj {getDisj = [GGuarded Ex [(y,LSortMsg),(j,LSortNode)] [Action Bound 0 (Fact {factTag = ProtoFact Linear Complicated 1, factAnnotations = fromList [], factTerms = [Bound 1]})] (GAto (Less Bound 0 Free #j)),GGuarded Ex [(y,LSortMsg),(j,LSortNode)] [Action Bound 0 (Fact {factTag = ProtoFact Linear Simpleunique 1, factAnnotations = fromList [], factTerms = [Bound 1]})] (GAto (Less Bound 0 Free #j))]})"
deprio: 
allGoal "DisjG (Disj {getDisj = [GGuarded Ex [(y,LSortMsg),(j,LSortNode)] [Action Bound 0 (Fact {factTag = ProtoFact Linear Complicated 1, factAnnotations = fromList [], factTerms = [Bound 1]})] (GAto (Less Bound 0 Free #vr)),GGuarded Ex [(y,LSortMsg),(j,LSortNode)] [Action Bound 0 (Fact {factTag = ProtoFact Linear Simpleunique 1, factAnnotations = fromList [], factTerms = [Bound 1]})] (GAto (Less Bound 0 Free #vr))]})"
```

To automate this process, we also provide the script `tacticGeneration.py`. It takes as parameters the theory file and the lemma to be proved. The script first tries to prove the lemma with the chosen strategy (Escape by default). If the proof succeeds, the process stops; otherwise, the script generates a tactic from the exported goals and retries the proof with the generated tactic. By default, at most 3 proof attempts are made (a first one without a tactic, then up to two with generated tactics).

The script accepts the following options:

- `--timeout=[Int]`: timeout of the first attempt in seconds (default: 6000). The timeout is doubled at each new attempt.
- `--bound=[Int]` (or `-b`): maximum number of proof attempts (default: 3).
- `--strategy=[STRATEGY]`: strategy used for the proofs (default: Escape).
- `--heuristic=[HEURISTIC]`: Tamarin heuristic used for the first attempt (default: `s`).
- `-m [MACRO]`: macro passed to Tamarin (equivalent to Tamarin's `-D` option).
- `--diff`: to be set for observational-equivalence (diff) theories.

```bash
# Example with a timeout of 1s. The first attempt should fail and the second one should succeed in less than a second.
source /opt/venv/bin/activate
python3 tacticGeneration.py SourceOfUniqueness.spthy uniqueness --strategy=Proba --timeout=1
```

The script should end with `Prove lemma uniqueness (file:SourceOfUniqueness.spthy) with heuristic: {uniqueness_0}.`, meaning that the lemma was proved with the tactic generated after the first attempt. All files produced by the script are stored in the `tacticGeneration` folder:

- `tacticGeneration/generatedTactics/` contains the generated tactics (named `<lemma>_<attempt>`, e.g. `uniqueness_0`);
- `tacticGeneration/theories/` contains the copy of the theory file, including the generated tactics, on which the proofs are run (the original theory file is not modified);
- `tacticGeneration/results/` contains the outputs of Tamarin.

## Reduced benchmark (for artifact evaluation)

We distinguish two benchmarks: the benchmark of the strategies (in the `artifacts/strategiesBenchmark` folder) and the benchmark of the tactic generation (in the `artifacts/tacticGenerationBenchmark` folder).

The experiments presented in the paper required around a week of computation, parallelised on three servers. For the sake of reproducibility, we present in this section a small-scale version of the benchmarks that illustrates the process and fits in the 24-hour time budget of the artifact evaluation. Please note that this time constraint means that only a very small number of lemmas can be tested. Thus, the statistical results produced by the reduced benchmark do not reflect those of the paper.

To rerun the full benchmark or to look at the results we provide, we refer the reader to the section [Full benchmark (paper version)](#full-benchmark-paper-version) below.

To run the benchmarks, go to the `artifacts` folder:

```bash
cd /workspace/tamarin-prover/artifacts
```

### Strategies benchmark (strategiesBenchmark folder)

*Requirements:* we assume that the reduced benchmark is run on a laptop. Therefore, we only require 4 cores and 10 GB of memory. The reduced benchmark consists of 18 proof tasks (3 lemmas × 6 configurations: the default behaviour and the 5 strategies), each with a timeout of one hour; it therefore takes at most 18 hours.

#### Running the benchmark

To run the benchmark, we use batch-tamarin, a wrapper for running Tamarin in batch mode. To execute the benchmark, run:

```bash
cd /workspace/tamarin-prover/artifacts/strategiesBenchmark
batch-tamarin run recipe_strategy_benchmark_fast.json
```

The results are then stored in the `result_strategiesBenchmark_fast` folder.

#### Analysing the results

To analyse the results of this benchmark (and generate the graph and tables presented in the paper), use the scripts available in the `strategiesBenchmark/resultsAnalysisScripts` folder. Run the following:

```bash
source /opt/venv/bin/activate
python3 resultsAnalysisScripts/analyseResultsBatchTamarinMergedVersion.py result_strategiesBenchmark_fast/execution_report.json
python3 resultsAnalysisScripts/results.py result_strategiesBenchmark_fast/execution_report_extracted.json
```

The results of the analysis (tables and graphs) are generated in `results/result_strategiesBenchmark_fast`. This folder also contains the file `lemmaToTactic.txt`, which lists the lemmas that none of the strategies managed to prove.

The results discussed in Section 4 can be found in `strategiesBenchmark/results_fullscale` (see [Finding the results of the paper](#finding-the-results-of-the-paper)).

Note: these results do not include the results of the tactic generation benchmark.

### Tactic generation benchmark (tacticGenerationBenchmark folder)

The goal of this benchmark is to check whether tactic generation allows us to prove lemmas that none of the strategies managed to prove. For the full benchmark, the list of these lemmas has been extracted by `results.py` (see the previous step) from the results of the full strategies benchmark, and is provided in the file `tacticGenerationBenchmark/lemmaToTactic.txt`. For the reduced benchmark, we selected two of these lemmas, listed in `tacticGenerationBenchmark/lemmaToTactic_fast.txt`.

*Requirements:* each lemma is attempted at most 3 times, with timeouts of 15, 30 and 60 minutes; the reduced benchmark therefore takes at most 3.5 hours.

#### Running the benchmark

To run the reduced tactic generation benchmark, run the following commands:

```bash
cd /workspace/tamarin-prover/artifacts/tacticGenerationBenchmark
source /opt/venv/bin/activate
python3 tacticGenBench.py -p=1 lemmaToTactic_fast.txt
```

The option `-p` sets the number of lemmas processed in parallel. The results are stored in the `tacticGenerationBenchmark/tacticGeneration/results` folder. The file `scriptResult` gives a textual summary of the lemmas proved (or not) by the benchmark, while the other files store the proofs and attack traces that have been reached for each lemma.

#### Analysing the results

To extract information from these results, run the following:

```bash
python3 resultsScripts/resultsTacticGen.py tacticGeneration/results/scriptResult --output=data_fast.json
```

It generates the file `data_fast.json`. This script takes the results of the full strategies benchmark of the paper (file `resultsScripts/result_strategiesBenchmark_merged.json`, which can be changed with the option `--inputStrat`) and adds to them the results of the tactic generation benchmark.
To analyse the results, run:

```bash
python3 resultsScripts/results.py data_fast.json
```

It uses the `data_fast.json` file generated above to produce the tables and graphs shown in the paper. They can be found in the `results` folder.

## Full benchmark (paper version)

### Finding the results of the paper

Readers who are only interested in the results of our experiments can find them in the following directories:

- For the strategies benchmark: `/workspace/tamarin-prover/artifacts/strategiesBenchmark/results_fullscale`
    - Each subfolder `result_strategiesBenchmark_server_X_Y` contains a subset of the experimental results. There are several of them because we split the experiment into 5 batches across 3 servers: the name `server_X_Y` indicates that the Y-th subset of the experiment has been run on server X. The file `result_strategiesBenchmark_merged.json` contains the merged results of these 5 batches.
    - The folder `tables_and_graphs` contains the analysis of the experiments as generated by the script `results.py`. The name of each table indicates where it appears in the paper. No results of the tactic generation are included in these tables.

- For the tactic generation benchmark: `/workspace/tamarin-prover/artifacts/tacticGenerationBenchmark/results_fullscale`
    - The file `scriptResult` is the output of the script `tacticGenBench.py`.
    - The folder `tables_and_graphs` contains the analysis of the experiments as generated by the script `results.py`. The name of each table indicates where it appears in the paper.

### Running the full-scale strategies benchmark

*Requirements:* we assume that the full benchmark is run on a server; it requires 40 cores and 400 GB of memory.
**Warning:** the Docker container we provide cannot guarantee these conditions. To install batch-tamarin and the version of Tamarin used in the paper, see [Running the tool outside of Docker](#running-the-tool-outside-of-docker).

The full benchmark is run following the same steps as the reduced benchmark. Execute the following commands:

```bash
cd /workspace/tamarin-prover/artifacts/strategiesBenchmark
batch-tamarin run recipe_strategy_benchmark.json
```

The results are then stored in the `result_strategiesBenchmark` folder.

To analyse the results:

```bash
source /opt/venv/bin/activate
python3 resultsAnalysisScripts/analyseResultsBatchTamarinMergedVersion.py result_strategiesBenchmark/execution_report.json
python3 resultsAnalysisScripts/results.py result_strategiesBenchmark/execution_report_extracted.json
```

### Running the full-scale tactic generation benchmark

*Requirements:* we assume that the full benchmark is run on a server; it requires 40 cores and 400 GB of memory.

The full benchmark is run following the same steps as the reduced benchmark. Execute the following commands:

```bash
cd /workspace/tamarin-prover/artifacts/tacticGenerationBenchmark
source /opt/venv/bin/activate
python3 tacticGenBench.py -p=10 lemmaToTactic.txt
```

To analyse the results:

```bash
source /opt/venv/bin/activate
python3 resultsScripts/resultsTacticGen.py tacticGeneration/results/scriptResult --output=data_full.json
python3 resultsScripts/results.py data_full.json
```

## Running the tool outside of Docker

The benchmarks only require the version of Tamarin with the strategies (see below), batch-tamarin, and Python 3.12 with the packages `tabulate numpy matplotlib pandas pydot pyparsing tree_sitter`. In the commands of the previous sections, replace `/workspace/tamarin-prover` with the path of this repository, and skip `source /opt/venv/bin/activate` if the Python packages are installed in your environment.

### Tamarin prover with strategies

We provide two options to run the version of Tamarin used in this paper outside of Docker:

- Binary version: we provide a binary (`artifacts/strategiesBenchmark/tamarin-prover-1.4.1-2468-g300638b4`, for x86-64 Linux only) that can be used directly to run Tamarin. Tamarin also requires [Maude](https://tamarin-prover.com/install.html) to be installed. To use the binary with batch-tamarin, either copy it to a directory of your `PATH` under the name `tamarin-prover`:

```bash
cp artifacts/strategiesBenchmark/tamarin-prover-1.4.1-2468-g300638b4 ~/.local/bin/tamarin-prover
```

  or change the path in the recipe files (`recipe_strategy_benchmark*.json`) to `"path": "tamarin-prover-1.4.1-2468-g300638b4"`.

- Compiling from source: follow the [installation guide of Tamarin](https://tamarin-prover.com/install.html) to install the dependencies. Then run the following from the root of this repository:

```bash
cd tamarin-prover
make
```

### Batch-tamarin

The artifact was tested with batch-tamarin 1.0.0, which can be installed from PyPI:

```bash
pipx install batch-tamarin==1.0.0   # or: pip install batch-tamarin==1.0.0
```

More information is available in the [batch-tamarin repository](https://github.com/tamarin-prover/batch-tamarin#installation).
