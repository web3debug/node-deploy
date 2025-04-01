# 部署文档

## 创建服务器

### 创建部署服务（1台）

   * 系统: ubuntu 24.04.1 LTS
   * CPU: 4核8G
   * 系统盘(SSD): 20G

### 创建验证节点服务器（4台）

> 验证人节点也是full node节点，提供给钱包使用

   * 系统: ubuntu 24.04.1 LTS
   * CPU: 2核4G
   * 系统盘(SSD): 20G
   * 数据盘(SSD): 50G，用于存储节点数据，方便扩容，将数据盘挂载到 /root/.ethereum 目录

## 在部署服务器上准备环境

> 注意⚠️：以下操作都是在部署服务器上执行

1. 将验证节点、full node节点的公钥添加到部署服务器的 `~/.ssh/authorized_keys` 文件中，同时在 `~/.ssh/config` 文件中配置服务器 ssh 登陆别名，例如：val-node-1、val-node-2 ...， full-node-1、full-node-2 ...

2. 安装 go

   ```shell
   wget https://go.dev/dl/go1.23.7.linux-amd64.tar.gz
   rm -rf /usr/local/go && tar -C /usr/local -xzf go1.23.7.linux-amd64.tar.gz
   echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
   source ~/.bashrc
   go version # Should print "go version go1.23.7 linux/amd64".
   ```
3. 安装 nodejs

   ```shell
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
   \. "$HOME/.nvm/nvm.sh"
   nvm install 18
   node -v # Should print "v18.20.7".
   nvm current # Should print "v18.20.7".
   npm -v # Should print "10.8.2".
   ```

