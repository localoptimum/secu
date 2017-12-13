#!/bin/bash

VERBOSE=1

# Initialise globals
HITNO=0   #iterated
DELTIME=2 #seconds
THRESHOLD=0.030

# Identify the method to grab photos
FOUNDSOMETHING=0
CAPTURE=""

# First test for streamer
RUNME="which streamer"
DIAG=$($RUNME)
if [[ -z $DIAG ]]
then
    echo 'streamer not found'
else
    echo 'Found streamer'
    FOUNDSOMETHING=1
    CAPTURE="streamer -o"
fi

#preferred is fswebcam, check for that next and override
RUNME="which fswebcam"
DIAG=$($RUNME)
if [[ -z $DIAG ]]
then
    echo 'fswebcam not found'
else
    echo 'Found fswebcam'
    FOUNDSOMETHING=1
    CAPTURE="fswebcam -d /dev/video0 -r 848x480 --jpeg 95"
fi

if [[ $FOUNDSOMETHING -eq 0 ]]
then
    echo "Error: no compatible capture software found.  Exiting."
    exit
fi

# Flush temp files
if [ -e "/tmp/ref1.jpeg" ]
then
   rm /tmp/ref1.jpeg
fi
   
if [ -e "/tmp/ref1n.jpg" ]
then
   rm /tmp/ref1n.jpg
fi

if [ -e "/tmp/ref2n.jpg" ]
then
   rm /tmp/ref2n.jpg
fi

#Don't overwrite existing hit data!
#Get new hit number from existing hits, if necessary
if [ -e $HOME/secu/secuHit0 ]
then
    echo 'secu hit data exists, appending hit numbers'
    LIST=$(ls $HOME/secu/ | sed 's/secuHit//' | sort -n | tail -1)
    HITNO=$((LIST+1))
    echo 'New hit number' $HITNO
fi


echo 'Available devices: '

v4l2-ctl --list-devices

echo 'Setting exposure to mid range then auto'

v4l2-ctl -c exposure_auto=1
v4l2-ctl -c exposure_absolute=300

function captureReferencePicture {
    if [ -e "/tmp/ref1n.jpg" ]
    then
	if [ $VERBOSE -eq 1 ]
	then
	    echo 'Cycling temp files'
	fi
	mv /tmp/ref1n.jpg /tmp/ref2n.jpg
    fi

    #Capture new photo
    $CAPTURE /tmp/ref1.jpeg

    #Normalise new photo
    convert /tmp/ref1.jpeg -auto-level /tmp/ref1n.jpg

    #remove old photo
    if [ -e "/tmp/ref1.jpeg" ]
    then
	rm /tmp/ref1.jpeg
    fi

    if [ $VERBOSE -eq 1 ]
    then
	echo 'Captured'
    fi
}

function performHit {
    FOLDER="$HOME/secu/secuHit$HITNO"

    if [ $VERBOSE -eq 1 ]
    then
	    echo $FOLDER
    fi

    mkdir $FOLDER

    for i in `seq 1 5`;
    do
	FILENAME="$FOLDER/hit$i.jpeg"
	if [ $VERBOSE -eq 1 ]
	then
	    echo $FILENAME
	fi
	$CAPTURE $FILENAME
	sleep 1
    done 
    
    #increment hit number
    ((HITNO++))

    if [ $VERBOSE -eq 1 ]
    then
	echo 'HIT! Metric exceeded threshold:' $METRIC
    fi

}

function main {
    while true; do
    #Take a new photo
    captureReferencePicture

    #If two photos exist
    if [[ -e "/tmp/ref1n.jpg" ]] && [[ -e "/tmp/ref2n.jpg" ]]
    then
	if [ $VERBOSE -eq 1 ]
	then
	    echo 'Two photos exist, comparing...'
	fi
	
	#Compare existing photos - metric goes to stderr so must redirect it
	METRICR=$((compare -metric RMSE /tmp/ref1n.jpg /tmp/ref2n.jpg NULL:) 2>&1)
	METRIC=$(echo $METRICR | sed 's/^.*(//' | sed 's/)//')

	#If big difference, reduce delay to 1 second for 1 minute,
	# use bash numeric calculator to compare both floats
	if (( $(echo "$METRIC > $THRESHOLD" |bc -l) ))
	then
	    # Perform hit
	    performHit
	else
	    if [ $VERBOSE -eq 1 ]
	    then
		echo 'Metric lower than threshold: ' $METRIC
	    fi
	fi
    fi
    sleep $DELTIME
    done
}



# Go to main loop
main
