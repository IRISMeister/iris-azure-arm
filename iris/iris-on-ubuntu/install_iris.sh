#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2015 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# Author: Full Scale 180 Inc.

# You must be root to run this script
if [ "${UID}" -ne 0 ];
then
    logger "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

#Format the data disk
bash vm-disk-utils-0.1.sh -s

# TEMP FIX - Re-evaluate and remove when possible
# This is an interim fix for hostname resolution in current VM (If it does not exist add it)
grep -q "${HOSTNAME}" /etc/hosts
if [ $? == 0 ];
then
  echo "${HOSTNAME}found in /etc/hosts"
else
  echo "${HOSTNAME} not found in /etc/hosts"
  # Append it to the hsots file if not there
  echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts
fi

# Get today's date into YYYYMMDD format
now=$(date +"%Y%m%d")

# Get passed in parameters $1, $2, $3, $4, and others...
MASTERIP=""
SUBNETADDRESS=""
NODETYPE=""
REPLICATORPASSWORD=""

#Loop through options passed
while getopts :m:s:t:p:U:P:L:T: optname; do
    logger "Option $optname set with value ${OPTARG}"
  case $optname in
    m)
      MASTERIP=${OPTARG}
      ;;
  	s) #Data storage subnet space
      SUBNETADDRESS=${OPTARG}
      ;;
    t) #Type of node (MASTER/SLAVE)
      NODETYPE=${OPTARG}
      ;;
    p) #Replication Password
      REPLICATORPASSWORD=${OPTARG}
      ;;
    U) #WRC Username
      WRCUSERNAME=${OPTARG}
      ;;
    P) #WRC Password
      WRCPASSWORD=${OPTARG}
      ;;
    L) #secret url
      SECRETURL=${OPTARG}
      ;;
    T) #secret sas token
      SECRETSASTOKEN=${OPTARG}
      ;;
    h)  #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

export PGPASSWORD=$REPLICATORPASSWORD
export WRC_USERNAME=$WRCUSERNAME
export WRC_PASSWORD=$WRCPASSWORD
export SECRETURL=$SECRETURL
export SECRETSASTOKEN=$SECRETSASTOKEN

logger "NOW=$now MASTERIP=$MASTERIP SUBNETADDRESS=$SUBNETADDRESS NODETYPE=$NODETYPE"


install_iris_service() {
	logger "Start installing IRIS..."
	# Re-synchronize the package index files from their sources. An update should always be performed before an upgrade.
	apt-get -y update

	install_iris_server

	logger "Start installing IRIS..."
}

