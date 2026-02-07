import maya
import pytest

from random_python_project import __version__, get_time_difference


def test_version():
    assert __version__ == "0.1.0"


def test_same_date():
    date1 = "2024-08-07"
    date2 = "2024-08-07"
    assert get_time_difference(date1, date2) == 0


def test_one_day_difference():
    date1 = "2024-08-06"
    date2 = "2024-08-07"
    assert get_time_difference(date1, date2) == 1


def test_large_difference():
    date1 = "2020-01-01"
    date2 = "2024-08-07"
    expected_days = (maya.when(date2) - maya.when(date1)).days
    assert get_time_difference(date1, date2) == expected_days


def test_reverse_dates():
    date1 = "2024-08-07"
    date2 = "2024-08-06"
    assert get_time_difference(date1, date2) == 1
