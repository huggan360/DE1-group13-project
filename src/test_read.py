from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("reddit-test").getOrCreate()

df = spark.read.json("hdfs:///project/reddit/raw")
print(df.columns)
df.printSchema()
df.show(5, truncate=False)

spark.stop()
