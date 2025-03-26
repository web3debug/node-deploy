#!/usr/bin/env bash
# shellcheck disable=SC2086

# Exit script on error
set -e

basedir=$(cd $(dirname $0) && pwd)
workspace=${basedir}
source ${workspace}/.env

GENESIS_COMMIT="7c97e5f94f728107de36e6de3f3ac39a9bde2837" # pascal commit
INIT_HOLDER=$PROTECTOR
size=${VALIDATOR_SIZE:-1}
blockInterval=${BLOCK_INTERVAL:-3}
sleepBeforeStart=5

# stop geth client
function exit_previous() {
    ValIdx=$1
    ps -ef | grep geth$ValIdx | grep mine | awk '{print $2}' | xargs -r kill
    sleep ${sleepBeforeStart}
}

function create_validator_keys() {
    rm -rf ${workspace}/.local ${workspace}/keys
    mkdir -p ${workspace}/.local/bsc ${workspace}/keys
    echo "$KEYPASS" >${workspace}/keys/password.txt

    for ((i = 0; i < size; i++)); do
        ${workspace}/bin/geth account new --password ${workspace}/keys/password.txt --datadir ${workspace}/keys/validator${i}
        ${workspace}/bin/geth bls wallet create --blspassword ${workspace}/keys/password.txt --datadir ${workspace}/keys/bls${i}
        ${workspace}/bin/geth bls account new --blspassword ${workspace}/keys/password.txt --datadir ${workspace}/keys/bls${i}
        ${workspace}/bin/bootnode -genkey ${workspace}/keys/nodekey${i}
        cp -r ${workspace}/keys/validator${i} ${workspace}/.local/bsc/
        cp -r ${workspace}/keys/bls${i} ${workspace}/.local/bsc/
    done
}

# reset genesis, but keep edited genesis-template.json
function reset_genesis() {
    if [ ! -f "${workspace}/genesis/genesis-template.json" ]; then
        cd ${workspace} && git submodule update --init --recursive && cd ${workspace}/genesis
        git reset --hard ${GENESIS_COMMIT}
    else
        cd ${workspace}/genesis
        cp genesis-template.json genesis-template.json.bk
        git stash && git stash clear
        if [ -n "$(git status --porcelain | grep -v genesis-template.json.bk)" ]; then
            echo "genesis has been modified" && exit 1
        fi
        cd ${workspace} && git submodule update --remote --recursive && cd ${workspace}/genesis
        git reset --hard ${GENESIS_COMMIT}
        mv genesis-template.json.bk genesis-template.json
    fi

    poetry install --no-root
    npm install
    rm -rf lib/forge-std
    forge install --no-git --no-commit foundry-rs/forge-std@v1.7.3
    cd lib/forge-std/lib
    rm -rf ds-test
    git clone https://github.com/dapphub/ds-test

}