install_iris_server() {
#!/bin/bash -e


if [ "$NODETYPE" == "MASTER" ];
then
  echo "Initializing as PRIMARY mirror member"
  IRIS_COMMAND_INIT_MIRROR="##class(SE.ShardInstaller).CreateMirrorSet(\"${MirrorArbiterIP}\")"
  IRIS_COMMAND_CREATE_DB="##class(SE.ShardInstaller).CreateMirroredDB(\"${MirrorDBName}\")"

fi

if [ "$NODETYPE" == "SLAVE" ];
then
  echo "Initializing as FAILOVER mirror member"
  IRIS_COMMAND_INIT_MIRROR="##class(SE.ShardInstaller).JoinAsFailover(\"${MirrorPrimaryIP}\")"
  IRIS_COMMAND_CREATE_DB="##class(SE.ShardInstaller).CreateMirroredDB(\"${MirrorDBName}\")"
fi

# ++ edit here for optimal settings ++
kit=IRIS-2021.1.0.215.0-lnxubuntux64
password=sys
globals8k=64
routines=64
locksiz=16777216
gmheap=37568
ssport=51773
webport=52773
kittemp=/tmp/iriskit
ISC_PACKAGE_INSTALLDIR=/usr/irissys
ISC_PACKAGE_INSTANCENAME=iris
ISC_PACKAGE_MGRUSER=irisowner
ISC_PACKAGE_IRISUSER=irisusr
# -- edit here for optimal settings --

# download iris binary kit
#if [ -n "$WRC_USERNAME" ]; then
#    wget -qO /dev/null --keep-session-cookies --save-cookies cookie --post-data="UserName=$WRC_USERNAME&Password=$WRC_PASSWORD" 'https://login.intersystems.com/login/SSO.UI.Login.cls?referrer=https%253A//wrc.intersystems.com/wrc/login.csp' 
#    wget --secure-protocol=TLSv1_2 -O $kit.tar.gz --load-cookies cookie "https://wrc.intersystems.com/wrc/WRC.StreamServer.cls?FILE=/wrc/Live/ServerKits/$kit.tar.gz"
#    rm -f cookie
#fi
wget "$SECRETURLblob/$kit.tar.gz?$SECRETSASTOKEN" -O $kit.tar.gz

# add a user and group for iris
useradd -m $ISC_PACKAGE_MGRUSER --uid 51773 | true
useradd -m $ISC_PACKAGE_IRISUSER --uid 52773 | true

# install iris
mkdir -p $kittemp
chmod og+rx $kittemp

# requird for non-root install
rm -fR $kittemp/$kit | true
tar -xvf $kit.tar.gz -C $kittemp

#; this is a here document of Installer.cls
cat << 'EOS' > $kittemp/$kit/Installer.cls
Include %occInclude
Class Silent.Installer
{

XData setup [ XMLNamespace = INSTALLER ]
{
<Manifest>
  <Var Name="Namespace" Value="myapp"/>
  <Var Name="Import" Value="0"/>

<If Condition='(##class(Config.Namespaces).Exists("${Namespace}")=0)'>
  <Log Text="Creating namespace ${Namespace}" Level="0"/>
  <Namespace Name="${Namespace}" Create="yes" Code="${Namespace}" Ensemble="0" Data="${Namespace}">
    <Configuration>
      <Database Name="${Namespace}"
        Dir="${MGRDIR}${Namespace}"
        Create="overwrite"
        Resource="%DB_${Namespace}"
        PublicPermissions="RW"
        MountAtStartup="true"/>
    </Configuration>
  </Namespace>
  <Log Text="End Creating namespace ${Namespace}" Level="0"/>
</If>

<Namespace Name="${Namespace}" Create="no">
  <CSPApplication Url="/csp/${Namespace}" Directory="${CSPDIR}${Namespace}" Resource=""/>
</Namespace>
<Namespace Name="${Namespace}" Create="no">
  <CSPApplication Url="/csp/${Namespace}" Directory="${CSPDIR}${Namespace}" Resource=""/>
</Namespace>
<Namespace Name="%SYS" Create="no">
  <Invoke Class="Silent.Installer" Method="setupExt" CheckStatus="1"/>
</Namespace>

</Manifest>
}

ClassMethod setup(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "setup")
}

ClassMethod setupExt() As %Status
{
  Set tSC='$$$OK
  Try {
    Set tSC=##class(Security.System).Get(,.params)
    $$$ThrowOnError(tSC)
    Set params("AutheEnabled")=$ZHEX("7FF") ; Ebable O/S auth
    Set tSC=##class(Security.System).Modify(,.params)
    $$$ThrowOnError(tSC)
  } Catch(e) {
	  Set tSC=e.AsStatus()
  }
  Return tSC
}

ClassMethod EnableMirroringService() As %Status
{
       do ##class(Security.Services).Get("%Service_Mirror", .p)
       set p("Enabled") = 1
       set sc=##class(Security.Services).Modify("%Service_Mirror", .p)
       quit sc
}

ClassMethod CreateMirrorSet(ArbiterIP As %String) As %Status
{
  set mirrorName="MIRRORSET"
  set hostName=$system.INetInfo.HostNameToAddr($system.INetInfo.LocalHostName())
  set systemName="MIRRORNODE01"
  // Create mirror:
  set mirror("UseSSL") = 0
  if (ArbiterIP'="none") {
    set mirror("ArbiterNode") = ArbiterIP_"|2188"
    set mirror("ECPAddress") = hostName  // Windows on AWS need this
  }
  set sc = ##class(SYS.Mirror).CreateNewMirrorSet(mirrorName, systemName, .mirror)
  write !,"Creating mirror "_mirrorName_"..."
  if 'sc do $system.OBJ.DisplayError(sc)  
  quit sc
}

ClassMethod JoinAsFailover(PrimaryNodeIP As %String) As %Status
{
  set mirrorName="MIRRORSET"
  set hostName=$system.INetInfo.HostNameToAddr($system.INetInfo.LocalHostName())
  set systemName="MIRRORNODE02"
  // Join as failover:
  set mirror("ECPAddress") = hostName  // Windows on AWS need this
  set sc=##class(SYS.Mirror).JoinMirrorAsFailoverMember(mirrorName,systemName,"IRIS",PrimaryNodeIP,,.mirror)
  write !,"Jonining mirror "_mirrorName_"...",!
  if 'sc do $system.OBJ.DisplayError(sc)
  quit sc
}

ClassMethod CreateMirroredDB(dbName As %String, dir As %String = "") As %Status
{
  if (dir="") { set dir="/iris/db/" }
  set mirrorName="MIRRORSET"
  
  write !, "Creating databases and NS ",dbName,"...",!
  
  // Create the directory
  do ##class(%Library.File).CreateDirectoryChain(dir)
  do ##class(%Library.File).CreateNewDir(dir,dbName)
  // Add DB to config
  set Properties("Directory")=dir_dbName
  do ##class(Config.Databases).Create(dbName,.Properties)
  // Set the DB properties
  set Properties("Directory")=dir_dbName
  // wait until mirror is ready on this node
  For i=1:1:10 {
    h 1
    Set mirrorStatus=$LIST($SYSTEM.Mirror.GetMemberStatus(mirrorName))
    if mirrorStatus="Backup" Quit
    if mirrorStatus="Primary" Quit
  }
  if ((mirrorStatus'="Primary")&(mirrorStatus'="Backup")) { 
    write "Mirror failed to be ready: Mirror Status:"_mirrorStatus,!
    quit '$$$OK
  }

  set rc = ##class(SYS.Database).CreateDatabase(dir_dbName,,,,,,dbName,mirrorName)
  if 'rc { 
    write !,"Database creation failed!"
    do $system.OBJ.DisplayError(rc)
    quit rc
  }
  
  // Create namespace for mirrored database
  set ns("Globals")=dbName
  set ns("Routines")=dbName
  do ##class(Config.Namespaces).Create(dbName,.ns)
  set rc = ##class(Config.Namespaces).Exists(dbName,.obj,.status)
  if 'rc {
    write !, "NS creation failed."
    do $system.OBJ.DisplayError(rc)
    quit rc
  }
    
  quit $$$OK
}


}
EOS
chmod 777 $kittemp/$kit/Installer.cls