4. 安装 foundry

   > ⚠️可能需要在 `~/.bashrc` 文件中添加 PATH 配置，注意观察安装输出内容提示

   ```shell
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
5. 安装 pipx

   > ⚠️可能需要在 `~/.bashrc` 文件中添加 PATH 配置，注意观察安装输出内容提示

   ```shell
   sudo apt update
   sudo apt install pipx
   pipx ensurepath
   ```
   
6. 安装 poetry

   > ⚠️可能需要在 `~/.bashrc` 文件中添加 PATH 配置，注意观察安装输出内容提示   

   ```shell
   pipx install poetry
   poetry --version # Should print "Poetry 2.1.1".
   ```

## 编译 geth

   ```shell
   git clone https://github.com/bnb-chain/bsc.git 
   (cd bsc && make all)
   ```

## 部署验证人节点（也是full node节点）

1. 克隆部署仓库

   ```shell
   git clone https://github.com/web3debug/node-deploy.git
   cd node-deploy
   git checkout fork/main
   ```

2. 安装依赖

   ```shell
   pip3 install -r requirements.txt
   ```

3. 将编译的 geth、bootnode 二进制拷贝到当前项目

   ```shell
   cp ../bsc/build/bin/geth ./bin/
   cp ../bsc/build/bin/bootnode ./bin/
   ```

4. 修改 .env 文件

   可修改变量，其他变量请勿修改
   
   * `VALIDATOR_SIZE` 验证节点数量
   * `VALIDATOR_IPS` 验证节点 IP 地址，多个节点用逗号分隔
   * `BLOCK_INTERVAL` 出块间隔
   * `KEYPASS` 验证人私钥密码，验证人私钥将自动生成，并备份在 keys 目录，注意保管好密码和私钥
   * `PROTECTOR` 链管理员地址
   * `INIT_HOLDERS` 初始持币地址，可以配置多个，持币数量在 `INIT_AMOUNT` 中配置
   * `INIT_AMOUNT` 初始持币数量，管理员地址也会分配这个数量的HEC

5. 生成 genesis 文件及节点配置文件

   * 创建验证人 keys，生成的文件在 `keys` 目录下，注意备份保管，同时会拷贝到 `.local` 文件中，之后会被拷贝到对应的验证人节点服务器上
   ```shell
   bash +x ./bsc_cluster.sh create_keys
   ```
   * 生成 genesis 文件
   ```shell
   bash +x ./bsc_cluster.sh create_genesis
   ```

6. 将节点配置文件拷贝到对应的节点服务器上

   ```shell
   scp -r ./.local/bsc/node0 val-node-1:
   scp -r ./.local/bsc/node1 val-node-2:
   scp -r ./.local/bsc/node2 val-node-3:
   scp -r ./.local/bsc/node3 val-node-4:
   ```

7. 启动验证节点

   节点启动使用 systemd 管理，服务器重启后会自动启动节点

   * 启动第一台验证人节点

   ```shell
   ssh val-node-1
   mv /root/node0 /root/.ethereum
   mv /root/.ethereum/geth0 /usr/local/bin/geth
   mv /root/.ethereum/hardwood.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable hardwood
   sudo systemctl start hardwood
   ```
   
   * 启动第二台验证人节点

   ```shell
   ssh val-node-2
   mv /root/node1 /root/.ethereum
   mv /root/.ethereum/geth1 /usr/local/bin/geth
   mv /root/.ethereum/hardwood.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable hardwood
   sudo systemctl start hardwood
   ```

   * 启动第三台验证人节点

   ```shell
   ssh val-node-3
   mv /root/node2 /root/.ethereum
   mv /root/.ethereum/geth2 /usr/local/bin/geth
   mv /root/.ethereum/hardwood.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable hardwood
   sudo systemctl start hardwood
   ```

   * 启动第四台验证人节点

   ```shell
   ssh val-node-4
   mv /root/node3 /root/.ethereum
   mv /root/.ethereum/geth3 /usr/local/bin/geth
   mv /root/.ethereum/hardwood.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable hardwood
   sudo systemctl start hardwood
   ```
   
   * 查看节点运行日志
   
   ```shell
   tail -f /root/.ethereum/bsc.log
   ```

8. 注册验证人信息
   
   下面是一个一个给验证人注册信息，这里可以根据需要修改每一位验证人的委托amount、moniker、identity、website、details信息。
   
   amount 的单位已经成包含了18位的精度，例如：20001表示20001个HEC
   moniker 必须设置
   identity 可以为空
   website 可以为空，建议设置
   details 可以为空，建议设置

   以下操作在部署服务器上执行，需要提前设置 RPC_URL 环境变量，IP 为任意一个验证人节点 IP 地址

   ```shell
   export RPC_URL=<ip>:8545
   ```   

   * 给第一个验证人注册信息
   
   ```shell
   go run ./create-validator/main.go \
     --consensus-key-dir ./keys/validator0 \
     --vote-key-dir ./keys/bls0 \
     --password-path ./keys/password.txt \
     --amount 20001 \
     --validator-moniker "validatir0 moniker" \
     --validator-identity "validatir0 identity" \
     --validator-website "validatir0 website" \
     --validator-details "validatir0 details" \
     --rpc-url ${RPC_URL}
   ```
   
   * 给第二个验证人注册信息
   
   ```shell
   go run ./create-validator/main.go \
     --consensus-key-dir ./keys/validator1 \
     --vote-key-dir ./keys/bls1 \
     --password-path ./keys/password.txt \
     --amount 20001 \
     --validator-moniker "validatir1 moniker" \
     --validator-identity "validatir1 identity" \
     --validator-website "validatir1 website" \
     --validator-details "validatir1 details" \
     --rpc-url ${RPC_URL}
   ```
   
   * 给第三个验证人注册信息
   
   ```shell
   go run ./create-validator/main.go \
     --consensus-key-dir ./keys/validator2 \
     --vote-key-dir ./keys/bls2 \
     --password-path ./keys/password.txt \
     --amount 20001 \
     --validator-moniker "validatir2 moniker" \
     --validator-identity "validatir2 identity" \
     --validator-website "validatir2 website" \
     --validator-details "validatir2 details" \
     --rpc-url ${RPC_URL}
   ```

   * 给第四个验证人注册信息

   ```shell
   go run ./create-validator/main.go \
     --consensus-key-dir ./keys/validator3 \
     --vote-key-dir ./keys/bls3 \
     --password-path ./keys/password.txt \
     --amount 20001 \
     --validator-moniker "validatir3 moniker" \
     --validator-identity "validatir3 identity" \
     --validator-website "validatir3 website" \
     --validator-details "validatir3 details" \
     --rpc-url ${RPC_URL}
   ```   

   * 如果还有更多验证人，将 `--consensus-key-dir` 和 `--vote-key-dir` 修改为对应的目录，然后执行上面的命令

9. 验证人节点创建完成（）

## 部署 archive node 节点

> 待补充。。。

### 创建archive node节点服务器（1台）

> 提供给浏览器使用

* 系统: ubuntu 24.04.1 LTS
* CPU: 8核8G
* 系统盘(SSD): 20G
* 数据盘(SSD): 100G，用于存储节点数据，方便扩容，可以使用好一点的ssd

## 节点维护注意事项

* 定期检查服务器磁盘空间，及时清理日志文件，日志文件保存在 `root/.ethereum/`，不要删除最新（看文件名）的日志文件及`bsc.log`，建议将日志等级调整为 `error` 级别