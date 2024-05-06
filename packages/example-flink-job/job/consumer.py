# import os
# from pyflink.table import DataTypes
# from pyflink.datastream import StreamExecutionEnvironment
# from pyflink.datastream.connectors import FlinkKafkaConsumer
# from pyflink.common.serialization import SimpleStringSchema
#
# def process_message(message):
#     # Your custom processing logic here
#     return "Processed: " + message
#
# def read_from_kafka(env, topic, broker):
#     deserialization_schema = SimpleStringSchema()
#     kafka_consumer = FlinkKafkaConsumer(
#         topics=[topic],
#         deserialization_schema=deserialization_schema,
#         properties={'bootstrap.servers': broker, 'group.id': 'test_group_1'}
#     )
#     kafka_consumer.set_start_from_earliest()
#
#     # Apply the process_message function to each message
#     env.add_source(kafka_consumer).flat_map(lambda x: [process_message(x)])
#     # Start the environment
#     env.execute("Read from Kafka")
#
# if __name__ == '__main__':
#     env = StreamExecutionEnvironment.get_execution_environment()
#     # topic = os.getenv("TOPIC")
#     # broker = os.getenv("BROKER")
#     topic = "Rides"
#     broker = "webb:9092"
#     read_from_kafka(env, topic, broker)
from pyflink.datastream import StreamExecutionEnvironment, TimeCharacteristic
from pyflink.table import StreamTableEnvironment, DataTypes, EnvironmentSettings
from pyflink.table.descriptors import Schema, Kafka, Json


def from_kafka_to_kafka_demo():
    s_env = StreamExecutionEnvironment.get_execution_environment()
    s_env.set_stream_time_characteristic(TimeCharacteristic.EventTime)
    s_env.set_parallelism(1)

    # use blink table planner
    st_env = StreamTableEnvironment \
        .create(s_env, environment_settings=EnvironmentSettings
                .new_instance()
                .in_streaming_mode()
                .use_blink_planner().build())

    # register source and sink
    register_rides_source(st_env)
    register_rides_sink(st_env)

    # query
    st_env.from_path("source").insert_into("sink")

    # execute
    st_env.execute("2-from_kafka_to_kafka")


def register_rides_source(st_env):
    st_env \
        .connect(  # declare the external system to connect to
        Kafka()
            .version("universal")
            .topic("Rides")
            .start_from_earliest()
            .property("zookeeper.connect", "webb:2181")
            .property("bootstrap.servers", "webb:9092")) \
        .with_format(  # declare a format for this system
        Json()
            .fail_on_missing_field(True)
            .schema(DataTypes.ROW([
            DataTypes.FIELD("rideId", DataTypes.BIGINT()),
            DataTypes.FIELD("isStart", DataTypes.BOOLEAN()),
            DataTypes.FIELD("eventTime", DataTypes.STRING()),
            DataTypes.FIELD("lon", DataTypes.FLOAT()),
            DataTypes.FIELD("lat", DataTypes.FLOAT()),
            DataTypes.FIELD("psgCnt", DataTypes.INT()),
            DataTypes.FIELD("taxiId", DataTypes.BIGINT())]))) \
        .with_schema(  # declare the schema of the table
        Schema()
            .field("rideId", DataTypes.BIGINT())
            .field("taxiId", DataTypes.BIGINT())
            .field("isStart", DataTypes.BOOLEAN())
            .field("lon", DataTypes.FLOAT())
            .field("lat", DataTypes.FLOAT())
            .field("psgCnt", DataTypes.INT())
            .field("eventTime", DataTypes.STRING())) \
        .in_append_mode() \
        .create_temporary_table("source")


def register_rides_sink(st_env):
    st_env \
        .connect(  # declare the external system to connect to
        Kafka()
            .version("universal")
            .topic("TempResults")
            .property("zookeeper.connect", "webb:2181")
            .property("bootstrap.servers", "webb:9092")) \
        .with_format(  # declare a format for this system
        Json()
            .fail_on_missing_field(True)
            .schema(DataTypes.ROW([
            DataTypes.FIELD("rideId", DataTypes.BIGINT()),
            DataTypes.FIELD("taxiId", DataTypes.BIGINT()),
            DataTypes.FIELD("isStart", DataTypes.BOOLEAN()),
            DataTypes.FIELD("lon", DataTypes.FLOAT()),
            DataTypes.FIELD("lat", DataTypes.FLOAT()),
            DataTypes.FIELD("psgCnt", DataTypes.INT()),
            DataTypes.FIELD("rideTime", DataTypes.STRING())
        ]))) \
        .with_schema(  # declare the schema of the table
        Schema()
            .field("rideId", DataTypes.BIGINT())
            .field("taxiId", DataTypes.BIGINT())
            .field("isStart", DataTypes.BOOLEAN())
            .field("lon", DataTypes.FLOAT())
            .field("lat", DataTypes.FLOAT())
            .field("psgCnt", DataTypes.INT())
            .field("rideTime", DataTypes.STRING())) \
        .in_append_mode() \
        .create_temporary_table("sink")


if __name__ == '__main__':
    from_kafka_to_kafka_demo()