pushd $kittemp/$kit
sudo ISC_PACKAGE_INSTANCENAME=$ISC_PACKAGE_INSTANCENAME \
ISC_PACKAGE_IRISGROUP=$ISC_PACKAGE_IRISUSER \
ISC_PACKAGE_IRISUSER=$ISC_PACKAGE_IRISUSER \
ISC_PACKAGE_MGRGROUP=$ISC_PACKAGE_MGRUSER \
ISC_PACKAGE_MGRUSER=$ISC_PACKAGE_MGRUSER \
ISC_PACKAGE_INSTALLDIR=$ISC_PACKAGE_INSTALLDIR \
ISC_PACKAGE_UNICODE=Y \
ISC_PACKAGE_INITIAL_SECURITY=Normal \
ISC_PACKAGE_USER_PASSWORD=$password \
ISC_PACKAGE_CSPSYSTEM_PASSWORD=$password \
ISC_PACKAGE_CLIENT_COMPONENTS= \
ISC_PACKAGE_SUPERSERVER_PORT=$ssport \
ISC_PACKAGE_WEBSERVER_PORT=$webport \
ISC_INSTALLER_MANIFEST=$kittemp/$kit/Installer.cls \
ISC_INSTALLER_LOGFILE=installer_log \
ISC_INSTALLER_LOGLEVEL=3 \
./irisinstall_silent
popd
rm -fR $kittemp

