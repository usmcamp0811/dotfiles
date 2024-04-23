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


def run(pipeline_name, input_topic, output_topic, error_topic, kafka_sasl_username, kafka_sasl_password, kafka_server, hadooppath):
    # Setup the Flink execution environment
    env = StreamExecutionEnvironment.get_execution_environment()

    # If Kafka is being used as a data source or sink, add the kafka connector
    env.add_jars("file://{}".format(hadooppath + "/flink-sql-connector-kafka_2.11-1.14.3.jar"))

    #########################
    # Define the Data Source
    #########################
    # Create Kafka Data Source
    kafka_consumer = FlinkKafkaConsumer(topics=input_topic, deserialization_schema=SimpleStringSchema(),
                                        properties={'bootstrap.servers': kafka_server,
                                                    'group.id': 'flink-generic',
                                                    'security.protocol': 'SASL_SSL',
                                                    'sasl.mechanism': 'PLAIN',
                                                    "sasl.jaas.config": f"org.apache.kafka.common.security.plain.PlainLoginModule required username=\"{kafka_sasl_username}\" password=\"{kafka_sasl_password}\";"
                                                    })
    ds = env.add_source(kafka_consumer)

    ######################
    # Define the Pipeline
    ######################
    ds = ds.flat_map(generic_flat_map, output_type=Types.STRING())
    ds_filtered = ds.flat_map(remove_error_messages, output_type=Types.STRING())
    ds_errors = ds.flat_map(keep_error_messages, output_type=Types.STRING())
   
    #######################
    # Define the Data Sink
    #######################
    # Create Kafka Data Sink
    producer_config = {
                    'bootstrap.servers': kafka_server,
                    'group.id': 'flink-generic',
                    'security.protocol': 'SASL_SSL',
                    'sasl.mechanism': 'PLAIN',
                    "sasl.jaas.config": f"org.apache.kafka.common.security.plain.PlainLoginModule required username=\"{kafka_sasl_username}\" password=\"{kafka_sasl_password}\";"

    }
    kafka_producer1 = FlinkKafkaProducer(topic=output_topic, serialization_schema=SimpleStringSchema(),
                                         producer_config=producer_config)
    ds_filtered.add_sink(kafka_producer1)

    if error_topic is not None:
        # Create Kafka Data Sink for Error Messages
        kafka_producer2 = FlinkKafkaProducer(topic=error_topic, serialization_schema=SimpleStringSchema(),
                                             producer_config=producer_config)
        ds_errors.add_sink(kafka_producer2)

    ###########################
    # Submit Job For Execution
    ###########################
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
