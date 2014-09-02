#!/bin/bash

untilsuccessful() {
    "$@"
    while [ $? -ne 0 ]
    do
      echo Retrying...
      sleep 1
        "$@"
    done
}

echo "NODE_ENV: ${NODE_ENV}"
if [[ ${NODE_ENV} = 'test' ]]; then
  COMMAND="sudo mount -t tmpfs -o size=200M tmpfs /opt/couchbase/var"
  echo about to $COMMAND
  sudo mount -t tmpfs -o size=200M tmpfs /opt/couchbase/var
fi

cd /opt/couchbase
mkdir -p var/lib/couchbase var/lib/couchbase/config var/lib/couchbase/data \
  var/lib/couchbase/stats var/lib/couchbase/logs var/lib/moxi

chown -R couchbase:couchbase var
/etc/init.d/couchbase-server start

int=`ip route | awk '/^default/ { print $5 }'`
addr=`ip route | egrep "^[0-9].*$int" | awk '{ print $9 }'`

CB_INIT_BUCKET_NAME=${CB_INIT_BUCKET_NAME-"bgch-cb-api"}

CB_INIT_DATA_PATH=${CB_INIT_DATA_PATH-"/opt/couchbase/var/lib/couchbase/data"}
CB_INIT_INDEX_PATH=${CB_INIT_INDEX_PATH-"/opt/couchbase/var/lib/couchbase/data"}
CB_INIT_USERNAME=${CB_INIT_USERNAME-"Administrator"}
CB_INIT_PASSWORD=${CB_INIT_PASSWORD-"password"}
TOTAL_MEM=$(free -m | grep Mem | awk '{ print $2 }')
let RAM_QUOTA=$TOTAL_MEM*80/100
CB_INIT_RAMSIZE=${CB_INIT_RAMSIZE-$RAM_QUOTA}
CB_INIT_BUCKET_SIZE=${CB_INIT_BUCKET_SIZE-"$CB_INIT_RAMSIZE"}
CB_INIT_BUCKET_ENABLEFLUSH=${CB_INIT_BUCKET_ENABLEFLUSH-"0"}
CB_INIT_BUCKET_REPLICA_COUNT=${CB_INIT_BUCKET_REPLICA_COUNT-"0"}

echo "Initialising node"
untilsuccessful /opt/couchbase/bin/couchbase-cli node-init -c 127.0.0.1:8091 \
    --node-init-data-path=$CB_INIT_DATA_PATH \
    --node-init-index-path=$CB_INIT_INDEX_PATH

echo "Initialising cluster"
untilsuccessful /opt/couchbase/bin/couchbase-cli cluster-init -c 127.0.0.1:8091 \
    --cluster-init-username=$CB_INIT_USERNAME \
    --cluster-init-password=$CB_INIT_PASSWORD \
    --cluster-init-ramsize=$CB_INIT_RAMSIZE

echo "Creating bucket ${CB_INIT_BUCKET_NAME}"
untilsuccessful /opt/couchbase/bin/couchbase-cli bucket-create -c 127.0.0.1:8091 \
    --user $CB_INIT_USERNAME \
    --password $CB_INIT_PASSWORD \
    --bucket=$CB_INIT_BUCKET_NAME \
    --bucket-ramsize=$CB_INIT_BUCKET_SIZE \
    --enable-flush=$CB_INIT_BUCKET_ENABLEFLUSH \
    --bucket-replica=${CB_INIT_BUCKET_REPLICA_COUNT}

echo "Couchbase initialisation complete"