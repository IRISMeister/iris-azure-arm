# iris
スタンドアロン構成のデプロイ  
[![Deploy To Azure Standalone](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FIRISMeister%2Firis-azure-arm%2Fmain%2Firis%2Firis-standalone-server-ubuntu%2Fazuredeploy.json)

ミラー構成のデプロイ  
[![Deploy To Azure Mirror](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FIRISMeister%2Firis-azure-arm%2Fmain%2Firis%2Firis-on-ubuntu%2Fazuredeploy.json)  

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FIRISMeister%2Firis-azure-arm%2Fmain%2Firis%2Firis-on-ubuntu%2Fazuredeploy.json)


## パラメータ一覧

| パラメータ名 | 用途 | 備考 |設定例|
| ------------ | ------ | ---- | --- |
|adminUsername|sudo可能なO/Sユーザ名,全VM共通||irismeister|
|adminPasswordOrKey|SSH public key|ssh接続時に使用。StandAloneのみ|ssh-rsa AAA... generated-by-azure|
|adminPassword|パスワード|Mirrorの場合,全VM共通|Passw0rd|
|domainName|Public DNS名|StandAloneのIRIS,MirrorのJumpBox用DNSホスト名|my-iris-123|
|_artifactsLocation|ARMテンプレートのURL|自動設定||
|_artifactsLocationSasToken|同Sas Token|未使用||
|_secretsLocation|プライべートファイルのURL|Azure Blobを想定。Kit,ライセンスキーなど|https://irismeister.blob.core.windows.net/|
|_secretsLocationSasToken|同Sas Token||sp=r&st=2021...|
||||

> Public DNS名はユニークである必要がある

## デプロイ方法
- Azureポータルを使用する場合は、上部のDeploy to Azureリンクを使用してDeploymentを作成。パラメータに値を環境に応じた設定する。
- az cliを使用する場合は、同梱のdeploy.shを使用。
    事前に、下記の要領でパラメータ用のテンプレートを作成し、環境に応じた編集をする。  

    StandAloneの場合
    ```bash
    cd iris-standalone-server-ubuntu
    cp azuredeploy.parameters.template.json azuredeploy.parameters.json
    vi azuredeploy.parameters.json
    ./deploy.sh
    ```
    Mirrorの場合
    ```bash
    cd iris-on-ubuntu
    cp azuredeploy.parameters.template.json azuredeploy.parameters.json
    vi azuredeploy.parameters.json
    ./deploy.sh
    ```

## デプロイ後のアクセス
使用したデプロイ構成によりアクセス方法が異なる。  

### 共通点
IRIS管理ポータルのユーザ名/パスワードはいずれも
```
SuperUser/sys
```

VMホストへのSSH後の、IRISセッションへのログインはO/S認証を使用。
```
irismeister@MyubuntuVM:~$ sudo -u irisowner iris session iris
Node: MyubuntuVM, Instance: IRIS
USER>

```

### StandAloneの場合
IRISサーバ用のVMにパブリックIPがアサインされるため直接接続が可能。  
> ポート22(SSH)及び52773(IRIS管理ポータル用のapache)が公開されるので注意

指定したリソース下に下記が作成される。
|NAME|	TYPE|	LOCATION|
|--|--|--|
|myNSG	|Network security group	|Japan East|
|myPublicIP	|Public IP address	|Japan East|
|MyubuntuVM	|Virtual machine	|Japan East|
|MyubuntuVM_OSDisk	|Disk	|Japan East|
|myVMNic	|Network interface	|Japan East|
|MyVNET	|Virtual network	|Japan East|


- IRIS管理ポータル  
    http://[domainName].japaneast.cloudapp.azure.com:52773/csp/sys/UtilHome.csp
    例)  
    http://my-iris-123.japaneast.cloudapp.azure.com:52773/csp/sys/UtilHome.csp

- SSH
    ```bash
    ssh -i [秘密鍵] [adminUsername]@[domainName].japaneast.cloudapp.azure.com
    例)
    ssh -i my-azure-keypair.pem irismeister@my-iris-123.japaneast.cloudapp.azure.com
    ```

