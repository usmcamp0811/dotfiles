import logging
import sys
import os
from pyflink.common import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kafka import FlinkKafkaProducer, FlinkKafkaConsumer
from pyflink.datastream.formats.json import JsonRowSerializationSchema
from pyflink.common.serialization import SimpleStringSchema

def write_to_kafka(env, topic, broker):
    type_info = Types.ROW([Types.INT(), Types.STRING()])
    ds = env.from_collection(
        [(1, 'hi'), (2, 'hello'), (3, 'hi'), (4, 'hello'), (5, 'hi'), (6, 'hello'), (6, 'hello')],
        type_info=type_info)

    serialization_schema = JsonRowSerializationSchema.Builder() \
        .with_type_info(type_info) \
        .build()
    kafka_producer = FlinkKafkaProducer(
        topic=topic,
        serialization_schema=serialization_schema,
        producer_config={'bootstrap.servers': broker, 'group.id': 'test_group'}
    )

    ds.add_sink(kafka_producer)
    env.execute("Write to Kafka")

if __name__ == '__main__':
    if not os.getenv('TOPIC') or not os.getenv('BROKER'):
        logging.error("Environment variables TOPIC or BROKER are not set correctly.")
        sys.exit(1)
    env = StreamExecutionEnvironment.get_execution_environment()

    topic = os.getenv("TOPIC")
    broker = os.getenv("BROKER")
    logging.info("Starting to write data to Kafka")
    write_to_kafka(env, topic, broker)
