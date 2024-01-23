#!/bin/bash

declare -A ips2ids
ips2ids["172.22.42.13"]="i-0d2b8632af953d0f6"
ips2ids["172.22.42.94"]="i-001b988ca374e66f1"
ips2ids["172.22.43.86"]="i-0d36ebf557138f8e5"
devnet_ips="172.22.42.13 172.22.42.94 172.23.43.86"

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

ips2ids["172.22.42.110"]="i-007723e75eb8f1dab"
ips2ids["172.22.42.235"]="i-0f501565decf3b921"
ips2ids["172.22.43.182"]="i-0df4fe5b482cc35e1"
gov_ips="172.22.42.110 172.22.42.235 172.22.43.182"

component=$1
if [[ "${component}"x == "devnet"x ]]; then
    ips=(${devnet_ips})
elif [[ "${component}"x == "staking"x ]]; then
    ips=(${staking_ips})
elif [[ "${component}"x == "gov"x ]]; then
    ips=(${gov_ips})
else
    echo "no process "
    exit
fi

for ((i = 0; i < ${#ips[@]}; i++)); do
    dst_id=${ips2ids[${ips[i]}]}
    aws ssm send-command \
        --instance-ids "${dst_id}" \
        --document-name "AWS-RunShellScript" \
        --parameters commands="sudo bash /server/clusterNetwork/stop_geth.sh"
done
