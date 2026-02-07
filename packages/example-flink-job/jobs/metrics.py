import time
from pyflink.datastream import MapFunction, RuntimeContext
from pyflink.table.udf import ScalarFunction

class MyExampleMapFunction(MapFunction):
    
    def open(self, runtime_context: RuntimeContext):
        # Get the name of the map class being used
        self.name = self.__class__.__name__
        
        # Setup the baseline metrics
        metric_group = runtime_context.get_metrics_group()
        self.consumed_count = metric_group.counter("{self.name}_consumed_count")
        self.published_count = metric_group.counter("{self.name}_published_count")
        self.error_count = metric_group.counter("{self.name}_error_count")
        self.latency_value = 0
        self.latency_gauge = metric_group.gauge("{self.name}_error_count", lambda: self.latency_value)

        # Run any custom open code
        self.example_open(runtime_context)

    def map(self, value):
        
        try:
            # Set the start time for latency calculation
            start_time = time.time()

            # Pre-processing logic before the core mapping logic
            preprocess_value = self.preprocess(value)
    
            # Core mapping logic (could be overridden in a further subclass if needed)
            result = self.example_map(preprocess_value)
            self.custom_metrics(preprocess_value)
    
            # Post-processing logic after the core mapping logic
            postprocess_result = self.postprocess(result)
            
            # Update the latency gauge
            self.latency_value = time.time() - start_time
    
            return postprocess_result
        
        except Exception as e:
            error_message = f"An error occurred in map {self.name} with input {value}: {str(e)}"
            self.error_count.inc(1)
            return error_message
            
    def preprocess(self, value):
        # Pre-processing logic
        self.consumed_count.inc(1)
        return value

    def postprocess(self, result):
        # Post-processing logic
        self.published_count.inc(1)
        return result

    def example_map(self, value):
        return value

    def example_open(self, runtime_context):
        pass

    def custom_metrics(self, value):
        pass


