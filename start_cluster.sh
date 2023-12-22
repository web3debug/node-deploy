#!/bin/bash
rm -rf ./clusterNetwork

declare -A ips2ids
ips2ids["172.22.42.13"]="i-0d2b8632af953d0f6"
ips2ids["172.22.42.94"]="i-001b988ca374e66f1"
ips2ids["172.22.43.86"]="i-0d36ebf557138f8e5"
devnet_ips="172.22.42.13 172.22.42.94 172.23.43.86"
devnet_ips_comma="172.22.42.13,172.22.42.94,172.23.43.86"

ips2ids["172.22.42.120"]="i-061e1e23e2b80d85b"
ips2ids["172.22.42.141"]="i-0fbfabb40b50e18b9"
ips2ids["172.22.42.162"]="i-0379203cb181dc3ba"
ips2ids["172.22.42.215"]="i-0cfd953fa89ca5a0e"
ips2ids["172.22.42.89"]="i-0823c28e250793d60"
ips2ids["172.22.42.96"]="i-0b136df8bba22f3e6"
ips2ids["172.22.43.110"]="i-09236d408f936106f"
ips2ids["172.22.43.194"]="i-0d35183acc4bd775f"
ips2ids["172.22.43.240"]="i-00ca2a5280cde3b16"
ips2ids["172.22.43.70"]="i-05f8468b161f86547"
ips2ids["172.22.43.85"]="i-098b02cc8635a7b19"
staking_ips="172.22.42.120 172.22.42.141 172.22.42.162 172.22.42.215 172.22.42.89 172.22.42.96 172.22.43.110 172.22.43.194 172.22.43.240 172.22.43.70 172.22.43.85"
staking_ips_comma="172.22.42.120,172.22.42.141,172.22.42.162,172.22.42.215,172.22.42.89,172.22.42.96,172.22.43.110,172.22.43.194,172.22.43.240,172.22.43.70,172.22.43.85"

ips2ids["172.22.42.110"]="i-007723e75eb8f1dab"
ips2ids["172.22.42.235"]="i-0f501565decf3b921"
ips2ids["172.22.43.182"]="i-0df4fe5b482cc35e1"
gov_ips="172.22.42.110 172.22.42.235 172.22.43.182"
gov_ips_comma="172.22.42.110,172.22.42.235,172.22.43.182"

component=$1
if [[ "${component}"x == "devnet"x ]]; then
    ips=(${devnet_ips})
    bash +x ./setup_bsc_node.sh native_init "${devnet_ips_comma}"
elif [[ "${component}"x == "staking"x ]]; then
    ips=(${staking_ips})
    bash +x ./setup_bsc_node.sh native_init "${staking_ips_comma}"
elif [[ "${component}"x == "gov"x ]]; then
    ips=(${gov_ips})
    bash +x ./setup_bsc_node.sh native_init "${gov_ips_comma}"
else
    echo "no process "
    exit
fi

rm -rf /mnt/efs/bsc-qa/bc-fusion/clusterNetwork
cp -r /server/roshan/node-deploy/clusterNetwork /mnt/efs/bsc-qa/bc-fusion
cp /server/roshan/node-deploy/start_geth.sh /mnt/efs/bsc-qa/bc-fusion/clusterNetwork/.
cp /server/roshan/node-deploy/stop_geth.sh /mnt/efs/bsc-qa/bc-fusion/clusterNetwork/.

for ((i = 0; i < ${#ips[@]}; i++)); do
    dst_id=${ips2ids[${ips[i]}]}
    aws ssm send-command \
        --instance-ids "${dst_id}" \
        --document-name "AWS-RunShellScript" \
        --parameters commands="sudo bash /server/clusterNetwork/stop_geth.sh"
    aws ssm send-command \
        --instance-ids "${dst_id}" \
        --document-name "AWS-RunShellScript" \
        --parameters commands="sudo rm -rf /server/clusterNetwork && sudo cp -r /mnt/efs/bsc-qa/bc-fusion/clusterNetwork /server && sudo chmod +x /server/clusterNetwork/node${i}/geth${i} && sudo bash /server/clusterNetwork/start_geth.sh ${i}"

done
