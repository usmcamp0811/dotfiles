import logging
import os
import sys

from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import DataTypes, EnvironmentSettings, StreamTableEnvironment
from pyflink.table.udf import udf


def run_example_flink_job(t_env: StreamTableEnvironment, broker: str):
    # Define Kafka source
    t_env.execute_sql(
        f"""
        CREATE TABLE kafka_source (
            username STRING,
            event STRING,
            event_ts AS TO_TIMESTAMP(event, 'yyyy-MM-dd''T''HH:mm:ss''Z'''),
            WATERMARK FOR event_ts AS event_ts - INTERVAL '1' SECOND
        ) WITH (
            'connector' = 'kafka',
            'topic' = 'example-table-topic-in',
            'properties.bootstrap.servers' = '{broker}',
            'properties.group.id' = 'test_group_1',
            'scan.startup.mode' = 'earliest-offset',
            'format' = 'json',
            'json.fail-on-missing-field' = 'false',
            'json.ignore-parse-errors' = 'true'
        )
        """
    )

    t_env.execute_sql(
        f"""
        CREATE TABLE agg_count (
            aggregated_counts VARCHAR(2000),
            window_time TIMESTAMP(3),
            PRIMARY KEY (window_time) NOT ENFORCED
        ) WITH (
            'connector' = 'upsert-kafka',
            'topic' = 'example-table-topic-out',
            'properties.bootstrap.servers' = '{broker}',
            'key.format' = 'json',
            'value.format' = 'json'
        )
        """
    )

    # Insert query with timestamp conversion and watermarking
    t_env.execute_sql(
        """
        INSERT INTO agg_count
        SELECT
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    'username' VALUE username,
                    'login_count' VALUE login_count
                )
            ) AS aggregated_counts,
            window_start AS window_time
        FROM (
            SELECT
                username,
                COUNT(username) AS login_count,
                window_start,
                window_end
            FROM TABLE(
                TUMBLE(TABLE kafka_source, DESCRIPTOR(event_ts), INTERVAL '30' SECOND)
            )
            GROUP BY
                username,
                window_start,
                window_end
        )
        GROUP BY
            window_start
        ;
        """
    )


if __name__ == "__main__":
    broker = os.getenv("KAFKA_BROKER", "webb:9092")
    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(message)s")

    env_settings = EnvironmentSettings.new_instance().in_streaming_mode().build()

    # Create streaming environment
    env = StreamExecutionEnvironment.get_execution_environment()

    # Set parallelism
    env.set_parallelism(1)

    # Enable checkpointing (optional, but useful for production)
    env.enable_checkpointing(10000)  # Checkpoint every 10 seconds

    # Create table environment
    tbl_env = StreamTableEnvironment.create(
        stream_execution_environment=env, environment_settings=env_settings
    )

    run_example_flink_job(tbl_env, broker)
