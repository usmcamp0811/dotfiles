# Example Flink Job

This is an example of how one might go about making a PyFlink Job as a Nix package. 
The package will create a Flink job that uses PyFlink to define the job. The Python
environment is defined using Poetry and built with nix using `poetry2nix`. The package
should run on any machine, it just expect the environment variable `KAFKA_BROKER` to be
set to the `hostname:port` of your Kafka cluster. The job is nothing to write home
about. It simply watches a topic called `example-input-topic` and for every new message
published it will reverse the text and publish the message to `example-output-topic`. 
I know super exciting! 

## Usage

**Run Job**

*Starts both a `jobmanager` and a `taskmanager`, then submits the job to be run.*

```
export KAFKA_BROKER="my-kafka-broker:9092"
nix run gitlab:usmcamp0811/dotfiles#example-flink-job
```

**Stop Job**

*This will stop both the `taskmanager` and the `jobmanager`*

```
nix run gitlab:usmcamp0811/dotfiles#example-flink-job.stop-all
```


## Testing with PyTest

This example job always demonstrates how PyTest can be used to run unit tests of your
Flink job. At the time of writing this I have yet to determine how to test the `run_example_flink_job`
function. This is due to some Java issues. If you know how please open an Issue or make a MR. 
The tests can be run with the following command. 

```
nix run gitlab:usmcamp0811/dotfiles#example-flink-job.test -- -vvv
```


## TODO's

- Additional Example Jobs
- Use Schema's
- Write to Timescale
