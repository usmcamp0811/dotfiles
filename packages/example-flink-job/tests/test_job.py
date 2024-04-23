import pytest
from job.job import *

@pytest.mark.parametrize("input_data, expected_output", [
    ([1, 2, 3], [2, 4, 6]),
    ([10, 20, 30], [20, 40, 60]),
    ([0, -1, -2], [0, -2, -4])
])
def test_doubler(input_data, expected_output):
    for test_input, expected in zip(input_data, expected_output):
        result = double_numbers([test_input])
        assert result == expected