### Mirrorの場合
IRISサーバはプライベートネットワーク上のVMにデプロイされる。
アクセス用にJumpBoxがデプロイされるので、SSHポートフォワーディングを使用してIRISにアクセスする。

指定したリソース下に下記が作成される。
|NAME|	TYPE|	LOCATION|備考|
|--|--|--|--|
|arbiternic	|Network interface|Japan East|Arbiter|
|arbitervm	|Virtual machine|Japan East|Arbiter|
|arbitervm_OsDisk_1_xxx	|Disk|Japan East|Arbiter|
|irisAvailabilitySet	|Availability set|Japan East|arbitervm,msvm0,slvm0|
|jumpboxnic	|Network interface|Japan East||
|jumpboxpublicIp	|Public IP address|Japan East|公開用IP|
|jumpboxvm	|Virtual machine|Japan East||
|jumpboxvm_OsDisk_1_xxx	|Disk|Japan East||
|msnic0	|Network interface|Japan East|プライマリ|
|msvm0	|Virtual machine|Japan East|プライマリ|
|msvm0_disk2_xxx	|Disk|Japan East|プライマリ|
|msvm0_disk3_xxx	|Disk|Japan East|プライマリ|
|msvm0_OSDisk	|Disk|Japan East|プライマリ|
|slnic0	|Network interface|Japan East|バックアップ|
|slvm0	|Virtual machine|Japan East|バックアップ|
|slvm0_disk2_xxx	|Disk|Japan East|バックアップ|
|slvm0_disk3_xxx	|Disk|Japan East|バックアップ|
|slvm0_OSDisk	|Disk|Japan East|バックアップ|
|vnet	|Virtual network|Japan East|バックアップ|

bash端末((Windows上のGit bashなどでも可)を2個開き、下記を実行する。

端末1
```bash
ssh -L 8888:msvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
[adminUsername]@[domainName].japaneast.cloudapp.azure.com
```

端末2
```bash
ssh -L 8889:slvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
[adminUsername]@[domainName].japaneast.cloudapp.azure.com
```

例) 
```bash
ssh -L 8888:msvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
irismeister@my-iris-123.japaneast.cloudapp.azure.com
irismeister@jumpboxvm:~$

ssh -L 8889:slvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
irismeister@my-iris-123.japaneast.cloudapp.azure.com
irismeister@jumpboxvm:~$
```

- IRIS管理ポータル  
プライマリサーバ  
http://localhost:8888/csp/sys/UtilHome.csp  
バックアップサーバ  
http://localhost:8889/csp/sys/UtilHome.csp

- SSH
    プライマリサーバへは端末1から。パスワードは[adminPassword]で指定したもの。
    ```bash
    [adminUsername]@jumpboxvm:~$ ssh [adminUsername]@msvm0

    例)
    irismeister@jumpboxvm:~$ ssh irismeister@msvm0
    irismeister@msvm0:~$
    irismeister@msvm0:~$ iris list

    Configuration 'IRIS'   (default)
            directory:    /usr/irissys
            versionid:    2021.1.0.215.0
            datadir:      /usr/irissys
            conf file:    iris.cpf  (SuperServer port = 51773, WebServer = 52773)
            status:       running, since Wed Aug  4 07:12:45 2021
            mirroring: Member Type = Failover; Status = Primary
            state:        ok
            product:      InterSystems IRIS
    irismeister@msvm0:~$
    ```

    バックアップサーバへは端末2から。パスワードは[adminPassword]で指定したもの。
    ```bash
    [adminUsername]@jumpboxvm:~$ ssh [adminUsername]@slvm0

    例)
    irismeister@jumpboxvm:~$ ssh irismeister@slvm0
    irismeister@slvm0:~$
    irismeister@slvm0:~$ iris list
    ```

## 補足

