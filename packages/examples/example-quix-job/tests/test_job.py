import pytest
from unittest.mock import MagicMock, patch
from pyflink.datastream import StreamExecutionEnvironment
from job.job import run, generic_flat_map, remove_error_messages, keep_error_messages

@pytest.fixture(scope='module')
def flink_env():
    return StreamExecutionEnvironment.get_execution_environment()

@pytest.mark.parametrize("message,expected", [
    ("Simple message", ['{"payload": "Simple message"}']),
    ("ERROR in Flink job: Something went wrong", ['ERROR in Flink job: Something went wrong'])
])
def test_generic_flat_map(message, expected):
    result = generic_flat_map(message)
    print(result, expected)
    assert result == expected

@pytest.mark.parametrize("message,expected", [
    ("ERROR in Flink job: Something went wrong", []),
    ("Valid message", ["Valid message"])
])
def test_remove_error_messages(message, expected):
    result = list(remove_error_messages(message))
    assert result == expected

@pytest.mark.parametrize("message,expected", [
    ("ERROR in Flink job: Something went wrong", ["ERROR in Flink job: Something went wrong"]),
    ("Valid message", [])
])
def test_keep_error_messages(message, expected):
    result = list(keep_error_messages(message))
    assert result == expected

def test_run_flink_job(flink_env, mocker):
    # Mock the Kafka consumer and producer
    mocked_consumer = MagicMock()
    mocked_producer = MagicMock()
    mocker.patch('pyflink.datastream.connectors.FlinkKafkaConsumer', return_value=mocked_consumer)
    mocker.patch('pyflink.datastream.connectors.FlinkKafkaProducer', return_value=mocked_producer)

    # Run the job
    run('test_job', 'input_topic', 'output_topic', 'error_topic', 'user', 'pass', 'server')

    # Assertions can be made here about how the Kafka consumer and producers were called
    mocked_consumer.assert_called()
    mocked_producer.assert_called()
