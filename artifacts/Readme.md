This folder contains the pythons scripts necessary to reproduce the experiences described in the paper "Adaptive Proof Strategies for Protocol Verification in Tamarin". Since the benchmarks are very long to run and the results files are too heavy to be stored on a git, provide a file data.json that contains the data extracted from our results, before analysis.

## Strategies benchmark.

#### Running the benchmarks
Running the strategies benchmark requires the tool `batch-tamarin`. It can be installed with the following command `pip3 install batch-tamarin`.

We propose two recipes for the benchmark (both can be found under the strategiesBenchmark folder):
-Full results (estimated running time, several weeks): recipeStrategiesBenchmark.json
-Sample from the full benchmark we used to confirm the results (estimated running time, 3 to 4 days): recipe__bigBenchEchantillon.json

To run a recipe, the command is `batch-tamarin run [recipe.json]`. The results of the analysis are then stored under the result[name of the recipe] folder.

TODO: maybe need to change execution file in the recipe after make

#### Analysing the results
To analyse the results of these benchmark (and generate the graph and table presented in the paper), one can use the scripts available in the strategiesBenchmark/resultsAnalysisScripts folder.
First, run `python3 analyseResultsBatchTamarinMergedVersion.py [path to results folder]\execution_report.json`.
And then `python3 results.py [path to results folder]\execution_report_extracted.json`
Results are generated in a strategiesBenchmark/resultsAnalysisScripts/results subfolder.