### Azure Blob(container)
本例ではIRISライセンスキーやキットなどの非公開ファイルは、非公開設定のAzure Blob(container)に格納している。
Generate SASで作成したキー(Signing method:Account key)を_secretsLocationSasTokenに指定する。shell内から下記のようにwgetで取得している。
```
wget "${SECRETURL}blob/iris.key?${SECRETSASTOKEN}" -O iris.key
```

### Fault Domain
日本リージョンには、障害ドメイン(Fault Domain)は2個しかない。  
https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/managed-disks-common-fault-domain-region-list.md


## デバッグ
### ファイルのデプロイ先
デプロイに使用されるファイル群は下記に存在する。stderr,stdout,params.logに実行ログなどが記録されている。  
```bash
irismeister@MyubuntuVM:~$ sudo su -
root@MyubuntuVM:~# cd /var/lib/waagent/custom-script/download/0
root@MyubuntuVM:/var/lib/waagent/custom-script/download/0# ls
IRIS-2021.1.0.215.0-lnxubuntux64.tar.gz  install_iris.sh  iris.service  stderr
Installer.cls                            iris.key         params.log    stdout
root@MyubuntuVM:/var/lib/waagent/custom-script/download/0#
```

### HealthProbe用のエンドポイント
$ az vm list-ip-addresses --resource-group $rg --output table
VirtualMachine    PrivateIPAddresses    PublicIPAddresses
----------------  --------------------  -------------------
arbitervm         10.0.1.4
jumpboxvm         10.0.0.4              52.185.171.9
msvm0             10.0.1.5
slvm0             10.0.1.6

プライマリメンバからの応答
irismeister@arbitervm:~$  echo `curl http://msvm0:52773/csp/bin/mirror_status.cxw -s`
SUCCESS
バックアップメンバからの応答
irismeister@arbitervm:~$  echo `curl http://slvm0:52773/csp/bin/mirror_status.cxw -s`
FAILED

### LB動作確認

templateでInternal LBを構成するとvmから外部接続できなくなる。(aptもwgetもできないため、vmの作成が失敗する)  
https://jpaztech.github.io/blog/network/snat-options-for-azure-vm/
https://docs.microsoft.com/ja-jp/azure/load-balancer/load-balancer-outbound-connections#how-does-default-snat-work

Standard 内部 Load Balancer を使用する場合、SNAT のために一時 IP アドレスは使用されません。 この機能は、既定でセキュリティをサポートします。 この機能により、リソースによって使用されるすべての IP アドレスが構成可能になり、予約できるようになります。 Standard 内部 Load Balancer を使用するときに、インターネットへのアウトバウンド接続を実現するには、次を構成します。
- インスタンス レベルのパブリック IP アドレス
- VNet NAT
- アウトバウンド規則が構成された Standard パブリック ロード バランサーへのバックエンド インスタンス。

> vmデプロイ後に、手動で、msvm0,slvm0をLBのBackend poolsに追加した場合は、なぜかNAT-GW無しでも外部接続できる模様。  
以下のJDBC接続テストは、手動で追加した後に実行。  

JDBCをLBに対して接続する。ミラーのアクティブノードに接続が行われる事の確認に使用する。
```bash
irismeister@jumpboxvm:~$ ssh irismeister@arbitervm
irismeister@arbitervm:~$ sudo su -
root@arbitervm:~# cd /var/lib/waagent/custom-script/download/0
root@arbitervm:/var/lib/waagent/custom-script/download/0# ls
Installer.cls    install_iris.sh              iris.service  stderr  vm-disk-utils-0.1.sh
JDBCSample.java  intersystems-jdbc-3.2.0.jar  params.log    stdout
root@arbitervm:/var/lib/waagent/custom-script/download/0# javac JDBCSample.java
root@arbitervm:/var/lib/waagent/custom-script/download/0# java -cp .:intersystems-jdbc-3.2.0.jar JDBCSample
```

恐らくNAT-GWが要る(AWSと同じ)。  
NAT-GW構成後のpublic ipは、NAT-GWのOutbound IPに一致する。
irismeister@slvm0:~$ curl https://ipinfo.io/ip
23.102.69.138
