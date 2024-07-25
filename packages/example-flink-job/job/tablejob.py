import logging
import os
import sys

from pyflink.table import EnvironmentSettings, TableEnvironment
from pyflink.table.expressions import call, col, lit
from pyflink.table.window import Tumble


def run_example_flink_job(t_env: TableEnvironment, broker: str):
    # Define Kafka source
    t_env.execute_sql(
        f"""
        CREATE TABLE kafka_source (
            username STRING,
            `timestamp` TIMESTAMP(3),
            WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '1' SECOND
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

    # Define Kafka sink
    t_env.execute_sql(
        f"""
        CREATE TABLE kafka_sink (
            username STRING,
            login_count BIGINT
        ) WITH (
            'connector' = 'kafka',
            'topic' = 'example-table-topic-out',
            'properties.bootstrap.servers' = '{broker}',
            'format' = 'json'
        )
        """
    )

    # Read from Kafka source
    source_table = t_env.from_path("kafka_source")

    # Define Tumble Window
    result_table = (
        source_table.window(Tumble.over(lit(1).minutes).on(col("timestamp")).alias("w"))
        .group_by(col("username"), col("w"))
        .select(col("username"), call("COUNT", col("username")).alias("login_count"))
    )

    # Write result to Kafka sink
    table_result = result_table.execute_insert("kafka_sink")
    table_result.wait()
    logging.info(
        f"Job Status: {table_result.get_job_client().get_job_status().result()}"
    )


if __name__ == "__main__":
    broker = os.getenv("KAFKA_BROKER", "localhost:9092")
    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(message)s")
    env_settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    t_env = TableEnvironment.create(env_settings)
    run_example_flink_job(t_env, broker)
