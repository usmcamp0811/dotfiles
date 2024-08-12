import os
from unittest.mock import MagicMock, patch

import pytest
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import DataTypes, EnvironmentSettings, StreamTableEnvironment
from pyflink.testing.test_case_utils import PyFlinkTestCase, exec_insert_table
from pyflink.util.java_utils import get_j_env_configuration

from jobs.stream_job import reverse_text, run_example_flink_job


@pytest.mark.parametrize(
    "message,expected",
    [
        ("Simple message", ["egassem elpmiS"]),
        ("Another test", ["tset rehtonA"]),
    ],
)
def test_reverse_text(message, expected):
    result = reverse_text(message)
    assert result == expected


if __name__ == "__main__":
    pytest.main()
