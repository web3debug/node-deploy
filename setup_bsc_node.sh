#!/usr/bin/env bash
basedir=$(
    cd $(dirname $0)
    pwd
)
ips=$2
workspace=${basedir}
source ${workspace}/.env
source ${workspace}/utils.sh
size=$((${BSC_CLUSTER_SIZE}))
standalone=true

function create_validator() {
    rm -rf ${workspace}/clusterNetwork

    for ((i = 0; i < ${size}; i++)); do
        mkdir -p ${workspace}/clusterNetwork/validator${i}
        echo "${KEYPASS}" >${workspace}/clusterNetwork/password.txt

        cons_addr=$(${workspace}/bin/geth account new --datadir ${workspace}/clusterNetwork/validator${i} --password ${workspace}/clusterNetwork/password.txt | grep "Public address of the key:" | awk -F"   " '{print $2}')
        fee_addr=$(${workspace}/bin/geth account new --datadir ${workspace}/clusterNetwork/validator${i}_fee --password ${workspace}/clusterNetwork/password.txt | grep "Public address of the key:" | awk -F"   " '{print $2}')
        mkdir -p ${workspace}/clusterNetwork/bls${i}
        expect create_bls_key.exp ${workspace}/clusterNetwork/bls${i} ${KEYPASS}
        vote_addr=0x$(cat ${workspace}/clusterNetwork/bls${i}/bls/keystore/*json | jq .pubkey | sed 's/"//g')
        if [ ${standalone} = true ]; then
            continue
        fi
    done
}

function generate_static_peers() {
    tool=${workspace}/bin/bootnode
    num=$1
    target=$2
    staticPeers=""
    for ((i = 0; i < $num; i++)); do
        if [ $i -eq $target ]; then
            continue
        fi

        file=${workspace}/clusterNetwork/node${i}/geth/nodekey
        if [ ! -f "$file" ]; then
            $tool -genkey $file
        fi
        port=30311
        domain="bsc-node-${i}.bsc.svc.cluster.local"
        if [ ! -z "$staticPeers" ]; then
            staticPeers+=","
        fi
        staticPeers+='"'"enode://$($tool -nodekey $file -writeaddress)@$domain:$port"'"'
    done

    echo $staticPeers
}

function prepare_config() {
    rm -f ${workspace}/genesis/validators.conf

    for ((i = 0; i < ${size}; i++)); do
        for f in ${workspace}/clusterNetwork/validator${i}/keystore/*; do
            cons_addr="0x$(cat ${f} | jq -r .address)"
        done

        for f in ${workspace}/clusterNetwork/validator${i}_fee/keystore/*; do
            fee_addr="0x$(cat ${f} | jq -r .address)"
        done

        mkdir -p ${workspace}/clusterNetwork/node${i}
        bbcfee_addrs=${fee_addr}
        powers="0x000001d1a94a2000"
        mv ${workspace}/clusterNetwork/bls${i}/bls ${workspace}/clusterNetwork/node${i}/ && rm -rf ${workspace}/clusterNetwork/bls${i}
        vote_addr=0x$(cat ${workspace}/clusterNetwork/node${i}/bls/keystore/*json | jq .pubkey | sed 's/"//g')
        echo "${cons_addr},${bbcfee_addrs},${fee_addr},${powers},${vote_addr}" >>${workspace}/genesis/validators.conf
        echo "validator" ${i} ":" ${cons_addr}
        echo "validatorFee" ${i} ":" ${fee_addr}
        echo "validatorVote" ${i} ":" ${vote_addr}
    done

    cd ${workspace}/genesis/
    git checkout HEAD contracts
    python3 scripts/generate.py generate-validators
    python3 scripts/generate.py generate-init-holders ${INIT_HOLDER}
    if [ ${standalone} = false ]; then
        initConsensusStateBytes=$(${workspace}/bin/tool -height 1 -rpc ${nodeurl} -network-type 0)
        python3 scripts/generate.py dev --dev-chain-id ${BSC_CHAIN_ID} --whitelist-1 ${INIT_HOLDER} --init-consensus-bytes ${initConsensusStateBytes} \
            --init-felony-slash-scope "60" \
            --breathe-block-interval "1 minutes" \
            --block-interval "1 seconds" \
            --init-bc-consensus-addresses 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb9226600000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c80000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc"' \
            --init-bc-vote-addresses 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000030b86b3146bdd2200b1dbdb1cea5e40d3451c028cbb4fb03b1826f7f2d82bee76bbd5cd68a74a16a7eceea093fd5826b9200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003087ce273bb9b51fd69e50de7a8d9a99cfb3b1a5c6a7b85f6673d137a5a2ce7df3d6ee4e6d579a142d58b0606c4a7a1c27000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030a33ac14980d85c0d154c5909ebf7a11d455f54beb4d5d0dc1d8b3670b9c4a6b6c450ee3d623ecc48026f09ed1f0b5c1200000000000000000000000000000000"' \
            --asset-protector "0xdF87F0e2B8519Ea2DD4aBd8B639cdD628497eD25" \
            --unbond-period "2 minutes" \
            --downtime-jail-time "2 minutes" \
            --felony-jail-time "3 minutes" \
            --init-voting-delay "1 minutes / BLOCK_INTERVAL" \
            --init-voting-period "2 minutes / BLOCK_INTERVAL" \
            --init-min-period-after-quorum "uint64(1 minutes / BLOCK_INTERVAL)" \
            --governor-protector "0xdF87F0e2B8519Ea2DD4aBd8B639cdD628497eD25" \
            --init-minimal-delay "1 minutes"
    else
        python3 scripts/generate.py dev --dev-chain-id ${BSC_CHAIN_ID} --whitelist-1 ${INIT_HOLDER} \
            --init-felony-slash-scope "60" \
            --breathe-block-interval "1 minutes" \
            --block-interval "1 seconds" \
            --init-bc-consensus-addresses 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb9226600000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c80000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc"' \
            --init-bc-vote-addresses 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000030b86b3146bdd2200b1dbdb1cea5e40d3451c028cbb4fb03b1826f7f2d82bee76bbd5cd68a74a16a7eceea093fd5826b9200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003087ce273bb9b51fd69e50de7a8d9a99cfb3b1a5c6a7b85f6673d137a5a2ce7df3d6ee4e6d579a142d58b0606c4a7a1c27000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030a33ac14980d85c0d154c5909ebf7a11d455f54beb4d5d0dc1d8b3670b9c4a6b6c450ee3d623ecc48026f09ed1f0b5c1200000000000000000000000000000000"' \
            --asset-protector "0xdF87F0e2B8519Ea2DD4aBd8B639cdD628497eD25" \
            --unbond-period "2 minutes" \
            --downtime-jail-time "2 minutes" \
            --felony-jail-time "3 minutes" \
            --init-voting-delay "1 minutes / BLOCK_INTERVAL" \
            --init-voting-period "2 minutes / BLOCK_INTERVAL" \
            --init-min-period-after-quorum "uint64(1 minutes / BLOCK_INTERVAL)" \
            --governor-protector "0xdF87F0e2B8519Ea2DD4aBd8B639cdD628497eD25" \
            --init-minimal-delay "1 minutes"
    fi
}

function initNetwork() {
    cd ${workspace}
    ${workspace}/bin/geth init-network --init.dir ${workspace}/clusterNetwork --init.size=${size} --init.ips ${ips} --config ${workspace}/config.toml ${workspace}/genesis/genesis.json
    rm -rf ${workspace}/*bsc.log*
    for ((i = 0; i < ${size}; i++)); do
        sed -i -e '/"<nil>"/d' ${workspace}/clusterNetwork/node${i}/config.toml

        cp -R ${workspace}/clusterNetwork/validator${i}/keystore ${workspace}/clusterNetwork/node${i}
        for j in ${workspace}/clusterNetwork/validator${i}/keystore/*; do
            cons_addr="0x$(cat ${j} | jq -r .address)"
        done

        cp ${workspace}/bin/geth ${workspace}/clusterNetwork/node${i}/geth${i}
        # init genesis
        ${workspace}/clusterNetwork/node${i}/geth${i} --datadir ${workspace}/clusterNetwork/node${i} init ${workspace}/genesis/genesis.json
    done
}

CMD=$1
case ${CMD} in
generate)
    echo "===== generate configs ===="
    create_validator
    prepare_config
    initNetwork
    echo "===== end ===="
    ;;
native_init)
    echo "===== register ===="
    create_validator
    echo "===== end ===="
    echo "===== generate configs ===="
    prepare_config
    initNetwork
    echo "===== end ===="
    ;;
*)
    echo "Usage: setup_bsc_node.sh | generate | native_init"
    ;;
esac
