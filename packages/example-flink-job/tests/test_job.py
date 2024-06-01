import pytest
from unittest.mock import MagicMock, patch
from pyflink.datastream import StreamExecutionEnvironment
from job.job import run, reverse_text

@pytest.fixture(scope='module')
def flink_env():
    return StreamExecutionEnvironment.get_execution_environment()

@pytest.mark.parametrize("message,expected", [
    ("Simple message", ['egassem elpmiS']),
    ("Another test", ['tset rehtonA']),
])
def test_reverse_text(message, expected):
    result = reverse_text(message)
    assert result == expected

def test_run_flink_job(flink_env):
    # Mock the Kafka consumer and producer
    with patch('pyflink.datastream.connectors.kafka.FlinkKafkaConsumer') as MockConsumer, \
         patch('pyflink.datastream.connectors.kafka.FlinkKafkaProducer') as MockProducer:
        
        mocked_consumer = MockConsumer.return_value
        mocked_producer = MockProducer.return_value

        # Mock the environment and the execution
        with patch('pyflink.datastream.StreamExecutionEnvironment.add_source', return_value=MagicMock()) as mock_add_source, \
             patch('pyflink.datastream.DataStream.flat_map', return_value=MagicMock()) as mock_flat_map, \
             patch('pyflink.datastream.DataStream.add_sink') as mock_add_sink, \
             patch('pyflink.datastream.StreamExecutionEnvironment.execute') as mock_execute:

            # Run the job
            run(flink_env)

            # Assertions can be made here about how the Kafka consumer and producers were called
            mock_add_source.assert_called_with(mocked_consumer)
            mock_flat_map.assert_called()
            mock_add_sink.assert_called_with(mocked_producer)
            mock_execute.assert_called_once_with("Read and Write to Kafka")

def test_kafka_consumer_configuration(flink_env):
    with patch('pyflink.datastream.connectors.kafka.FlinkKafkaConsumer') as MockConsumer:
        mocked_consumer = MockConsumer.return_value
        
        # Run the job
        run(flink_env)
        
        # Check that the Kafka consumer was created with the correct topic and properties
        MockConsumer.assert_called_with(
            topics='example-input-topic',
            deserialization_schema=MagicMock(),  # SimpleStringSchema instance
            properties={'bootstrap.servers': 'test_broker', 'group.id': 'test_group_1'}
        )

def test_kafka_producer_configuration(flink_env):
    with patch('pyflink.datastream.connectors.kafka.FlinkKafkaProducer') as MockProducer:
        mocked_producer = MockProducer.return_value
        
        # Run the job
        run(flink_env)
        
        # Check that the Kafka producer was created with the correct topic and properties
        MockProducer.assert_called_with(
            topic='example-output-topic',
            serialization_schema=MagicMock(),  # SimpleStringSchema instance
            producer_config={'bootstrap.servers': 'test_broker'}
        )

if __name__ == '__main__':
    pytest.main()
