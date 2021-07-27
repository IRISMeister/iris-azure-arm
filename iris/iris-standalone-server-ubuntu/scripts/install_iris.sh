#!/bin/bash -e
sudo apt-get update

# ++ edit here for optimal settings ++
WRC_USERNAME=$1
WRC_PASSWORD=$2
kit=IRIS-2021.1.0.215.0-lnxubuntux64
instance=iris
installdir=/usr/irissys
password=sys
globals8k=64
routines=64
locksiz=16777216
gmheap=37568
ssport=51773
webport=52773
kittemp=/tmp/iriskit
# -- edit here for optimal settings --

# download iris binary kit
if [ -n "$WRC_USERNAME" ]; then
    wget -qO /dev/null --keep-session-cookies --save-cookies cookie --post-data="UserName=$WRC_USERNAME&Password=$WRC_PASSWORD" 'https://login.intersystems.com/login/SSO.UI.Login.cls?referrer=https%253A//wrc.intersystems.com/wrc/login.csp' 
    wget --secure-protocol=TLSv1_2 -O $kit.tar.gz --load-cookies cookie "https://wrc.intersystems.com/wrc/WRC.StreamServer.cls?FILE=/wrc/Live/ServerKits/$kit.tar.gz"
    rm -f cookie
fi

# add a user and group for iris
useradd -m $ISC_PACKAGE_MGRUSER --uid 51773 | true
useradd -m $ISC_PACKAGE_IRISUSER --uid 52773 | true

# install iris
mkdir -p $kittemp
chmod og+rx $kittemp

# requird for non-root install
rm -fR $kittemp/$kit | true
tar -xvf $kit.tar.gz -C $kittemp
cp -fR manifest/ $kittemp/$kit
pushd $kittemp/$kit
sudo ISC_PACKAGE_INSTANCENAME=$instance \
ISC_PACKAGE_IRISGROUP=irisusr \
ISC_PACKAGE_IRISUSER=irisusr \
ISC_PACKAGE_MGRGROUP=irisowner \
ISC_PACKAGE_MGRUSER=irisowner \
ISC_PACKAGE_INSTALLDIR=$installdir \
ISC_PACKAGE_UNICODE=Y \
ISC_PACKAGE_INITIAL_SECURITY=Normal \
ISC_PACKAGE_USER_PASSWORD=$password \
ISC_PACKAGE_CSPSYSTEM_PASSWORD=$password \
ISC_PACKAGE_CLIENT_COMPONENTS= \
ISC_PACKAGE_SUPERSERVER_PORT=$ssport \
ISC_PACKAGE_WEBSERVER_PORT=$webport \
ISC_INSTALLER_MANIFEST=$kittemp/$kit/manifest/Installer.cls \
ISC_INSTALLER_LOGFILE=installer_log \
ISC_INSTALLER_LOGLEVEL=3 \
ISC_INSTALLER_PARAMETERS=routines=$routines,locksiz=$locksiz,globals8k=$globals8k,gmheap=$gmheap \
./irisinstall_silent
popd
rm -fR $kittemp

# copy iris.key
if [ -e iris.key ]; then
  cp iris.key $ISC_PACKAGE_INSTALLDIR/mgr/
fi

# Apply config settings and license (if any) 
iris restart $ISC_PACKAGE_INSTANCENAME
