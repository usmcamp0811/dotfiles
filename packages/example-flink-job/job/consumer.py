import os
from pyflink.common import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors import FlinkKafkaConsumer
from pyflink.common.serialization import SimpleStringSchema

def process_message(message):
    # Your custom processing logic here
    return "Processed: " + message

def read_from_kafka(env, topic, broker):
    deserialization_schema = SimpleStringSchema()
    kafka_consumer = FlinkKafkaConsumer(
        topics=topic,
        deserialization_schema=deserialization_schema,
        properties={'bootstrap.servers': broker, 'group.id': 'test_group_1'}
    )
    kafka_consumer.set_start_from_earliest()

    # Apply the process_message function to each message
    env.add_source(kafka_consumer).flat_map(lambda x: [(process_message(x),)], output_type=Types.TUPLE([Types.STRING()]))
    # Start the environment
    env.execute("Read from Kafka")

if __name__ == '__main__':
    env = StreamExecutionEnvironment.get_execution_environment()
    topic = os.getenv("TOPIC")
    broker = os.getenv("BROKER")
    read_from_kafka(env, topic, broker)

