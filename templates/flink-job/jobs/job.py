import logging
import os
import sys

import google
from pyflink.common import Types
from pyflink.common.serialization import SimpleStringSchema
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kafka import FlinkKafkaConsumer, FlinkKafkaProducer

# This is example code change me


def reverse_text(message):
    """
    This is just meant to be an example
    Simple Map function that reverses any text that its given.
    """
    logging.info(f"Reversing Text: {message}")
    return [message[::-1]]


def run_example_flink_job(env: StreamExecutionEnvironment, broker: str):
    """
    The main function that defines and run the Flink Job
    """
    # Define the deserialization schema for the consumer
    deserialization_schema = SimpleStringSchema()

    # Define Kafka consumer
    kafka_consumer = FlinkKafkaConsumer(
        topics="example-input-topic",
        deserialization_schema=deserialization_schema,
        properties={"bootstrap.servers": broker, "group.id": "test_group_1"},
    )

    # Define Kafka producer
    kafka_producer = FlinkKafkaProducer(
        topic="example-output-topic",
        serialization_schema=SimpleStringSchema(),
        producer_config={"bootstrap.servers": broker},
    )

    # Consume from 'example-topic' and produce to 'example-out'
    datastream = env.add_source(kafka_consumer)
    datastream = datastream.flat_map(reverse_text, output_type=Types.STRING())
    datastream = datastream.add_sink(kafka_producer)

    # Execute the Flink job
    env.execute("Read and Write to Kafka")
    return datastream


# Example Code change me!

if __name__ == "__main__":
    broker = os.getenv("KAFKA_BROKER", "localhost:9092")
    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(message)s")
    env = StreamExecutionEnvironment.get_execution_environment()
    run_example_flink_job(env, broker)
