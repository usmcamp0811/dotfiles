import argparse
import sys
import simplejson
from pyflink.common.typeinfo import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors import FlinkKafkaConsumer, FlinkKafkaProducer
from pyflink.common.serialization import SimpleStringSchema


def generic_flat_map(message):
    try:
        # Do nothing if the message has caused an error
        if message.startswith('ERROR in Flink job'):
            return [message]
        return [simplejson.dumps({'payload': message})]

    except Exception as e:
        return ['ERROR in Flink job | Error Message: {} | Data Stream Record: {}'.format(e, message)]


def remove_error_messages(message):
    if not message.startswith('ERROR in Flink job'):
        yield message


def keep_error_messages(message):
    if message.startswith('ERROR in Flink job'):
        yield message


def run(pipeline_name, input_topic, output_topic, error_topic, kafka_sasl_username, kafka_sasl_password, kafka_server):
    # Setup the Flink execution environment
    env = StreamExecutionEnvironment.get_execution_environment()

    kafka_consumer = FlinkKafkaConsumer(topics=input_topic, deserialization_schema=SimpleStringSchema(),
                                        properties={
                                            'bootstrap.servers': kafka_server,
                                            'group.id': 'flink-generic'
                                        })
    ds = env.add_source(kafka_consumer)

    # Define the Pipeline
    ds = ds.flat_map(generic_flat_map, output_type=Types.STRING())
    ds_filtered = ds.flat_map(remove_error_messages, output_type=Types.STRING())
    ds_errors = ds.flat_map(keep_error_messages, output_type=Types.STRING())
   
    # Create Kafka Data Sink
    producer_config = {
                    'bootstrap.servers': kafka_server,
                    'group.id': 'flink-generic'
    }

    kafka_producer1 = FlinkKafkaProducer(topic=output_topic, serialization_schema=SimpleStringSchema(),
                                         producer_config=producer_config)
    ds_filtered.add_sink(kafka_producer1)

    if error_topic is not None:
        # Create Kafka Data Sink for Error Messages
        kafka_producer2 = FlinkKafkaProducer(topic=error_topic, serialization_schema=SimpleStringSchema(),
                                             producer_config=producer_config)
        ds_errors.add_sink(kafka_producer2)

    # Submit Job For Execution
    env.execute(pipeline_name)


if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--jobname',
        dest='jobname',
        required=False,
        help='Name of the flink job.')
    parser.add_argument(
        '--inputtopic',
        dest='inputtopic',
        required=False,
        help='Input topic to process.')
    parser.add_argument(
        '--outputtopic',
        dest='outputtopic',
        required=False,
        help='Output topic to publish results to.')
    parser.add_argument(
        '--errortopic',
        dest='errortopic',
        required=False,
        help='Output topic to publish errors to.')
    parser.add_argument(
        '--kafka_username',
        dest='kafka_sasl_username',
        required=False,
        help='Kafka SASL Username.')
    parser.add_argument(
        '--kafka_password',
        dest='kafka_sasl_password',
        required=False,
        help='Output file to write results to.')
    parser.add_argument(
        '--kafka_server',
        dest='kafka_server',
        required=False,
        help='URL of Kafka bootstrap server.')
    parser.add_argument(
        '--hadooppath',
        dest='hadooppath',
        required=False,
        help='The path on the hadoop server where the job files are located')

    known_args, _ = parser.parse_known_args(sys.argv[1:])

    jobname="example-flink-job" 
    inputtopic="example-topic" 
    outputtopic="example-output" 
    errortopic="example-error" 
    kafka_server="10.8.0.70:9092"
    kafka_sasl_username=None
    kafka_sasl_password=None
    run(jobname, inputtopic, outputtopic, errortopic, kafka_sasl_username, kafka_sasl_password, kafka_server)
    # run(known_args.jobname, known_args.inputtopic, known_args.outputtopic, known_args.errortopic, known_args.kafka_sasl_username, known_args.kafka_sasl_password, known_args.kafka_server, known_args.hadooppath)
