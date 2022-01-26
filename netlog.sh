#!/bin/bash
############################################################
#  This script will automate the process of                #
#  Logging Calls on a Pi-Star Hotpot			   #
#  to assist with Net Logging                              #
#                                                          #
#  VE3RD                              Created 2021/07/05   #
############################################################
#set -o errexit 
#set -o pipefail 
set -e
#set -e 
#set -o errtrace
#set -E -o functrace

ver=2022012014


sudo mount -o remount,rw / 
#printf '\e[9;1t'

callstat="" 
callinfo="No Info" 
lastcall2="" 
lastcall1=""
netcont="none"
stat=""
dt1=""
P1="$1"
if [ ! -z "$P1" ]; then
	netcont=$(echo "$P1" | tr '[:lower:]' '[:upper:]')
fi

P2="$2"
if [ "$P2" ]; then
#	P2S=${P2^^} 
#	stat=${P2^^}
	stat=$(echo "$P2" | tr '[:lower:]' '[:upper:]')
fi
P3="$3"
if [ "$P3" ]; then
	P3S=${P3^^} 
fi

TG=""
#echo "$netcont"   "$stat" 
dur=$((0)) 
cnt=$((0)) 
lcnt=$((0)) 
count=""
cntd=0
cm=0 
lcm=0 
ber=0 
netcontdone=0 
nodupes=0 
rf=0 
clen=$((0))
lfdts="" 
dts="" 
nline1=""
calli=""
src="RF"  #"NET"
active=0
sline="                                                                                                                       "
oldline=""
newline=""
pmode=""
mode=""
server=""
call=""
line2=""
yat=""
keybd="no"
amode="no"
stripped=0

err_report() 
{ 
	echo "Error on line $1"
	echo "Last  Call = $call" 
	echo "Last TCall = $tcall" 
	./netlog.sh ReStart
}

trap 'err_report $LINENO' ERR


fnEXIT() {

  echo -e "${BOLD}${WHI}THANK YOU FOR USING NETLOG by VE3RD!${SGR0}${DEF}"
echo ""
  exit
  
}

trap fnEXIT SIGINT SIGTERM

function getinput()
{
	calli=" "
	echo -n "Type a Call Sign and press enter: ";
	read calli
	call=${calli^^} 
	echo ""
	stty sane
	cm=2
	keybd="yes"
	ProcessNewCall
}


function help(){
	#echo "Syntax : \./netlog.sh Param1 Param2 Param3"
	echo "All Parameters are optional"
	echo "Param1 can be  any one of three things "
	echo "1) Net Controller Call Sign.  If used This must be Param 1"
	echo "2) The word 'NEW' This will initalize the Log File"
	echo "3) The word 'OLD' This will start by showing the log file complete with dupes"
	echo "3) No Parameters will start by displaying the log file with no dupes"
echo ""
	echo "You can manually enter a call sign."
	echo "1) Press ENTER"
	echo "2) Enter a Call Sign"
	echo "3) Press ENTEE"
}


