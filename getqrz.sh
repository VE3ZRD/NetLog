#!/bin/bash
############################################################
#  This script will retreive data from QRZ                 #
#                                                          #
#  VE3RD                              Created 2021/07/05   #
############################################################
set -o errexit 
set -o pipefail 

if [ -z "$1" ]; then
	echo "No Call Sign Provided"
	exit
fi

if [ "$1" ]; then
        P1="$1"
        P1S=${P1^^}
        call=${P1^^}
fi

function getqrz(){
. /home/pi-star/.qrz.conf
# get a session key from qrz.com
session_xml=$(curl -s -X GET 'http://xmldata.qrz.com/xml/current/?username='${user}';password='${password}';agent=qrz_sh')

# check for login errors
#e=$(printf %s "$session_xml" | grep -oP "(?<=<Error>).*?(?=</Error>)" ) # only works with GNU grep
e=$(printf %s "$session_xml" | awk -v FS="(<Error>|<\/Error>)" '{print $2}' 2>/dev/null | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n//g')
if [ "$e" != ""  ]
  then
    echo "The following error has occured: $e"
    exit
  fi

# extract session key from response
#session_key=$(printf %s "$session_xml" |grep -oP '(?<=<Key>).*?(?=</Key>)') # only works with GNU grep
session_key=$(printf %s "$session_xml" | awk -v FS="(<Key>|<\/Key>)" '{print $2}' 2>/dev/null | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n//g')

# lookup callsign at qrz.com
lookup_result=$(curl -s -X GET 'http://xmldata.qrz.com/xml/current/?s='${session_key}';callsign='${call}'')

ncall="OK"

# check for login errors
#e=$(printf %s "$lookup_result" | grep -oP "(?<=<Error>).*?(?=</Error>)" ) # only works with GNU grep
e=$(printf %s "$lookup_result" | awk -v FS="(<Error>|<\/Error>)" '{print $2}' 2>/dev/null | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n//g')
if [ "$e" != ""  ]
  then
    	echo "$call  Not Found at QRZ"
	cnt=$((cnt+1))
	nocall="$cnt,$call,NoName,NA,NA.NA,NA,NA" 
	echo "$nocall" >> /usr/local/etc/stripped2.csv
	ncall="NO"
#    exit
#  fi
else
	# grep field values from xml and put them into variables
	#for f in "call" "fname" "name" "addr1" "addr2" "country" "grid" "email" "user" "lotw" "mqsl" "eqsl" "qslmgr"
	for f in "call" "fname" "name" "addr1" "addr2" "state" "country" 
	do

  		#z=$(printf %s "$lookup_result" | grep -oP "(?<=<${f}>).*?(?=</${f}>)" ) # only works with GNU grep
  		z=$(printf %s "$lookup_result" | awk -v FS="(<${f}>|<\/${f}>)" '{print $2}' 2>/dev/null | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n//g')
  		eval "$f='${z}'";
	done

	#touch /usr/local/etc/stripped2.csv
        cntd=$(tail -n 1 /usr/local/etc/stripped2.csv | cut -d "," -f 1)
	cnt=$((cntd+1))
	newcall=$(echo "$cnt","$call","$fname","$name","$addr2","$state","$country") 
	echo -e "${LTMAG}QRZ: $newcall $cnt added to stripped2.csv ${ENDCOLOR}"
	echo "$newcall" >> /usr/local/etc/stripped2.csv
fi
}

if grep -F "$call," /usr/local/etc/stripped.csv  > /dev/null
then
        echo -en "${LTGREEN}$Time Call:$call Found in Stripped.csv ${ENDCOLOR} \n"
 	grep -F "$call," /usr/local/etc/stripped.csv | head -n 1
else
        if grep -F "$call" /usr/local/etc/stripped2.csv
        then
                echo -en "${LTCYAN} $Time Call $call Found in Stripped2.csv ${ENDCOLOR} \n"
	 	grep -F "$call," /usr/local/etc/stripped2.csv | head -n 1
        else
                echo "$Time Using  QRZ to Locate $call"
                getqrz
        fi

fi