function prepare_config() {
    rm -f ${workspace}/genesis/validators.conf

    initHolders=${INIT_HOLDERS}
    for ((i = 0; i < size; i++)); do
        for f in ${workspace}/.local/bsc/validator${i}/keystore/*; do
            cons_addr="0x$(cat ${f} | jq -r .address)"
            initHolders=${initHolders}","${cons_addr}
            fee_addr=${cons_addr}
        done

        mkdir -p ${workspace}/.local/bsc/node${i}
        cp ${workspace}/keys/password.txt ${workspace}/.local/bsc/node${i}/
        bbcfee_addrs=${fee_addr}
        powers="0x000001d1a94a2000" #2000000000000
        mv ${workspace}/.local/bsc/bls${i}/bls ${workspace}/.local/bsc/node${i}/ && rm -rf ${workspace}/.local/bsc/bls${i}
        vote_addr=0x$(cat ${workspace}/.local/bsc/node${i}/bls/keystore/*json | jq .pubkey | sed 's/"//g')
        echo "${cons_addr},${bbcfee_addrs},${fee_addr},${powers},${vote_addr}" >>${workspace}/genesis/validators.conf
        echo "validator" ${i} ":" ${cons_addr}
        echo "validatorFee" ${i} ":" ${fee_addr}
        echo "validatorVote" ${i} ":" ${vote_addr}
    done

    cd ${workspace}/genesis/
    git checkout HEAD contracts

    sed -i -e '/registeredContractChannelMap\[VALIDATOR_CONTRACT_ADDR\]\[STAKING_CHANNELID\]/d' ${workspace}/genesis/contracts/deprecated/CrossChain.sol
    sed -i -e 's/alreadyInit = true;/turnLength = 4;alreadyInit = true;/' ${workspace}/genesis/contracts/BSCValidatorSet.sol
    sed -i -e 's/public onlyCoinbase onlyZeroGasPrice {/public onlyCoinbase onlyZeroGasPrice {if (block.number < 30) return;/' ${workspace}/genesis/contracts/BSCValidatorSet.sol

    poetry run python -m scripts.generate generate-validators
    poetry run python -m scripts.generate generate-init-holders "${initHolders}" "${INIT_AMOUNT}"
    poetry run python -m scripts.generate dev \
        --dev-chain-id ${CHAIN_ID} \
        --epoch 200 \
        --block-interval ${blockInterval} \
        --stake-hub-protector "${INIT_HOLDER}" \
        --governor-protector "${INIT_HOLDER}" \
        --token-recover-portal-protector "${INIT_HOLDER}"
}

function init_network() {
    cd ${workspace}
    for ((i = 0; i < size; i++)); do
        mkdir ${workspace}/.local/bsc/node${i}/geth
        cp ${workspace}/keys/nodekey${i} ${workspace}/.local/bsc/node${i}/geth/nodekey
    done
    if [ -n "${VALIDATOR_IPS}" ]; then
        VALIDATOR_IPS="--init.ips ${VALIDATOR_IPS}"
    fi
    ${workspace}/bin/geth init-network --init.dir ${workspace}/.local/bsc --init.size=${size} --config ${workspace}/config.toml ${VALIDATOR_IPS} ${workspace}/genesis/genesis.json
    rm -f ${workspace}/*bsc.log*
    for ((i = 0; i < size; i++)); do
        sed -i -e '/"<nil>"/d' ${workspace}/.local/bsc/node${i}/config.toml
        mv ${workspace}/.local/bsc/validator${i}/keystore ${workspace}/.local/bsc/node${i}/ && rm -rf ${workspace}/.local/bsc/validator${i}

        # init genesis
        initLog=${workspace}/.local/bsc/node${i}/init.log
        if [ $i -eq 0 ]; then
            ${workspace}/bin/geth --datadir ${workspace}/.local/bsc/node${i} init --state.scheme hash --db.engine leveldb ${workspace}/genesis/genesis.json >"${initLog}" 2>&1
        #elif [ $i -eq 1 ]; then
        #    ${workspace}/bin/geth --datadir ${workspace}/.local/bsc/node${i} init --state.scheme path --db.engine pebble --multidatabase ${workspace}/genesis/genesis.json >"${initLog}" 2>&1
        else
            ${workspace}/bin/geth --datadir ${workspace}/.local/bsc/node${i} init --state.scheme path --db.engine pebble ${workspace}/genesis/genesis.json >"${initLog}" 2>&1
        fi
        rm -f ${workspace}/.local/bsc/node${i}/*bsc.log*
    done
}

function generate_service_config() {
    ValIdx=$1
    for ((i = 0; i < size; i++)); do
        if [ ! -z $ValIdx ] && [ $i -ne $ValIdx ]; then
            continue
        fi

        for j in ${workspace}/.local/bsc/node${i}/keystore/*; do
            cons_addr="0x$(cat ${j} | jq -r .address)"
        done

        gcmode="full"

        cat >${workspace}/.local/bsc/node${i}/hardwood.service <<EOF
[Unit]
Description=Hard Wood Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/geth --datadir /root/.ethereum --config /root/.ethereum/config.toml --password /root/.ethereum/password.txt --blspassword /root/.ethereum/password.txt --nodekey /root/.ethereum/geth/nodekey --unlock ${cons_addr} --miner.etherbase ${cons_addr} --gcmode ${gcmode} --syncmode full --mine --vote
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF
    done
}

function native_start() {
    ValIdx=$1
    for ((i = 0; i < size; i++)); do
        if [ ! -z $ValIdx ] && [ $i -ne $ValIdx ]; then
            continue
        fi

        for j in ${workspace}/.local/bsc/node${i}/keystore/*; do
            cons_addr="0x$(cat ${j} | jq -r .address)"
        done

        HTTPPort=$((8545 + i * 10))
        WSPort=$((8546 + i * 10))
        MetricsPort=$((6060 + i))

        # geth may be replaced
        rm -f ${workspace}/.local/bsc/node${i}/geth${i}
        cp ${workspace}/bin/geth ${workspace}/.local/bsc/node${i}/geth${i}

        gcmode="archive"
        if [ $i -ne 0 ]; then
            gcmode="full"
        fi

        nohup ${workspace}/.local/bsc/node${i}/geth${i} --config ${workspace}/.local/bsc/node${i}/config.toml \
            --datadir ${workspace}/.local/bsc/node${i} \
            --password ${workspace}/.local/bsc/node${i}/password.txt \
            --blspassword ${workspace}/.local/bsc/node${i}/password.txt \
            --nodekey ${workspace}/.local/bsc/node${i}/geth/nodekey \
            --unlock ${cons_addr} --miner.etherbase ${cons_addr} --allow-insecure-unlock \
            --ws --ws.port ${WSPort} --http.port ${HTTPPort} --metrics.port ${MetricsPort} \
            --gcmode ${gcmode} --syncmode full --mine --vote --monitor.maliciousvote \
            >${workspace}/.local/bsc/node${i}/bsc-node.log 2>&1 &
    done
}

function register_stakehub() {
    echo "sleep 45s to wait feynman enable"
    sleep 45
    cd ${workspace}/create-validator
    for ((i = 0; i < size; i++)); do
        go run main.go \
            --consensus-key-dir ${workspace}/keys/validator${i} \
            --vote-key-dir ${workspace}/keys/bls${i} \
            --password-path ${workspace}/keys/password.txt \
            --amount 20001 \
            --validator-moniker "validatir$i moniker" \
            --validator-identity "validatir$i identity" \
            --validator-website "validatir$i website" \
            --validator-details "validatir$i details" \
            --rpc-url http://localhost:8545
    done
}

CMD=$1
ValidatorIdx=$2
case ${CMD} in
create_keys)
    create_validator_keys
    ;;
create_genesis)
    reset_genesis
    prepare_config
    init_network
    generate_service_config $ValidatorIdx
    ;;
register)
    register_stakehub
    ;;
reset)
    exit_previous
    create_validator_keys
    reset_genesis
    prepare_config
    init_network
    native_start
    register_stakehub
    ;;
stop)
    exit_previous $ValidatorIdx
    ;;
start)
    native_start $ValidatorIdx
    ;;
restart)
    exit_previous $ValidatorIdx
    native_start $ValidatorIdx
    ;;
*)
    echo "Usage: bsc_cluster.sh | reset | stop [vidx]| start [vidx]| restart [vidx]"
    ;;
esac
