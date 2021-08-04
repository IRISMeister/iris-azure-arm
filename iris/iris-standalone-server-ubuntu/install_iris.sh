#!/bin/bash -e
apt-get -y update

SECRETURL=$1
SECRETSASTOKEN=$2
echo "${SECRETURL}blob/iris.key?${SECRETSASTOKEN}" >> params.log

# ++ edit here for optimal settings ++
kit=IRIS-2021.1.0.215.0-lnxubuntux64
password=sys
ssport=51773
webport=52773
kittemp=/tmp/iriskit
ISC_PACKAGE_INSTALLDIR=/usr/irissys
ISC_PACKAGE_INSTANCENAME=iris
ISC_PACKAGE_MGRUSER=irisowner
ISC_PACKAGE_IRISUSER=irisusr
# -- edit here for optimal settings --

# download iris binary kit
wget "${SECRETURL}blob/${kit}.tar.gz?${SECRETSASTOKEN}" -O $kit.tar.gz

# add a user and group for iris
useradd -m $ISC_PACKAGE_MGRUSER --uid 51773 | true
useradd -m $ISC_PACKAGE_IRISUSER --uid 52773 | true

#; change owner so that IRIS can create folders and database files
chown irisowner:irisusr /datadisks/disk1/

# install iris
mkdir -p $kittemp
chmod og+rx $kittemp

# requird for non-root install
rm -fR $kittemp/$kit | true
tar -xvf $kit.tar.gz -C $kittemp

cp Installer.cls $kittemp/$kit/Installer.cls
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
wget "${SECRETURL}blob/iris.key?${SECRETSASTOKEN}" -O iris.key
if [ -e iris.key ]; then
  cp iris.key $ISC_PACKAGE_INSTALLDIR/mgr/
fi

# create related folders. 
# See https://github.com/IRISMeister/iris-private-cloudformation/blob/master/iris-full.yml for more options
mkdir /iris
mkdir /iris/wij
mkdir /iris/journal1
mkdir /iris/journal2
chown $ISC_PACKAGE_MGRUSER:$ISC_PACKAGE_IRISUSER /iris
chown $ISC_PACKAGE_MGRUSER:$ISC_PACKAGE_IRISUSER /iris/wij
chown $ISC_PACKAGE_MGRUSER:$ISC_PACKAGE_IRISUSER /iris/journal1
chown $ISC_PACKAGE_MGRUSER:$ISC_PACKAGE_IRISUSER /iris/journal2

# any better way?
chmod 777 /iris/journal1
chmod 777 /iris/journal1

cp iris.service /etc/systemd/system/iris.service
chmod 644 /etc/systemd/system/iris.service
sudo systemctl daemon-reload &&
sudo systemctl enable ISCAgent.service &&
sudo systemctl start ISCAgent.service &&
sudo systemctl enable iris &&

USERHOME=/home/$ISC_PACKAGE_MGRUSER
# additional config if any
cat << 'EOS' > $USERHOME/merge.cpf
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
EOS

ISC_CPF_MERGE_FILE=$USERHOME/merge.cpf iris start $ISC_PACKAGE_INSTANCENAME quietly
# ToDo: should I restart by using systemctl?
