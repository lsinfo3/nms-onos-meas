#!/bin/bash

REP="1"
COUNT="1"
DURATION="120"
TYPE="ORG"
USEUDP=false

while getopts "t:d:hc:r:u" opt; do
  case $opt in
	t)
	  TYPE=$OPTARG
	  if [ "$TYPE" == "ORG" ] || [ "$TYPE" == "MOD" ] || [ "$TYPE" == "NMS" ]
		then
		  echo "Measurement type: $OPTARG" >&2
		else
		  echo "Measurement type not valid!"
		  exit 1
	  fi
	  ;;
    d)
      echo "Measurement duration: $OPTARG seconds" >&2
      DURATION=$OPTARG
      ;;
    c)
      echo "Connection count: $OPTARG" >&2
      COUNT=$OPTARG
      ;;
    r)
      echo "Measurement repetitions: $OPTARG" >&2
      REP=$OPTARG
      ;;
    u)
      echo "Use UDP rather than TCP." >&2
      USEUDP=true
      ;;
    h)
      echo -e "Usage:\nstartMetricsMeasurement.sh [-r REPETITIONS] [-c COUNT] [-d DURATION] [-u] -t {ORG|MOD|NMS}"
      exit 1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done


# create results folder with date and time
leftVmFolder="$HOME/Masterthesis/vm/leftVm"
STARTTIME=$(date +%F_%H-%M-%S)
resultFolder="$leftVmFolder/captures/metrics/${TYPE}_${STARTTIME}"
mkdir $resultFolder


### repeat measurement ###

for run in `seq 1 $REP`; do

echo "--------------Run #${run}--------------" >&2

# monitor traffic with tcpdump to file
# output of switch 2 (first data stream)
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'cd /home/ubuntu/captures/; sudo tcpdump -i s2-eth2 -Z ubuntu -w "$TYPE"_s2-eth2.cap'\""
sleep 1
# output of switch 4 (second data stream)
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'cd /home/ubuntu/captures/; sudo tcpdump -i s4-eth1 -Z ubuntu -w "$TYPE"_s4-eth1.cap'\""
sleep 1
# output of switch 3 (both data streams)
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'cd /home/ubuntu/captures/; sudo tcpdump -i s3-eth3 -Z ubuntu -w "$TYPE"_s3-eth3.cap'\""
sleep 1
# output of switch 1 (both data streams before limitation)
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'cd /home/ubuntu/captures/; sudo tcpdump -i s1-eth3 -Z ubuntu -w "$TYPE"_s1-eth3.cap'\""
sleep 1

# TODO: check if all four cap files exist
# TODO: adapt nms runtime to connection arrival time

if [ "$TYPE" == "NMS" ]; then
  # start network management system
  nmsCommand="bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c '/home/ubuntu/python/measurements/02_lowBandwidthSsh/simpleNms.py -i 10 -r $(($DURATION + $COUNT*0 + 16))"
  if [ "$USEUDP" == true ]; then
	nmsCommand="$nmsCommand -u"
  fi
  gnome-terminal -e "$nmsCommand'\""
fi

sleep 5


# start iperf instances
iperfCommand="./iperfParameter/runIperf.sh -c $COUNT -d $DURATION -b 400 -a 0 -t $TYPE"
if [ "$USEUDP" == true ]; then
	iperfCommand="$iperfCommand -u"
fi
eval $iperfCommand
unset iperfCommand


sleep $DURATION
sleep 12
# kill iperf server on mininet vm in vagrant vm
#gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'sudo killall iperf3'\""
# kill tcpdump in vagrant vm
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'sudo killall tcpdump'\""



### create results ###

# move captures to the new folder
mv $leftVmFolder/captures/*.cap $resultFolder

capFiles=""
legendNames=""
for f in $resultFolder/*.cap; do

  # echo "File: $f"
  fileBaseName=$(basename "$f") # example: ./out.pdf -> out.pdf
  # echo "FileBaseName: $fileBaseName"
  fileName="${fileBaseName%.*}" # example: out.pdf -> out
  # echo "FileName: $fileName"
  #fileFolderName="$resultFolder/$fileName"
  # get the legend name
  legendNamePos=`expr index "$fileName" "_"`
  legendName=${fileName:$legendNamePos:2}
  
  # concatenate capture file and legend names
  if [ -z "$capFiles" ]
    then
	  capFiles="$f"
	else
	  capFiles="${capFiles} $f"
  fi
  
  if [ -z "$legendNames" ]
    then
	  legendNames="$legendName"
	else
	  legendNames="${legendNames} $legendName"
  fi

done

# create and execute R file command
rCommand="$leftVmFolder/python/rScripts/createPlot.sh"
if [ "$USEUDP" == true ]; then
  # use UDP rather than TCP
  rCommand="$rCommand -u"
fi
rCommand="$rCommand -i \"${capFiles}\""
rCommand="$rCommand -n \"${legendNames}\""
rCommand="$rCommand -r $leftVmFolder/python/rScripts/computeMetrics/computeMetrics.r"
rCommand="$rCommand -o $resultFolder/metrics"

eval $rCommand
unset rCommand

# move iperf result and graphs to extra folder with timestamp
dataFolder="${resultFolder}/$(date +%F_%H-%M-%S)"
mkdir $dataFolder
mv $leftVmFolder/captures/*.txt $dataFolder
mv ${resultFolder}/*.pdf $dataFolder

# remove capture files
rm $resultFolder/*.cap

unset fileBaseName fileName fileName2 fileFolderName dataFolder

sleep 10

done

unset resultFolder STARTTIME leftVmFolder
