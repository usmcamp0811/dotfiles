################################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
################################################################################
import logging
import sys
import os

from pyflink.common import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors.kafka import FlinkKafkaProducer, FlinkKafkaConsumer
from pyflink.datastream.formats.csv import CsvRowSerializationSchema, CsvRowDeserializationSchema
from pyflink.common.serialization import SimpleStringSchema


def reverse_text(text):
    try:
        return [text[::-1]]
    except ValueError:
        return [text]

def add_constant(value):
    try:
        return str(int(value) + 10)
    except ValueError:
        return value

def read_from_kafka(env: StreamExecutionEnvironment):
    # Define the deserialization schema for the consumer
    deserialization_schema = SimpleStringSchema()
    
    # Define Kafka consumer
    kafka_consumer = FlinkKafkaConsumer(
        topics='example-input-topic',
        deserialization_schema=deserialization_schema,
        properties={'bootstrap.servers': broker, 'group.id': 'test_group_1'}
    )
    # kafka_consumer.set_start_from_earliest()

    # Define Kafka producer
    kafka_producer = FlinkKafkaProducer(
        topic='example-output-topic',
        serialization_schema=SimpleStringSchema(),
        producer_config={'bootstrap.servers': broker}
    )
    
    # Consume from 'example-topic' and produce to 'example-out'
    # env.add_source(kafka_consumer).add_sink(kafka_producer)
    datastream = env.add_source(kafka_consumer)
    datastream.print()
    datastream = datastream.flat_map(reverse_text, output_type=Types.STRING())
    datastream = datastream.add_sink(kafka_producer)
    # Execute the Flink job
    env.execute("Read and Write to Kafka")
    return datastream

if __name__ == '__main__':
    topic = os.getenv("TOPIC")
    broker = os.getenv("BROKER")

    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(message)s")

    env = StreamExecutionEnvironment.get_execution_environment()
    # env.add_jars("file:///path/to/flink-sql-connector-kafka-1.15.0.jar")
    print("start reading data from kafka")
    ds = read_from_kafka(env)
    print(ds)

