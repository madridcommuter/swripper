#!/bin/bash

# Verify if torsocks and wget are installed
if ! command -v torsocks &> /dev/null
then
    echo "torsocks is not installed. SWRipper needs it to run."
    exit -1
fi

if ! command -v wget &> /dev/null
then
    echo "wget is not installed. SWRipper needs it to run."
    exit -1
fi

source swripper.conf

# If there are one or more arguments, the first argument is taken
# as the camurl value. The rest of the arguments are ignored.
if [ "$#" -ge 1 ]
then
    camurl=$1
fi

if [ -z ${camurl+x} ]
then
    echo "You have not provided the link to the cam to be ripped."
    echo
    echo "Provide it either as the first argument or in the configuration file".
    exit -1
fi

# camid is the identifier for this cam, extracted from its url.
camid=$(basename $camurl .html)

# logfile is the name of the file for logging the ripper activity
logfile="$camid.log"

if [ ! -d $tmpdir ]
then
    mkdir -p $tmpdir
fi

if [ ! -d $basedir/$ripsdir/$camid ]
then
    mkdir -p $basedir/$ripsdir/$camid
    echo "[$(date +"%Y%m%d-%H%M%S")] Creating $basedir/$ripsdir/$camid" >> $basedir/$logfile
fi

echo "[$(date +"%Y%m%d-%H%M%S")] Session STARTED" > $basedir/$logfile

while true
do
  echo "[$(date +"%Y%m%d-%H%M%S")] Downloading index file for $camid" >> $basedir/$logfile
  torsocks wget -q -t0 -N --user-agent="$useragent" --keep-session-cookies --save-cookies "$tmpdir/cookies-$camid" "$camurl" -O $tmpdir/index.html
  plurl=$(grep m3u8 $tmpdir/index.html | sed -e 's$.*\(https.*m3u8.a=..........................\).*$\1$')

  # The session is reused for five times. It is renewed afterwards. 
  i=0
  while [ $i -lt 5 ]
  do
    datedir=$(date +"%Y%m%d")
    if [ ! -d $basedir/$ripsdir/$camid/$datedir ]
    then
	mkdir -p $basedir/$ripsdir/$camid/$datedir
    fi
    ts1=$(date +"%s")

    echo "[$(date +"%Y%m%d-%H%M%S")] Downloading playlist for $camid" >> $basedir/$logfile
    torsocks wget -q -t0 -N --user-agent="$useragent" --load-cookies "cookies-$camid" "$plurl" -O $tmpdir/playlist.m3u8
    grep "http.*ts" $tmpdir/playlist.m3u8 > $tmpdir/tsfiles
    echo "[$(date +"%Y%m%d-%H%M%S")] Downloading video fragments for $camid" >> $basedir/$logfile
    torsocks wget -q -t0 -N --user-agent="$useragent" --load-cookies "cookies-$camid" -i $tmpdir/tsfiles -P $basedir/$ripsdir/$camid/$datedir

    ts2=$(date +"%s")
    sleeptime=$(($interval-$ts2+$ts1))
    echo "[$(date +"%Y%m%d-%H%M%S")] Sleeping for $sleeptime seconds" >> $basedir/$logfile
    if [ $sleeptime -gt 0 ]; then sleep $sleeptime; fi
    i=$((i+1))
  done
done
