#!/bin/bash

#############
## Locale. ##
#############
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
sudo locale-gen en_US.UTF-8

#######################################################################################################
## Install ONOS prerequisites (cf. https://wiki.onosproject.org/display/ONOS/Developer+Quick+Start). ##
#######################################################################################################
printf "\n### Updating the Packet Sources ###"
sudo apt-get update
printf "\n### Installing Java8 ###"
sudo apt-get install software-properties-common -y && \
sudo add-apt-repository ppa:webupd8team/java -y && \
sudo apt-get update && \
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get install oracle-java8-installer oracle-java8-set-default -y
printf "\n### Installing zip and python ###"
sudo apt-get install zip -y && \
sudo apt-get install python -y

######################
## Clone ONOS repo. ##
######################
printf "\n### Cloning ONOS Repository ###"
git clone https://github.com/lsinfo3/nms-aware-onos ./nms-aware-onos/ --progress

#######################################################################################
## Build ONOS (cf. https://wiki.onosproject.org/display/ONOS/Developer+Quick+Start). ##
#######################################################################################
cd nms-aware-onos
git checkout networkManagement
printf "\n### Building ONOS with Buck ###"
export ONOS_ROOT=$(pwd)
# Set variable persistently.
echo "export ONOS_ROOT=$(pwd)" >> /home/ubuntu/.bashrc
tools/build/onos-buck build onos --show-output
# Generate IntelliJ project structure.
tools/build/onos-buck project

####################
## Configure ONOS ##
####################
printf "\n### Configuring ONOS ###"
cp buck-out/gen/tools/package/onos-package/onos.tar.gz /opt/
tar -xzf /opt/onos.tar.gz -C /opt/
mv /opt/onos-1.7.2-SNAPSHOT/ /opt/onos/
chown -cR ubuntu /opt/onos/
echo "export ONOS_APPS=drivers,openflow-base,hostprovider,netcfglinksprovider,ifw,proxyarp,mobility" >> /home/ubuntu/.bashrc

###########################
## Adding public SSH key ##
###########################
if [ -f /home/ubuntu/.ssh/me.pub ]; then
  cat /home/ubuntu/.ssh/me.pub >> /home/ubuntu/.ssh/authorized_keys
else
  printf "No public SSH key available! No connection via SSH possible without password!\n" 1>&2
fi

