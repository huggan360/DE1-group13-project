## Group 13 Course Project


### What has been done
- Created 4 VMs: 1 master + 3 workers
- Set correct internal hostnames and /etc/hosts
- Set up SSH from master to workers
- Installed Java 11, Hadoop 3.4.1, Spark 3.5.1, Python, Jupyter
- Configured HDFS
- Verified HDFS
- Installed and started Spark master and workers
- Created GitHub repo ( DE1-group13-project)
- Downloaded the redit dataset
- 


### Monday
1. Upload the dataset to hdfs
   
   source ~/.bashrc 
   - ~/bin/start-cluster.sh

   - hdfs dfs -mkdir -p /project/reddit/raw
   - hdfs dfs -put -f /mnt/data/reddit/* /project/reddit/raw/
   - hdfs dfs -ls /project/reddit/raw
   - hdfs dfs -du -h /project/reddit/raw
   

3. test the cluster
   - spark-submit --master spark://group13-master:7077 src/test_read.py

## Manual
### IMPORTANT PATHS

Repo:
~/DE1-group13-project

Hadoop:
~/hadoop-3.4.1

Spark:
~/spark-3.5.1-bin-hadoop3

Dataset local folder:
~/datasets/reddit

Helper scripts:
~/bin/format-namenode.sh
~/bin/start-cluster.sh
~/bin/stop-cluster.sh
~/bin/start-jupyter.sh

### WHAT THE SCRIPTS DO

format-namenode.sh
- Formats HDFS NameNode
- Run only once on first setup

start-cluster.sh
- Starts HDFS
- Starts Spark master
- Starts Spark workers
- Creates HDFS project folders if missing

stop-cluster.sh
- Stops Spark workers
- Stops Spark master
- Stops HDFS

start-jupyter.sh
- Starts JupyterLab on the master

### USEFUL COMMANDS

Check HDFS:
hdfs dfsadmin -report

Check Java daemons:
jps

List HDFS root:
hdfs dfs -ls /

Start Spark manually:
start-master.sh
start-workers.sh

Stop Spark manually:
stop-workers.sh
stop-master.sh

## Git commands
- git add .
- git commit -m "message"
- git push origin main
  
- git pull origin main