# stop iris to apply config settings and license (if any) 
iris stop $ISC_PACKAGE_INSTANCENAME quietly

# copy iris.key from secure location...
wget "$SECRETURLblob/iris.key?$SECRETSASTOKEN" -O iris.key
if [ -e iris.key ]; then
  cp iris.key $ISC_PACKAGE_INSTALLDIR/mgr/
fi

# create related folders. 
# See https://github.com/IRISMeister/iris-private-cloudformation/blob/master/iris-full.yml for more options
mkdir /iris
mkdir /iris/wij
mkdir /iris/journal1
mkdir /iris/journal2
chown $ISC_PACKAGE_MGRUSER:$ISC_PACKAGE_IRISUSER /iris/wij
chown $ISC_PACKAGE_MGRUSER:$ISC_PACKAGE_IRISUSER /iris/journal1
chown $ISC_PACKAGE_MGRUSER:$ISC_PACKAGE_IRISUSER /iris/journal2

cat << 'EOS2' > /etc/systemd/system/iris.service
[Unit]
Description=Intersystem IRIS Service
After=network.target
[Service]
Type=forking
WorkingDirectory=/iris/sys
User=root
ExecStart=/iris/sys/bin/iris start IRIS
ExecStop=/iris/sys/bin/iris stop IRIS quietly
Restart=on-abort
[Install]
WantedBy=default.target
EOS2

chmod 644 /etc/systemd/system/iris.service
sudo systemctl daemon-reload &&
sudo systemctl enable ISCAgent.service &&
sudo systemctl start ISCAgent.service &&
sudo systemctl enable iris &&

USERHOME=/home/$ISC_PACKAGE_MGRUSER
# additional config if any
cat << 'EOS3' > $USERHOME/merge.cpf
[config]
globals=0,0,128,0,0,0
gmheap=75136
locksiz=33554432
routines=128
wijdir=/iris/wij/
wduseasyncio=1
[Journal]
AlternateDirectory=/iris/journal2/
CurrentDirectory=/iris/journal1/
EOS3

# Ocasionally license server fails to recognize it...
# 2 [Utility.Event] LMF Error: License Server replied 'Invalid Key' to startup message. Server is incompatible with this product or key.
# 0 [Generic.Event] LMFMON exited due to halt command executed
ISC_CPF_MERGE_FILE=$USERHOME/merge.cpf iris start $ISC_PACKAGE_INSTANCENAME quietly &&
iris session $ISC_PACKAGE_INSTANCENAME -U\%SYS "##class(SE.ShardInstaller).EnableMirroringService()" &&
sleep 2 &&
echo "\nexecuting $IRIS_COMMAND_INIT_MIRROR" && 
iris session $ISC_PACKAGE_INSTANCENAME -U\%SYS "$IRIS_COMMAND_INIT_MIRROR" &&
# Without restart, FAILOVER member fails to retrieve (mirror) journal file...and retries forever...
if [ "$INSTANCEROLE" == "FAILOVER" ]
then
  sudo iris restart $ISC_PACKAGE_INSTANCENAME quietly
fi
sleep 2 &&
echo "\nexecuting $IRIS_COMMAND_CREATE_DB" && 
iris session $ISC_PACKAGE_INSTANCENAME -U\%SYS "$IRIS_COMMAND_CREATE_DB"

}