function header(){
	clear
	set -e sudo mount -o remount,rw / 
	echo ""
	echo "NET Logging Program by VE3RD Version $ver"
#	echo ""
	echo "Dates and Times Shown are Local to your hotspot"
#	echo ""
	echo "Net Log Started $dates"
	echo "0, Net Log Started $dates" | tee /home/pi-star/netlog.log > /dev/null
#	echo "0, Net Log Started $dates" > /home/pi-star/netlog.log
	echo "0" | tee ./count.val > /dev/null
	echo ""
	if [ ! "$netcont" ] || [ "$netcont" == "NEW" ]; then
		echo "No Net Controller Specified"
		netcont="N/A"
	else
		echo "Net Controller is $netcont"
		echo ""
	fi
}
#M: 2021-12-29 14:55:46.923 YSF, received network data from WB2FLX     to DG-ID 0 at FCS00390
function getysf(){
	ysfm=$(sed -n -r "/^\[Network\]/ { :l /^Startup[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/ysfgateway)
	server="$ysfm"
	tg=$(echo "$nline1" | cut -d " " -f 14)
	if [ "$ysfm" == "YSF2P25" ]; then
		server="YSF2P25"
		tg=$(sed -n -r "/^\[Network\]/ { :l /^Static[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/p25gateway)
	fi
}
function getnxdn(){
	nxdn=$(sed -n -r "/^\[Network\]/ { :l /^Startup[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/nxdngateway)
}

function getserver(){
	Addr=$(sed -n -r "/^\[DMR Network\]/ { :l /^Address[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/mmdvmhost)
	DMRen=$(sed -n -r "/^\[DMR\]/ { :l /^Enabled[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/mmdvmhost)

	if [ $Addr = "127.0.0.1" ] && [ "$DMRen" = "1" ]; then
		fg=$(ls /var/log/pi-star/DMRGateway* | tail -n1)
		NetNum=$(tail -n1 "$fg" | cut -d " " -f 6)
		server=$(sed -n -r "/^\[DMR Network "${NetNum##*( )}"\]/ { :l /^Name[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/dmrgateway)
         else	
		ms=$(sudo sed -n '/^[^#]*'"$Addr"'/p' /usr/local/etc/DMR_Hosts.txt | head -n1 | sed -E "s/[[:space:]]+/|/g" | cut -d'|' -f1)
 		server=$(echo "$ms" | cut -d " " -f1)
	fi
		
sudo mount -o remount,rw / 
echo "Get Server Data " >> /home/pi-star/netlog_debug.txt

}

function getuserinfo(){
stripped=0
	if [ "$cm" != 6 ] && [ ! -z  "$call" ] && [ "$call" != "to" ]; then
		call=$(echo "$call" | cut -d "/" -f 1)
		call=$(echo "$call" | cut -d "-" -f 1)
if [ $call ]; then
 		lines=$(sed -n '/'",$call"',/p' /usr/local/etc/stripped.csv | head -n 1)	
		
		if [ -z "$lines"  ]; then
	 		lines=$(sed -n '/'",$call"',/p' /usr/local/etc/stripped2.csv | head -n 1)	
		else
			stripped=1
		fi 
		if [ "$lines"  ]; then
			stripped=2
		fi
		line=$(echo "$lines" | head -n1)

		if [ ! -z line ] || [ stripped == 0 ]; then
			name=$(echo "$line" | cut -d "," -f 3 | cut -d " " -f 1)
#			name=$(echo "$line" | cut -d "," -f 3 )
			city=$(echo "$line"| cut -d "," -f 5)
			state=$(echo "$line" | cut -d "," -f 6)
			country=$(echo "$line" | cut -d "," -f 7)
		else
			callinfo="No Info"
			name="NA"
			city="NA"
			state="NA"
			country="NA"
		fi
	fi
fi
sudo mount -o remount,rw / 

echo "End Get User Info " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
}

function checkcall(){ 
		if [ "$cm" != 6 ] && [ "$call" != "to" ]; then 
			logline=$(sed -n '/'"$call"',/p' /home/pi-star/netlog.log | head -n 1) 
			if [ $? != 0 ]; then
  				echo "Sed Error on Line $LINENO"
			fi
			
			if [ -z "$logline" ]; then 
     				callstat="New"
			else 
				callstat="Dup"
				cnt2da=$(echo "$logline" | cut -d "," -f 1) 
	
				cnt2d=$(printf "%1.0f\n" $cnt2da) 
	#			ck=$(echo "$logline" | cut -d "," -f 3) #call 
	#			ckt=$(echo "$logline" | cut -d "," -f 2) # time
			fi
		fi
}

function Logit(){ 
	sudo mount -o remount,rw /
	## Write New Call to Log File
	echo "$cnt, $mode, $dt1, $Time, $call, $name, $city, $state, $country, $dur sec $server $tg " | tee -a /home/pi-star/netlog.log > /dev/null
	echo "$cnt" | tee ./count.val > /dev/null
}
function LogDup(){ 
	sudo mount -o remount,rw /
	## Write Duplicate Call to Log File
	echo " -- Dup $cntd, $mode, $dt1, $Time, $call, $name, $city, $state, $country, $dur sec $server $tg " >> /home/pi-star/netlog.log 
}



function ProcessNewCall(){ 

RED="\e[31m"
GREEN="\e[32m"
LTMAG="\e[95m"
LTGREEN="\e[92m"
LTCYAN="\e[96m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"


#echo "Processing Call:$call Mode:$pmode"

if [ "$keybd" == "yes" ]; then
	pmode="DMRK"    
  	keybd="no"
fi
sudo mount -o remount,rw / 

echo "ProcessNewCall 1 $call " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
	getuserinfo 
	checkcall 
#	getserver 

	if [ "$mode" == "DMR" ]; then
		getserver
        fi

	if [ "$pmode" == "YSF" ]; then
		getysf
		tg="$yat"
        fi

	if [ "$pmode" == "P25" ]; then
		getp25
        fi
	if [ "$pmode" == "NXDN" ]; then
		getnxdn
        fi

#echo "Process Mode - $pmode : Call:$call" >> /home/pi-star/netlog_debug.txt

sudo mount -o remount,rw / 

echo "ProcessNewCall - got mode info " | tee -a /home/pi-star/netlog_debug.txt > /dev/null

	if [ "$pmode" == "DMRA" ] || [ "$pmode" == "YSFA" ] || [ "$pmode" == "P25A" ] || [ "$pmode" == "NXDNA" ]; then
                fdate=$(echo "$nline1" | cut -d " " -f2)
		amode="yes"
		textstr=$(echo -en " ${YELLOW}   Active $mode QSO $dt1 $Time from $call $name, $city, $state, $country, $server : $tg ${ENDCOLOR}")
		echo "$textstr"
		echo -en "\033[1A\033"
		ber=0
		pl=0
		dur=0
		sudo mount -o remount,rw / 

echo "ProcessNewCall Active QSO $pmode" | tee -a /home/pi-star/netlog_debug.txt > /dev/null
	fi

   	if [  "$pmode" == "DMRT" ] || [ "$pmode" == "YSFT" ] || [ "$pmode" == "P25T" ]  || [ "$pmode" == "NXDNT" ]; then
		amode="no"
sudo mount -o remount,rw / 
echo "ProcessNewCall Last Heard $pmode" | tee -a /home/pi-star/netlog_debug.txt > /dev/null
		if [ "$call" == "$netcont" ]; then
			sudo mount -o remount,rw /

			if [ "$rf" == 1 ]; then
				printf " ${LTMAG}-------------------- $mode $dt1 $Time  Net Control $netcont $name BER:$ber  $tg,   $server ${ENDCOLOR}\n"
			else
				printf " ${LTMAG}-------------------- $mode $dt1 $Time  Net Control $netcont $name, $city, $state, $country, $durt sec,  $tg,   $server ${ENDCOLOR}\n"
			fi	
			echo " --------------------- $mode $dt1 $Time  Net Control $netcont $name, $city, $state, $country, $durt secy  \n" >> /home/pi-star/netlog.log 

#			printf '\e[0m'
sudo mount -o remount,rw / 
echo "ProcessNewCall echo net control " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
		fi

		if [ "$call" != "$netcont" ]; then
			lastcall1=""
			call1=""
			netcontdone=0


				if [ $dur -lt 2 ]; then

					if [ "$callstat" == "New" ]; then
						cnt=$((cnt+1))
printf "${LTCYAN} %-3s $mode New KeyUp %s %-8s -- %-6s %s, %s, %s, %s, %s, %s, TG:%s  %s ${ENDCOLOR} \n" "$cnt" "$dt1" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg "
						Logit
sudo mount -o remount,rw / 

echo "ProcessNewCall Loged New Key Up" | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi

					if [ "$callstat" == "Dup" ]; then
						cnt2ds=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n 1)
						if [ $? != 0 ]; then
 			 				echo "Sed Error on Line $LINENO"
						fi
						cnt2d=$(echo "$cnt2ds" | cut -d "," -f 1)

printf "${LTGREEN}%s SKU Dup" "$mode"
printf " %-4s %s %-8s %-6s " "$cnt2d" "$dt1" "$Time" "$call" 
printf " %s, %s, %s, %s" "$name" "$city" "$state" "$country"
printf " Dur:%s, Pl:%s, Svr:%s, TG:%s ${ENDCOLOR}\n" "$durt" "$pl" "$server" "$tg"

#printf "${LTGREEN} %3s %4s %s %-8s %-6s %s, %s, %s, %s  %s, %s, %s, %s ${ENDCOLOR}\n" "$mode" "$cnt2d" "$dt1" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt" "$pl" "$server" "$tg"
#printf "${LTGREEN} %3s %4s %-8s %-6s %s, %s, %s, %s  %s, %s, %s, %s ${ENDCOLOR}\n" "$mode" "$cnt2d" "$dt1 $Time" "$call" "$name" "$city" "$state" "$country" "$durt" "$pl" "$server" "$tg"
#printf "${LTGREEN} %3s %4s %-8s ${ENDCOLOR}\n" "$mode" "$cnt2d" "$Time" "$call"

sudo mount -o remount,rw / 
LogDup

echo "ProcessNewCall Keyup Dupe " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi

				#		echo "Dupe Callstat = $callstat $dur"
				else  # Real Call

					if [ "$callstat" == "New" ]; then
##						echo " Write New Call to Screen"
						cnt=$((cnt+1))
#						printf '\e[0;40m'
#						printf '\e[1;36m'

					    	if [ "$kbd" == true ]; then
printf "${LTCYAN} %-3s $mode New Call %s %-8s -- %-6s %s, %s, %s, %s, %s  KeyBd, TG:%s %s ${ENDCOLOR}\n" "$cnt" "$dt1" "$Time" "$call" "$name" "$city" "$state" "$country" "$server" "$tg "	
					    	else
printf "${LTCYAN} %-3s $mode New Call %s %-8s -- %-6s %s, %s, %s, %s,  Dur:%s Secs, PL:%s, TG:%s %s${ENDCOLOR}\n" "$cnt" "$dt" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt"  "$pl" "$server" "$tg "	
					    	
						fi
						Logit
sudo mount -o remount,rw / 

echo "ProcessNewCall Logged New Call " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi

					if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
							## Write Duplicate Info to Screen

				    		if [ "$kbd" == true ]; then
		#
printf "${LTGREEN}$mode KBd Dup %4s %s %-8s %-6s %s,%s, %s, %s %s %s${ENDCOLOR}\n" "$cnt2d" "$dt1" "$Time" "$call" "$name" "$city" "$state" "$country" "$server" "$tg"	
#printf "%s, %s, %s %s %s\n" "$city" "$state" "$country" "$server" "$tg"	
					    	else
printf "${LTGREEN}$mode Net Dup %-4s %s %-8s %-6s %s, %s, %s, %s, %s, %s %s %s${ENDCOLOR} \n" "$cnt2d" "$dt1" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg"	
#printf "   %s, %s, %s %s %s \n" "$country" " Dur: $durt sec"  "PL: $pl" "$server" "$tg"	
					    	fi
#							printf '\e[0m'
#						fi
sudo mount -o remount,rw / 
LogDup
echo "ProcessNewCall echo Duplicate Call " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
					fi
printf "${ENDCOLOR}"
			
				fi  # end of keyup loop
		fi  #end of not netcont loop

		if [ active == 1 ]; then
			active=0
		fi
		lcm=0
	fi
sudo mount -o remount,rw / 

echo "ProcessNewCall End of Regular Data " | tee -a /home/pi-star/netlog_debug.txt > /dev/null

#Watchdog loop
	if [ "$pmode" == "Watchdog" ]; then
sudo mount -o remount,rw / 

echo "ProcessNewCall Processing Watchdog Line " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
		if [ "$callstat" == "New" ]; then
			cnt=$((cnt+1))
			printf " ${LTCYAN} New %s %s %-15s - $mode Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s${ENDCOLOR}\n" "$cnt" "$dt1" "$Time" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
			Logit
		fi 
		if [ "$callstat" == "Dup" ]; then
			printf "${LTGREEN} Dup %s %s %-15s - $mode Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s${ENDCOLOR}\n" "$cnt2d" "$dt1" "$Time" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
		fi	
	fi
sudo mount -o remount,rw / 

echo "ProcessNewCall End " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
	
}
################################
function ParseLineNXDN(){
		if [[ "$nline1" =~ "network transmission" ]]; then
			call=$(echo "$nline1" | cut -d " " -f 9)
			tg=$(echo "$nline1" | cut -d " " -f 12)
			pmode="NXDNA"
		fi
		if [[ "$nline1" =~ "end of transmission" ]]; then
			call=$(echo "$nline1" | cut -d " " -f 11)
			tg=$(echo "$nline1" | cut -d " " -f 14)
			durt=$(echo "$nline1" | cut -d " " -f 15)
			dur=$(printf "%1.0f\n" $durt)
			pmode="NXDNT"
		fi
}

function ParseLineP25(){

		if [[ "$nline1" =~ "received network" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 9)
					tg=$(echo "$nline1" | cut -d " " -f 12)
					pmode="P25A"
		fi
		if [[ "$nline1" =~ "end of transmission" ]]; then
					call=$(echo "$nline1" | cut -d " " -f 10)
					tg=$(echo "$nline1" | cut -d " " -f 13)
					pl=$(echo "$nline1" | cut -d " " -f 16)
					ber=$(echo "$nline1" | cut -d " " -f 23)
					durt=$(echo "$nline1" | cut -d " " -f 14)
					dur=$(printf "%1.0f\n" $durt)
					pmode="P25T"
		fi
}

function ParseLineYSF(){
		if [[ "$nline1" =~ "header from" ]] || [[ "$nline1" =~ "data from" ]]; then
#					call=$(echo "$nline1" | cut -d " " -f 9 | cut -d "/" -f 1)
					name=$(echo "$nline1" | cut -d " " -f 9 | cut -d "/" -f 2)
			#		echo "Call=$call"
					yat=$(echo "$nline1" | cut -d " " -f 14)
					tg="$yat"
					server=""
					pmode="YSFA"
		fi

		if [[ "$nline1" =~ "end of transmission" ]]; then
#					call=$(echo "$nline1" | cut -d " " -f 11)
					ber=$(echo "$nline1" | cut -d " " -f 18)
				#	pl=$(echo "$nline1" | cut -d " " -f 17)
					durt=$(echo "$nline1" | cut -d " " -f 15)
					dur=$(printf "%1.0f\n" $durt)
					pmode="YSFT"
		fi

		if [[ "$nline1" =~ "transmission lost" ]]; then
#					call=$(echo "$nline1" | cut -d " " -f 8)
					ber=$(echo "$nline1" | cut -d " " -f 15)
					durt=$(echo "$nline1" | cut -d " " -f 11)
					dur=$(printf "%1.0f\n" $durt)
					pmode="YSFW"
		fi
}
################################################
function ParseLineDMR(){

	
#	echo " Last Line : $nline1"
	tg=""
	sudo mount -o remount,rw / 

	echo "ParseLine getting date/time " | tee -a /home/pi-star/netlog_debug.txt > /dev/null
	fdate=$(echo "$nline1" | cut -d " " -f2 )    #| sed 's/ *$//g' 
	ftime=$(echo "$nline1" | cut -d " " -f3 )
#	mode=$(echo "$nline1" | cut -d " " -f 4 |  sed 's/,//g')


	if [[ "$nline1" =~ "RF" ]]; then

				if [[ "$nline1" =~ "RF voice header" ]]; then
					tg=$(echo "$nline1" | cut -d " " -f 15 | sed 's/,//g')
					ber=0
					pl=0
					durt=""
					dur=0
					pmode="DMRA"
				fi

				if [[ "$nline1" =~ "end of voice transmission" ]]; then
					nmode="RF"
					tg=$(echo "$nline1" | cut -d " " -f 17 | sed 's/,//g')
					ber=$(echo "$nline1" | cut -d " " -f 21)
					pl=$(echo "$nline1" | cut -d " " -f 20)
 					durt=$(echo "$nline1" | cut -d " " -f 18)
					dur=$(printf "%1.0f\n" $durt)
					pmode="DMRT"
				fi
	else	

			if [[ "$nline1" =~ "network voice header" ]]; then
					nmode="NET"
					tg=$(echo "$nline1" | cut -d " " -f 15 | sed 's/,//g')
					pl=0
					ber=0
					dur=0
					pmode="DMRA"
				fi

				if [[ "$nline1" =~ "end of voice" ]]; then
#					call=$(echo "$nline1" | cut -d " " -f 14)
					nmode="NET"
					tg=$(echo "$nline1" | cut -d " " -f 17 | sed 's/,//g')
					pl=$(echo "$nline1" | cut -d " " -f 20)
					ber=$(echo "$nline1" | cut -d " " -f 24)
					durt=$(echo "$nline1" | cut -d " " -f 18)
					dur=$(printf "%1.0f\n" $durt)
					pmode="DMRT"

				fi	
     	fi


		if [[ "$nline1" =~ "watchdog has expired" ]]; then
					pl=$(echo "$nline1" | cut -d " " -f 13)
					ber=$(echo "$nline1" | cut -d " " -f 17)
					durt=$(echo "$nline1" | cut -d " " -f 11)
					dur=$(printf "%1.0f\n" $durt)
					pmode="Watchdog"
					cnt=$((cnt+1))
		fi
		if [[ "$nline1" =~ "watchdog" ]] && [ "$mode" == "P25" ]; then
					pl=$(echo "$nline1" | cut -d " " -f 11)
					ber="0"
					durt=$(echo "$nline1" | cut -d " " -f 9)
					dur=$(printf "%1.0f\n" $durt)
					pmode="Watchdog"
		fi
}

function GetLastLine(){
	ok=false
        f1=$(ls -tv /var/log/pi-star/MMDVM* | tail -n 1 )
        line1=$(tail -n 1 "$f1" | tr -s \ |  sed -n -e 's/^.*to //p')
#	nline1=$(tail -n 1 "$f1" | tr -s \ |  sed 's/ *$//g' | sed 's/%//g' | sed 's/,//g' )
	nline1=$(tail -n 1 "$f1" | tr -s \ )
	tcall=$(echo "$nline1" |  grep -oP '(?<=from )\w+(?= to)' | tr "/" " " | tr "-" " ")
	clen=$(echo $tcall | wc -c)

	if [[ "$nline1" =~ "from" ]] && [ "$clen" -ge 4 ] && [ "$clen" -le 7 ]; then
		ok=true
		call="$tcall"
	fi

        newline="$nline1"
        mode=$(echo "$nline1" | cut -d " " -f 4 |  sed 's/-ND//' | sed 's/,//g' )

        if [ "$oldline" != "$newline" ] && [ "$ok" == true ]; then
		dt=$(date --rfc-3339=ns)
		sudo mount -o remount,rw / 

		 echo "GetLastLine - Got New Line $dt" | tee /home/pi-star/netlog_debug.txt > /dev/null

	        if [ "$mode" == "DMR" ]; then
			if [ "$ok" == true ]; then
				ParseLineDMR
                        	ProcessNewCall
			fi
		fi
	        
		if [ "$mode" == "YSF" ]; then
			if [ "$ok" == true ]; then
				ParseLineYSF
                        	ProcessNewCall
			fi
		fi
	        
		if [ "$mode" == "P25" ]; then
			if [ "$ok" == true ]; then
				ParseLineP25
                        	ProcessNewCall
			fi
		fi
	        
		if [ "$mode" == "NXDN" ]; then
			if [ "$ok" == true ]; then
				ParseLineNXDN
                        	ProcessNewCall
	                fi
		fi	
	dt=$(date --rfc-3339=ns)
#echo "Get dt"
sudo mount -o remount,rw / 

		echo "End of GetLastLine Loop  $dt "| tee -a /home/pi-star/netlog_debug.txt > /dev/null
#echo "Get 11"
	
#		echo "echo 1 > /proc/sys/vm/drop_caches" > /dev/null

        oldline="$newline"
#	echo "End of Loop: wait for next line"
        fi

}

function getcount(){
  count=$(grep -v '^ --' /home/pi-star/netlog.log | tail -n 1 | cut -d "," -f 1)
  echo "$count" > ./count.val
  
}

function StartUp()
{
        f1=$(ls -tv /var/log/pi-star/MMDVM* | tail -n 1 )
#        line1=$(tail -n 1 "$f1" | tr -s \ |  sed -n -e 's/^.*to //p')
#	nline1=$(tail -n 1 "$f1" | tr -s \ |  sed 's/ *$//g' | sed 's/%//g' | sed 's/,//g' )   #sed 's/h//g'
	nline1=$(tail -n 1 "$f1" | tr -s \ )

        newline="$nline1"
	oldline="$nline1"

if [ ! -f /home/pi-star/Netlog/count.val ]; then
  
sudo mount -o remount,rw / 
echo "0" > /home/pi-star/Netlog/count.val
fi



if [ "$netcont" != "ReStart" ]; then

	if [ "$netcont" == "HELP" ]; then
		help
		exit
	fi

	if [ "$netcont" == "NEW" ] || [ "$stat" == "NEW" ] || [ ! -f /home/pi-star/netlog.log ]; then
		## Delete and start a new data file starting with date line
		dates=$(date '+%A %Y-%m-%d %T')
        	header 
		
	elif [ "$netcont" == "OLD" ] || [ "$stat" == "OLD" ] || [ ! -f /home/pi-star/netlog.log ]; then
		## Delete and start a new data file starting with date line
		dates=$(date '+%A %Y-%m-%d %T')
		cntt=$(cat ./count.val)
		getcount
                cnt=$((cntt))
                        echo "Restart Program Ver:$ver - Counter = $cnt"
                        cat /home/pi-star/netlog.log 
#			grep -v '^ --' /home/pi-star/netlog.log
   #             fi

	elif [ "$netcont" != "NEW" ] && [ "$stat" == "NEW" ] || [ ! -f /home/pi-star/netlog.log ]; then
		call="$netcont"
		processnewcall

	elif [ "$netcont" != "ReStart" ]; then
#                        cat /home/pi-star/netlog.log 
			grep -v '^ --' /home/pi-star/netlog.log
			getcount
			cntt=$(cat ./count.val)
                	cnt=$((cntt))
                        echo "Restart Program Ver:$ver - Counter = $cnt"
	fi

fi
}

######## Start of Main Program
###LoopKeys

StartUp

#getnewcall
callstat=""

######### Main Loop Starts Here
#echo "Starting Loop"

while true
do 
kbd=false
	cm=0	
        dt1=$(date '+%m-%d')

 	Time=$(date '+%T')  
	GetLastLine


#	sync
#	sleep 1.0

	while read -t1  
  	do 
		kbd=true
		getinput
	done
done
echo "No Longer True"
