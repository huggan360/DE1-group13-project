#!/usr/bin/env bash
set -euo pipefail

HADOOP_VERSION="3.4.1"
SPARK_VERSION="3.5.1"
SPARK_PACKAGE="spark-${SPARK_VERSION}-bin-hadoop3"

MASTER_HOST="group13-master"
MASTER_IP="192.168.2.46"
WORKER1_HOST="group13-worker1"
WORKER1_IP="192.168.2.249"
WORKER2_HOST="group13-worker2"
WORKER2_IP="192.168.2.132"
WORKER3_HOST="group13-worker3"
WORKER3_IP="192.168.2.75"

append_if_missing() {
  local line="$1"
  local file="$2"
  grep -Fqx "$line" "$file" || echo "$line" >> "$file"
}


echo "1) worker1"
echo "2) worker2"
echo "3) worker3"
read -rp "Choose worker " choice

case "$choice" in
  1) HOSTNAME_TARGET="$WORKER1_HOST" ;;
  2) HOSTNAME_TARGET="$WORKER2_HOST" ;;
  3) HOSTNAME_TARGET="$WORKER3_HOST" ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

echo "==> Setting hostname"
sudo hostnamectl set-hostname "$HOSTNAME_TARGET"

echo "==> Writing /etc/hosts"
sudo tee /etc/hosts >/dev/null <<EOF
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME_TARGET}

${MASTER_IP} ${MASTER_HOST}
${WORKER1_IP} ${WORKER1_HOST}
${WORKER2_IP} ${WORKER2_HOST}
${WORKER3_IP} ${WORKER3_HOST}

::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

echo "==> Installing packages"
sudo apt update
sudo apt install -y \
  openjdk-11-jdk-headless \
  python3 python3-pip python3-venv \
  git curl wget rsync net-tools unzip tar nano

python3 -m pip install --upgrade pip
python3 -m pip install jupyterlab notebook pyspark pandas matplotlib findspark

echo "==> Setting shell environment"
append_if_missing 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' "$HOME/.bashrc"
append_if_missing 'export PATH=$JAVA_HOME/bin:$PATH' "$HOME/.bashrc"
append_if_missing "export HADOOP_HOME=\$HOME/hadoop-${HADOOP_VERSION}" "$HOME/.bashrc"
append_if_missing 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' "$HOME/.bashrc"
append_if_missing 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' "$HOME/.bashrc"
append_if_missing "export SPARK_HOME=\$HOME/${SPARK_PACKAGE}" "$HOME/.bashrc"
append_if_missing 'export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin' "$HOME/.bashrc"
append_if_missing 'export PYSPARK_PYTHON=python3' "$HOME/.bashrc"
source "$HOME/.bashrc" || true

echo "==> Installing Hadoop"
if [ ! -d "$HOME/hadoop-${HADOOP_VERSION}" ]; then
  cd "$HOME"
  wget -q "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
  tar -xzf "hadoop-${HADOOP_VERSION}.tar.gz"
  rm -f "hadoop-${HADOOP_VERSION}.tar.gz"
fi

echo "==> Installing Spark"
if [ ! -d "$HOME/${SPARK_PACKAGE}" ]; then
  cd "$HOME"
  wget -q "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz"
  tar -xzf "${SPARK_PACKAGE}.tgz"
  rm -f "${SPARK_PACKAGE}.tgz"
fi

echo "==> Configuring Hadoop"
HADOOP_CONF="$HOME/hadoop-${HADOOP_VERSION}/etc/hadoop"
grep -q 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' "$HADOOP_CONF/hadoop-env.sh" || \
  echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> "$HADOOP_CONF/hadoop-env.sh"

mkdir -p "$HOME/hdfs/namenode" "$HOME/hdfs/datanode"

cat > "$HADOOP_CONF/core-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://${MASTER_HOST}:9000</value>
  </property>
</configuration>
EOF

cat > "$HADOOP_CONF/hdfs-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>2</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///home/ubuntu/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///home/ubuntu/hdfs/datanode</value>
  </property>
</configuration>
EOF

echo "==> Configuring Spark"
SPARK_CONF="$HOME/${SPARK_PACKAGE}/conf"
cp -f "$SPARK_CONF/spark-env.sh.template" "$SPARK_CONF/spark-env.sh"

cat > "$SPARK_CONF/spark-env.sh" <<EOF
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_CONF_DIR=/home/ubuntu/hadoop-${HADOOP_VERSION}/etc/hadoop
export SPARK_MASTER_HOST=${MASTER_HOST}
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=2g
export SPARK_DRIVER_MEMORY=1g
EOF

echo "Paste the master public key "
read -r MASTER_PUBKEY_CONTENT

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"

grep -Fqx "$MASTER_PUBKEY_CONTENT" "$HOME/.ssh/authorized_keys" || \
  echo "$MASTER_PUBKEY_CONTENT" >> "$HOME/.ssh/authorized_keys"

echo
echo "WORKER SETUP DONE: ${HOSTNAME_TARGET}"


