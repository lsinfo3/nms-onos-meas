#!/bin/bash

DURATION="120"
TYPE="ORG"
USEUDP=false

while getopts "t:d:hu" opt; do
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
    u)
      echo "Use UDP rather than TCP." >&2
      USEUDP=true
      ;;
    h)
      echo -e "Usage:\nstartMeasurement.sh [-d DURATION] [-u] -t {ORG|MOD|NMS}"
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

if [ "$TYPE" == "NMS" ]; then
  # start network management system
  nmsCommand="bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c '/home/ubuntu/python/measurements/02_lowBandwidthSsh/simpleNms.py -i 10 -r $(($DURATION + 100))"
  if [ "$USEUDP" == true ]; then
	nmsCommand="$nmsCommand -u"
  fi
  gnome-terminal -e "$nmsCommand'\""
fi

sleep 5

# start iperf bandwidth test
iperfCommand="bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c '/home/ubuntu/python/measurements/02_lowBandwidthSsh/testOverSsh.py -d $DURATION -c 4 -b 200"
if [ "$USEUDP" == true ]; then
  # use UDP rather than TCP
  iperfCommand="$iperfCommand -u"
fi
if [ "$TYPE" == "NMS" ]; then
  # add constraints if NMS is used
  iperfCommand="$iperfCommand -a"
fi
gnome-terminal -e "$iperfCommand -p 5001 -n iperf1 -r /home/ubuntu/iperfResult1.txt'\""
sleep 40
gnome-terminal -e "$iperfCommand -p 5002 -n iperf2 -r /home/ubuntu/iperfResult2.txt'\""
sleep 40
gnome-terminal -e "$iperfCommand -p 5003 -n iperf3 -r /home/ubuntu/iperfResult3.txt'\""
unset iperfCommand

sleep $DURATION
sleep 10
# kill iperf server on mininet vm in vagrant vm
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'sudo killall iperf3'\""
# kill tcpdump in vagrant vm
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'sudo killall tcpdump'\""
# kill nms?

# copy iperf output to measurement folder
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'cd /home/ubuntu/; cp ./iperfResult1.txt ./captures/iperfResult1.txt'\""
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'cd /home/ubuntu/; cp ./iperfResult2.txt ./captures/iperfResult2.txt'\""
gnome-terminal -e "bash -c \"cd $HOME/Masterthesis/vm/leftVm/; vagrant ssh -c 'cd /home/ubuntu/; cp ./iperfResult3.txt ./captures/iperfResult3.txt'\""



### create results
leftVmFolder="$HOME/Masterthesis/vm/leftVm"
folderName="$leftVmFolder/captures/${TYPE}_$(date +%F_%H-%M-%S)"
# create new folder with date and time
mkdir $folderName
# move capture to the new folder
mv $leftVmFolder/captures/*.cap $folderName

# generate folder and compute graphs for each cap file
for f in $folderName/*.cap; do
	
	# echo "File: $f"
	fileBaseName=$(basename "$f") # example: ./out.pdf -> out.pdf
	# echo "FileBaseName: $fileBaseName"
	fileName="${fileBaseName%.*}" # example: out.pdf -> out
	# echo "FileName: $fileName"
	fileFolderName="$folderName/$fileName"
	# get the legend name
	legendNamePos=`expr index "$fileName" "_"`
	legendName=${fileName:$legendNamePos:2}
  
  # create plot command
	rCommand="$leftVmFolder/python/rScripts/createPlot.sh"
	if [ "$USEUDP" == true ]; then
		# use UDP rather than TCP
		rCommand="$rCommand -u"
  fi
	
	# create combined plots
	for file2 in $folderName/*.cap; do
		if ( [[ $f == *'s1-eth3'* ]] && [[ $file2 == *'s3-eth3'* ]] ) || ( [[ $f == *'s2-eth2'* ]] && [[ $file2 == *'s4-eth1'* ]] ); then
		
			# get file name
			fileName2=$(basename "$file2")
			fileName2="${fileName2%.*}"
			# get the legend name
			legendNamePos=`expr index "$fileName2" "_"`
			legendName2=${fileName2:$legendNamePos:2}

			rCommandTwoFiles="$rCommand -i \"$f $file2\""
			rCommandTwoFiles="$rCommandTwoFiles -n \"$legendName $legendName2\""
			
			# run R script - diff plot one
			rCommandEval="$rCommandTwoFiles -r $leftVmFolder/python/rScripts/Bandwidth_allClients_diffPlot_one/bandwidth_allClients_diffPlot_one.r"
			rCommandEval="$rCommandEval -o $folderName/${fileName}_${fileName2}_separate_one"
			eval $rCommandEval
			# run R script - diff plot three
			rCommandEval="$rCommandTwoFiles -r $leftVmFolder/python/rScripts/Bandwidth_allClients_diffPlot_three/bandwidth_allClients_diffPlot_three.r"
			rCommandEval="$rCommandEval -o $folderName/${fileName}_${fileName2}_separate_three"
			eval $rCommandEval
			# run R scripts - one plot
			rCommandEval="$rCommandTwoFiles -r $leftVmFolder/python/rScripts/Bandwidth_allClients_onePlot/bandwidth_allClients_onePlot.r"
			rCommandEval="$rCommandEval -o $folderName/${fileName}_${fileName2}_combined"
			eval $rCommandEval
      unset rCommandTwoFiles rCommandEval

		fi
	done
	
	# move files to own folder
	mkdir $fileFolderName
	mv $f $fileFolderName
  
  rCommand="$rCommand -i \"$fileFolderName/$fileBaseName\""
  rCommand="$rCommand -n \"$legendName\""
	
	# run R scripts
  rCommandEval="$rCommand -r $leftVmFolder/python/rScripts/Bandwidth_allClients_onePlot/bandwidth_allClients_onePlot.r"
  rCommandEval="$rCommandEval -o $fileFolderName/${fileName}-combined"
  eval $rCommandEval
  rCommandEval="$rCommand -r $leftVmFolder/python/rScripts/Bandwidth_allClients_diffPlot_one/bandwidth_allClients_diffPlot_one.r"
  rCommandEval="$rCommandEval -o $fileFolderName/${fileName}_separate_one"
  eval $rCommandEval
  rCommandEval="$rCommand -r $leftVmFolder/python/rScripts/Bandwidth_allClients_diffPlot_three/bandwidth_allClients_diffPlot_three.r"
  rCommandEval="$rCommandEval -o $fileFolderName/${fileName}_separate_three"
  eval $rCommandEval
  unset rCommand rCommandEval
  
done

# remove csv files
for csvFile in ./*.csv; do
  mv $csvFile ${csvFile}.old
done

# move iperf result to the new folder
mv $leftVmFolder/captures/*.txt $folderName

unset leftVmFolder folderName fileBaseName fileName fileName2 fileFolderName
