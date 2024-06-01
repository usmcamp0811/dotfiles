import pytest
import os
from unittest.mock import MagicMock, patch
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import DataTypes, StreamTableEnvironment, EnvironmentSettings
from pyflink.testing.test_case_utils import PyFlinkTestCase, exec_insert_table
from pyflink.util.java_utils import get_j_env_configuration
from job.job import run_example_flink_job, reverse_text


@pytest.mark.parametrize("message,expected", [
    ("Simple message", ['egassem elpmiS']),
    ("Another test", ['tset rehtonA']),
])
def test_reverse_text(message, expected):
    result = reverse_text(message)
    assert result == expected


if __name__ == '__main__':
    pytest.main()

