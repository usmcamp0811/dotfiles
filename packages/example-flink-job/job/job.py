import os
from pyflink.common.serialization import SimpleStringSchema
from pyflink.common.typeinfo import Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors import FlinkKafkaConsumer

def hello():
    return "hello"

def main():
    # Set up the environment
    env = StreamExecutionEnvironment.get_execution_environment()

    # Kafka configuration
    kafka_server = os.getenv('KAFKA_SERVER', 'localhost:9092')
    kafka_topic = os.getenv('KAFKA_TOPIC', 'test_topic')
    properties = {
        'bootstrap.servers': kafka_server,
        'group.id': 'test_group'
    }

    # Define the source: reading from Kafka
    kafka_consumer = FlinkKafkaConsumer(
        kafka_topic,
        SimpleStringSchema(),
        properties)
    data_stream = env.add_source(kafka_consumer)

    # Define the data processing pipeline
    counts = data_stream \
        .flat_map(lambda line: [(word, 1) for word in line.split()]) \
        .returns(Types.TUPLE([Types.STRING(), Types.INT()])) \
        .key_by(lambda word: word[0]) \
        .time_window(Time.seconds(5)) \
        .reduce(lambda a, b: (a[0], a[1] + b[1]))

    # Print the results
    counts.print()

    # Execute the job
    env.execute("Kafka Streaming WordCount")

if __name__ == "__main__":
    print(hello())
    # main()
