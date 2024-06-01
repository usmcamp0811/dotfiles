import logging
import sys
import os

from pyflink.common import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kafka import FlinkKafkaProducer, FlinkKafkaConsumer
from pyflink.datastream.formats.csv import CsvRowSerializationSchema, CsvRowDeserializationSchema
from pyflink.common.serialization import SimpleStringSchema


def reverse_text(message):
    """
    This is just meant to be an example
    Simple Map function that reverses any text that its given. 
    """
    logging.info("Reversing Text")
    return [message[::-1]]

def run(env: StreamExecutionEnvironment):
    # Define the deserialization schema for the consumer
    deserialization_schema = SimpleStringSchema()
    
    # Define Kafka consumer
    kafka_consumer = FlinkKafkaConsumer(
        topics='example-input-topic',
        deserialization_schema=deserialization_schema,
        properties={'bootstrap.servers': broker, 'group.id': 'test_group_1'}
    )
    
    # Define Kafka producer
    kafka_producer = FlinkKafkaProducer(
        topic='example-output-topic',
        serialization_schema=SimpleStringSchema(),
        producer_config={'bootstrap.servers': broker}
    )
    
    # Consume from 'example-topic' and produce to 'example-out'
    datastream = env.add_source(kafka_consumer)
    datastream = datastream.flat_map(reverse_text, output_type=Types.STRING())
    datastream = datastream.add_sink(kafka_producer)

    # Execute the Flink job
    env.execute("Read and Write to Kafka")
    return datastream

if __name__ == '__main__':
    broker = os.getenv("KAFKA_BROKER")
    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(message)s")
    env = StreamExecutionEnvironment.get_execution_environment()
    run(env)

