## Group 13 Course Project


### What has been done
- Created 4 VMs: 1 master + 3 workers
- Set correct internal hostnames and /etc/hosts
- Set up SSH from master to workers
- Installed Java 11, Hadoop 3.4.1, Spark 3.5.1, Python, Jupyter
- Configured HDFS and fixed NameNode binding issue
- Verified HDFS is healthy with 3 live DataNodes
- Installed and started Spark master/workers
- Created GitHub repo: DE1-group13-project
- 
### Monday
1. Verify cluster:
   jps
   hdfs dfsadmin -report
   start-master.sh
   start-workers.sh

2. Go to repo
   cd ~/DE1-group13-project

3. Download dataset locally on master:
   cd ~/datasets/reddit
   wget -O corpus-webis-tldr-17.zip "https://zenodo.org/records/1043504/files/corpus-webis-tldr-17.zip?download=1"
   unzip corpus-webis-tldr-17.zip

4. Upload dataset to HDFS:
   hdfs dfs -mkdir -p /project/reddit/raw
   hdfs dfs -put -f ~/datasets/reddit/* /project/reddit/raw/

5. Start coding first Spark test:
   src/test_read.py

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
