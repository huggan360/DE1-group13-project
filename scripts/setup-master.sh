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

CLUSTER_KEY_PATH="$HOME/.ssh/id_ed25519_cluster"

append_if_missing() {
  local line="$1"
  local file="$2"
  grep -Fqx "$line" "$file" || echo "$line" >> "$file"
}

echo "==> Setting hostname"
sudo hostnamectl set-hostname "$MASTER_HOST"

echo "==> Writing /etc/hosts"
sudo tee /etc/hosts >/dev/null <<EOF
127.0.0.1 localhost
127.0.1.1 ${MASTER_HOST}

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

cat > "$HADOOP_CONF/workers" <<EOF
${WORKER1_HOST}
${WORKER2_HOST}
${WORKER3_HOST}
EOF

echo "==> Configuring Spark"
SPARK_CONF="$HOME/${SPARK_PACKAGE}/conf"
cp -f "$SPARK_CONF/spark-env.sh.template" "$SPARK_CONF/spark-env.sh"

cat > "$SPARK_CONF/spark-env.sh" <<EOF
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_CONF_DIR=/home/ubuntu/hadoop-${HADOOP_VERSION}/etc/hadoop
export SPARK_MASTER_HOST=${MASTER_HOST}
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_CORES=1
export SPARK_WORKER_MEMORY=2g
export SPARK_DRIVER_MEMORY=1g
EOF

cat > "$SPARK_CONF/workers" <<EOF
${WORKER1_HOST}
${WORKER2_HOST}
${WORKER3_HOST}
EOF

echo "==> Creating cluster SSH key"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ ! -f "${CLUSTER_KEY_PATH}" ]; then
  ssh-keygen -t ed25519 -f "${CLUSTER_KEY_PATH}" -C "group13-cluster" -N ""
fi

cat > "$HOME/.ssh/config" <<EOF
Host group13-worker1
    HostName ${WORKER1_IP}
    User ubuntu
    IdentityFile ${CLUSTER_KEY_PATH}

Host group13-worker2
    HostName ${WORKER2_IP}
    User ubuntu
    IdentityFile ${CLUSTER_KEY_PATH}

Host group13-worker3
    HostName ${WORKER3_IP}
    User ubuntu
    IdentityFile ${CLUSTER_KEY_PATH}
EOF

chmod 600 "$HOME/.ssh/config" "${CLUSTER_KEY_PATH}"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"

MASTER_PUBKEY_CONTENT="$(cat "${CLUSTER_KEY_PATH}.pub")"
grep -Fqx "$MASTER_PUBKEY_CONTENT" "$HOME/.ssh/authorized_keys" || \
  echo "$MASTER_PUBKEY_CONTENT" >> "$HOME/.ssh/authorized_keys"

mkdir -p "$HOME/bin"

cat > "$HOME/bin/start-cluster.sh" <<'EOF'
#!/usr/bin/env bash
set -e
source ~/.bashrc
start-dfs.sh
start-master.sh
start-workers.sh
hdfs dfs -mkdir -p /user/ubuntu || true
hdfs dfs -mkdir -p /project/reddit/raw || true
hdfs dfs -mkdir -p /project/reddit/output || true
jps
hdfs dfsadmin -report
EOF

cat > "$HOME/bin/stop-cluster.sh" <<'EOF'
#!/usr/bin/env bash
set -e
source ~/.bashrc
stop-workers.sh || true
stop-master.sh || true
stop-dfs.sh || true
EOF

cat > "$HOME/bin/format-namenode.sh" <<'EOF'
#!/usr/bin/env bash
set -e
source ~/.bashrc
hdfs namenode -format
EOF

cat > "$HOME/bin/start-jupyter.sh" <<'EOF'
#!/usr/bin/env bash
set -e
jupyter lab --no-browser --ip=0.0.0.0 --port=8888
EOF

chmod +x "$HOME"/bin/*.sh

echo
echo "---- MASTER SETUP DONE ---"
echo
echo "Master public key for workers"
cat "${CLUSTER_KEY_PATH}.pub"
echo

