import argparse
from pyspark.sql import SparkSession


def main(input_file, output_dir):
    # Create a Spark session (cluster details are passed by spark-submit)
    spark = SparkSession.builder.appName("Word Count with Arguments").getOrCreate()

    # Read the text file
    text_file = spark.read.text(input_file)

    # Perform the word count
    word_counts = (
        text_file.rdd.flatMap(lambda line: line.value.split())
        .map(lambda word: (word, 1))
        .reduceByKey(lambda a, b: a + b)
    )

    # Convert to a DataFrame and save the output
    word_counts_df = word_counts.toDF(["word", "count"])
    word_counts_df.write.csv(output_dir)

    # Stop the Spark session
    spark.stop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PySpark Word Count Script")
    parser.add_argument("--input", required=True, help="Input file path in HDFS")
    parser.add_argument("--output", required=True, help="Output directory in HDFS")
    args = parser.parse_args()

    main(args.input, args.output)
