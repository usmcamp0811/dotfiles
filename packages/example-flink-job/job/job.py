import argparse
import sys
import logging
from pyflink.common.typeinfo import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors import FlinkKafkaConsumer, FlinkKafkaProducer
from pyflink.common.serialization import SimpleStringSchema
import simplejson

def generic_flat_map(message):
    logging.info("Processing message")
    try:
        if message.startswith('ERROR in Flink job'):
            return [message]
        return [simplejson.dumps({'payload': message})]
    except Exception as e:
        error_msg = f'ERROR in Flink job | Error Message: {e} | Data Stream Record: {message}'
        return [error_msg]

def remove_error_messages(message):
    if not message.startswith('ERROR in Flink job'):
        yield message

def keep_error_messages(message):
    if message.startswith('ERROR in Flink job'):
        yield message

def run(pipeline_name, input_topic, output_topic, error_topic, kafka_server):
    logging.info(f"Starting Flink job: {pipeline_name}")
    env = StreamExecutionEnvironment.get_execution_environment()
    kafka_consumer = FlinkKafkaConsumer(input_topic, SimpleStringSchema(), {'bootstrap.servers': kafka_server, 'group.id': 'flink-generic'})
    ds = env.add_source(kafka_consumer).flat_map(generic_flat_map, Types.STRING())
    ds_filtered = ds.flat_map(remove_error_messages, Types.STRING())
    ds_errors = ds.flat_map(keep_error_messages, Types.STRING())

    producer_config = {'bootstrap.servers': kafka_server, 'group.id': 'flink-generic'}
    kafka_producer = FlinkKafkaProducer(output_topic, SimpleStringSchema(), producer_config)
    ds_filtered.add_sink(kafka_producer)
    
    if error_topic:
        kafka_producer_errors = FlinkKafkaProducer(error_topic, SimpleStringSchema(), producer_config)
        ds_errors.add_sink(kafka_producer_errors)

    env.execute(pipeline_name)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--jobname', default='default-flink-job', help='Name of the flink job.')
    parser.add_argument('--inputtopic', default='default-input', help='Input topic to process.')
    parser.add_argument('--outputtopic', default='default-output', help='Output topic to publish results to.')
    parser.add_argument('--errortopic', default='default-error', help='Output topic to publish errors to.')
    parser.add_argument('--kafka_server', default='localhost:9092', help='URL of Kafka bootstrap server.')

    args = parser.parse_args()
    run(args.jobname, args.inputtopic, args.outputtopic, args.errortopic, args.kafka_server)

