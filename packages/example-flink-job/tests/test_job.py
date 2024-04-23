from job.job import *

def test_hello():
    assert hello() == "hello"

def test_version():
    assert __version__ == "0.1.0"