setup_datadisks() {

	MOUNTPOINT="/datadisks/disk1"

	# Move database files to the striped disk
	if [ -L /var/lib/postgresql/9.3/main ];
	then
		logger "Symbolic link from /var/lib/postgresql/9.3/main already exists"
		echo "Symbolic link from /var/lib/postgresql/9.3/main already exists"
	else
		logger "Moving  data to the $MOUNTPOINT/main"
		echo "Moving PostgreSQL data to the $MOUNTPOINT/main"
		service postgresql stop
		# mkdir $MOUNTPOINT/main
		mv -f /var/lib/postgresql/9.3/main $MOUNTPOINT

		# Create symbolic link so that configuration files continue to use the default folders
		logger "Create symbolic link from /var/lib/postgresql/9.3/main to $MOUNTPOINT/main"
		ln -s $MOUNTPOINT/main /var/lib/postgresql/9.3/main

        chown postgres:postgres $MOUNTPOINT/main
        chmod 0700 $MOUNTPOINT/main
	fi
}

configure_streaming_replication() {
	# use this entry for mirror setup. Primary and Backup.
	logger "Starting configuring PostgreSQL streaming replication..."

	# Configure the MASTER node
	if [ "$NODETYPE" == "MASTER" ];
	then
		logger "Create user replicator..."
		echo "CREATE USER replicator WITH REPLICATION PASSWORD '$PGPASSWORD';"
		sudo -u postgres psql -c "CREATE USER replicator WITH REPLICATION PASSWORD '$PGPASSWORD';"
	fi

	# Stop service
	service postgresql stop

	# Update configuration files
	cd /etc/postgresql/9.3/main

	if grep -Fxq "# install_postgresql.sh" pg_hba.conf
	then
		logger "Already in pg_hba.conf"
		echo "Already in pg_hba.conf"
	else
		# Allow access from other servers in the same subnet
		echo "" >> pg_hba.conf
		echo "# install_postgresql.sh" >> pg_hba.conf
		echo "host replication replicator $SUBNETADDRESS md5" >> pg_hba.conf
		echo "hostssl replication replicator $SUBNETADDRESS md5" >> pg_hba.conf
		echo "" >> pg_hba.conf

		logger "Updated pg_hba.conf"
		echo "Updated pg_hba.conf"
	fi

	if grep -Fxq "# install_postgresql.sh" postgresql.conf
	then
		logger "Already in postgresql.conf"
		echo "Already in postgresql.conf"
	else
		# Change configuration including both master and slave configuration settings
		echo "" >> postgresql.conf
		echo "# install_postgresql.sh" >> postgresql.conf
		echo "listen_addresses = '*'" >> postgresql.conf
		echo "wal_level = hot_standby" >> postgresql.conf
		echo "max_wal_senders = 10" >> postgresql.conf
		echo "wal_keep_segments = 500" >> postgresql.conf
		echo "archive_mode = on" >> postgresql.conf
		echo "archive_command = 'cd .'" >> postgresql.conf
		echo "hot_standby = on" >> postgresql.conf
		echo "" >> postgresql.conf

		logger "Updated postgresql.conf"
		echo "Updated postgresql.conf"
	fi

	# Synchronize the slave
	if [ "$NODETYPE" == "SLAVE" ];
	then
		# Remove all files from the slave data directory
		logger "Remove all files from the slave data directory"
		sudo -u postgres rm -rf /datadisks/disk1/main

		# Make a binary copy of the database cluster files while making sure the system is put in and out of backup mode automatically
		logger "Make binary copy of the data directory from master"
		sudo PGPASSWORD=$PGPASSWORD -u postgres pg_basebackup -h $MASTERIP -D /datadisks/disk1/main -U replicator

		# Create recovery file
		logger "Create recovery.conf file"
		cd /var/lib/postgresql/9.3/main/

		sudo -u postgres echo "standby_mode = 'on'" > recovery.conf
		sudo -u postgres echo "primary_conninfo = 'host=$MASTERIP port=5432 user=replicator password=$PGPASSWORD'" >> recovery.conf
		sudo -u postgres echo "trigger_file = '/var/lib/postgresql/9.3/main/failover'" >> recovery.conf
	fi

	logger "Done configuring PostgreSQL streaming replication"
}

# MAIN ROUTINE
install_iris_service

#setup_datadisks

#service postgresql start
#iris start iris quietly

#configure_streaming_replication

#service postgresql start
#iris start iris quietly

