#!/usr/bin/env bash

# Exit script on error
set -e


basedir=$(cd $(dirname $0); pwd)
workspace=${basedir}
source ${workspace}/.env

stateScheme="hash"
syncmode="full"
gcmode="archive"
index=0

src=${workspace}/.local/bsc/node0
if [ ! -d "$src" ] ;then
	echo "you must startup validator firstly..."
	exit 1
fi

if [ ! -z "$2" ] ;then
	index=$2
fi

if [ ! -z "$3" ] ;then
	syncmode=$3
fi

if [ ! -z "$4" ] ;then
	gcmode=$4
fi

node=node$index
dst=${workspace}/.local/bsc/$gcmode/${node}
rialtoHash=`cat $src/init.log|grep "database=chaindata"|awk -F"=" '{print $NF}'|awk -F'"' '{print $1}'`

mkdir -pv $dst/

cp $src/config.toml $dst/ && cp $src/genesis.json $dst/
${workspace}/bin/geth init --state.scheme ${stateScheme} --datadir ${dst}/ ${dst}/genesis.json

cat >$dst/hardwood.service <<EOF
[Unit]
Description=Hard Wood Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/geth --datadir /root/.ethereum --config /root/.ethereum/config.toml --nodekey /root/.ethereum/geth/nodekey --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.origins "*" --ws.api "eth,net,web3,network,debug,txpool" --http.addr 0.0.0.0 --http.port 8545 --http.corsdomain "*" --http.api debug,net,eth,shh,web3,txpool --http.vhosts "*" --metrics --metrics.addr localhost --metrics.port 6060 --metrics.expensive --gcmode ${gcmode} --syncmode ${syncmode} --state.scheme ${stateScheme} --mine --vote --monitor.maliciousvote --rialtohash ${rialtoHash} --override.passedforktime 0 --override.pascal 0 --override.prague 0 --override.lorentz 0 --override.immutabilitythreshold ${FullImmutabilityThreshold} --override.breatheblockinterval ${BreatheBlockInterval} --override.minforblobrequest ${MinBlocksForBlobRequests} --override.defaultextrareserve ${DefaultExtraReserveForBlobRequests}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF
