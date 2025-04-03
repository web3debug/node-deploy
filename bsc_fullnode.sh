#!/usr/bin/env bash

# Exit script on error
set -e


basedir=$(cd $(dirname $0); pwd)
workspace=${basedir}
source ${workspace}/.env

stateScheme="hash"
syncmode="full"
gcmode="full"
index=0

src=${workspace}/.local/bsc/node0
if [ ! -d "$src" ] ;then
	echo "you must startup validator firstly..."
	exit 1
fi

if [ ! -z "$1" ] ;then
	index=$1
fi

if [ ! -z "$2" ] ;then
	gcmode=$2
fi

if [ ! -z "$3" ] ;then
	syncmode=$3
fi

dst=${workspace}/.local/bsc/$gcmode/node$index

mkdir -pv $dst/

cp $src/config.toml $dst/ && cp $src/genesis.json $dst/
cp ${workspace}/bin/geth $dst/geth$index
${workspace}/bin/geth init --state.scheme ${stateScheme} --datadir ${dst}/ ${dst}/genesis.json

cat >$dst/hardwood.service <<EOF
[Unit]
Description=Hard Wood Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/geth --datadir /root/.ethereum --config /root/.ethereum/config.toml --nodekey /root/.ethereum/geth/nodekey --gcmode ${gcmode} --syncmode ${syncmode}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF
