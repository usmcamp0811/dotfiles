import logging
import sys

from pyflink.common import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kafka import FlinkKafkaProducer, FlinkKafkaConsumer
from pyflink.datastream.formats.json import JsonRowSerializationSchema
from pyflink.common.serialization import SimpleStringSchema

# Initialize logging
logging.basicConfig(stream=sys.stdout, level=logging.DEBUG, format="%(message)s")

def write_to_kafka(env):
    type_info = Types.ROW([Types.INT(), Types.STRING()])
    ds = env.from_collection(
        [(1, 'hi'), (2, 'hello'), (3, 'hi'), (4, 'hello'), (5, 'hi'), (6, 'hello'), (6, 'hello')],
        type_info=type_info)

    serialization_schema = JsonRowSerializationSchema.Builder() \
        .with_type_info(type_info) \
        .build()
    kafka_producer = FlinkKafkaProducer(
        topic='test_json_topic',
        serialization_schema=serialization_schema,
        producer_config={'bootstrap.servers': 'webb:9092', 'group.id': 'test_group'}
    )

    ds.add_sink(kafka_producer)
    env.execute("Write to Kafka")

def read_from_kafka(env):
    deserialization_schema = SimpleStringSchema()
    kafka_consumer = FlinkKafkaConsumer(
        topics='test_json_topic',
        deserialization_schema=deserialization_schema,
        properties={'bootstrap.servers': 'webb:9092', 'group.id': 'test_group_1'}
    )
    kafka_consumer.set_start_from_earliest()

    env.add_source(kafka_consumer).print()
    env.execute("Read from Kafka")

if __name__ == '__main__':
    env = StreamExecutionEnvironment.get_execution_environment()

    if len(sys.argv) > 1 and sys.argv[1] == 'read':
        logging.info("Starting to read data from Kafka")
        read_from_kafka(env)
    else:
        logging.info("Starting to write data to Kafka")
        write_to_kafka(env)
