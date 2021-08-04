# iris
[![Deploy To Azure Standalone](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FIRISMeister%2Firis-azure-arm%2Fmain%2Firis%2Firis-standalone-server-ubuntu%2Fazuredeploy.json)  
[![Deploy To Azure Mirror](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FIRISMeister%2Firis-azure-arm%2Fmain%2Firis%2Firis-on-ubuntu%2Fazuredeploy.json)  


## パラメータ一覧

| パラメータ名 | 用途 | 備考 |設定例|
| ------------ | ------ | ---- | --- |
|adminUsername|sudo可能なO/Sユーザ名||irismeister|
|adminPasswordOrKey|SSH public key|ssh接続時に使用。StandAloneのみ|ssh-rsa AAA... generated-by-azure|
|adminPassword|パスワード|Mirrorの場合|Passw0rd|
|dnsNamePrefix|Public DNS名のプリフィックス|StandAloneのIRIS用|my-iris-123|
|_artifactsLocation|ARMテンプレートのURL|自動設定||
|_artifactsLocationSasToken|同Sas Token|未使用||
|_secretsLocation|プライべートファイルのURL|Azure Blobを想定。Kit,ライセンスキーなど|https://irismeister.blob.core.windows.net/|
|_secretsLocationSasToken|同Sas Token||sp=r&st=2021...|
||||

## デプロイ方法
- Azureポータルを使用する場合は、上部のリンクを使用してDeploymentを作成。パラメータに値を環境に応じた設定する。
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
$ sudo -u irisowner iris session iris

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
http://[public ipあるいはドメイン名]:52773/csp/sys/UtilHome.csp

- SSH
    ```bash
    ssh -i [秘密鍵] [adminUsername]@[public ipあるいはドメイン名]
    例)
    ssh -i my-azure-keypair.pem irismeister@my-iris-123.japaneast.cloudapp.azure.com
    ```

### Mirrorの場合
IRISサーバはプライベートネットワーク上のVMにデプロイされる。
アクセス用にJumpBoxがデプロイされるので、SSHポートフォワーディングを使用してIRISにアクセスする。

bash端末を2個開き、下記を実行します。(Windows上のGit bashでも可)

```bash
端末1
ssh -L 8888:msvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null [adminUsername]@iris-[リソースグループ名].japaneast.cloudapp.azure.com
端末2
ssh -L 8889:slvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null [adminUsername]@iris-[リソースグループ名].japaneast.cloudapp.azure.com
例) ただし、リソースグループ名はIRIS-Group
ssh -L 8888:msvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null irismeister@iris-IRIS-Group.japaneast.cloudapp.azure.com
ssh -L 8889:slvm0:52773 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null irismeister@iris-IRIS-Group.japaneast.cloudapp.azure.com
```

- IRIS管理ポータル  
プライマリサーバ  
http://localhost:8888/csp/sys/UtilHome.csp  
バックアップサーバ  
http://localhost:8889/csp/sys/UtilHome.csp

- SSH
    パスワードはadminPasswordで指定したもの。
    ```bash
    端末1から
    ssh irismeister@msvm0
    端末2から
    ssh irismeister@slvm0
    ```

## 補足

### Azure Blob(container)
License, Kit はAzure Blob(container)に格納。
Generate SASで作成したキー(Signing method:Account key)を_secretsLocationSasTokenに指定する。shell内から下記のようにwgetで取得している。
```
wget "${SECRETURL}blob/iris.key?${SECRETSASTOKEN}" -O iris.key
```

### Fault Domain
日本はFault Domainは2個しかない
https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/managed-disks-common-fault-domain-region-list.md


### Debug

cd /var/lib/waagent/custom-script/download/0
root@MyubuntuVM:/var/lib/waagent/custom-script/download/0# ls
IRIS-2021.1.0.215.0-lnxubuntux64.tar.gz  Installer.cls  install_iris.sh  stderr  stdout
