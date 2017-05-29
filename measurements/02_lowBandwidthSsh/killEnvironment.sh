#!/bin/bash

onosVmFolder="$HOME/Masterthesis/vm/firstOnosVm"
mnVmFolder="$HOME/Masterthesis/vm/leftVm"
mnVmIp="192.168.33.10"
onosVmIp="192.168.33.20"

# kill mininet
ssh ubuntu@$mnVmIp "sudo killall /usr/bin/python; sudo mn -c"

# kill onos via karaf shell
ssh -p 8101 karaf@$onosVmIp "shutdown -f"

unset mnVmIp onosVmIp

gnome-terminal -x sh -c "cd $mnVmFolder;vagrant halt"
gnome-terminal -x sh -c "cd $onosVmFolder;vagrant halt"
