from pyflink.common import ExecutionConfig, Types
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.functions import FlatMapFunction, Collector

class Doubler(FlatMapFunction):
    def flat_map(self, value, collector: Collector):
        collector.collect(value * 2)

def create_env():
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(1)
    return env

def double_numbers(data):
    env = create_env()
    doubles = env.from_collection(data, type_info=Types.INT()).flat_map(Doubler())
    result = doubles.execute_and_collect().next()
    return result

if __name__ == "__main__":
    env = create_env()
    data_stream = env.from_collection([1, 2, 3, 4], type_info=Types.INT())
    data_stream = data_stream.flat_map(Doubler())
    data_stream.print()
    env.execute("Double numbers job")
