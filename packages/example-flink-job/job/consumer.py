import logging
import sys
import os
from pyflink.common import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kafka import FlinkKafkaProducer, FlinkKafkaConsumer
from pyflink.datastream.formats.json import JsonRowSerializationSchema
from pyflink.common.serialization import SimpleStringSchema

# Initialize logging
logging.basicConfig(stream=sys.stdout, level=logging.DEBUG, format="%(message)s")

def read_from_kafka(env, topic, broker):
    deserialization_schema = SimpleStringSchema()
    kafka_consumer = FlinkKafkaConsumer(
        topics=topic,
        deserialization_schema=deserialization_schema,
        properties={'bootstrap.servers': 'webb:9092', 'group.id': 'test_group_1'}
    )
    kafka_consumer.set_start_from_earliest()

    env.add_source(kafka_consumer).print()
    env.execute("Read from Kafka")

if __name__ == '__main__':
    if not os.getenv('TOPIC') or not os.getenv('BROKER'):
        logging.error("Environment variables TOPIC or BROKER are not set correctly.")
        sys.exit(1)
    env = StreamExecutionEnvironment.get_execution_environment()

    topic = os.getenv("TOPIC")
    broker = os.getenv("BROKER")
    logging.info("Starting to read data from Kafka")
    read_from_kafka(env, topic, broker)
