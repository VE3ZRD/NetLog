#!/bin/bash
############################################################
#  This script will automate the process of                #
#  Logging Calls on a Pi-Star Hotpot			   #
#  to assist with Net Logging                              #
#                                                          #
#  VE3RD                              Created 2021/07/05   #
############################################################
set -o errexit 
set -o pipefail 
set -e 
set -o errtrace
set -E -o functrace

ver=2021092501

sudo mount -o remount,rw / 
printf '\e[9;1t'

callstat="" 
callinfo="No Info" 
lastcall2="" 
lastcall1=""
P1="$1" 
P2="$2" 
P3="$3" 
P1S=${P1^^} 
P2S=${P2^^} 
P3S=${P3^^} 
netcont=${P1^^} 
stat=${P2^^}
#echo "$netcont"   "$stat" 
dur=$((0)) 
cnt=$((0)) 
cm=0 
lcm=0 
ber=0 
netcontdone=0 
nodupes=0 
rf=0 
lfdts="" 
dts="" 
nline1=""
calli=""
src="RF"  #"NET"
active=0

err_report() { 
	echo "Error on line $1 for call: $call"
	./netlog.sh ReStart 
}

trap 'err_report $LINENO' ERR

fnEXIT() {

 tput cuu1
 tput el
 tput el1 
  echo -e "${BOLD}${WHI}THANK YOU FOR USING NETLOG by VE3RD!${SGR0}${DEF}"
echo ""
  exit
  
}

trap fnEXIT SIGINT SIGTERM


function getinput()
{
	tput el
	tput el1
	calli=" "
	echo -n "Type a Call Sign and press enter: ";
	read calli
	call=${calli^^} 
	echo ""
	tput cuu 2
	stty sane
	cm=2
	ProcessNewCall K
}


function help(){
	#echo "Syntax : \./netlog.sh Param1 Param2 Param3"
	echo "All Parameters are optional"
	echo "Param1 can be  any one of three things "
	echo "1) Net Controller Call Sign.  If used This must be Param 1"
	echo "2) The word 'NEW' This will initalize the Log File"
	echo "3) The word 'NODUPES' This will stop the display from showing Dupes"
	echo "Param 2 and 3 may be any cobination of items 2 and 3 above"
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
	echo ""
	echo "Dates and Times Shown are Local to your hotspot"
	echo ""
	echo "Net Log Started $dates"
	echo "0, Net Log Started $dates" > /home/pi-star/netlog.log
	echo ""

	if [ ! "$netcont" ] || [ "$netcont" == "NEW" ]; then
		echo "No Net Controller Specified"
		netcont="N/A"
	else
		echo "Net Controller is $netcont"
		echo ""
	fi
}

function getserver(){

Addr=$(sed -n -r "/^\[DMR Network\]/ { :l /^Address[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/mmdvmhost)
if [ $Addr = "127.0.0.1" ]; then
	fg=$(ls /var/log/pi-star/DMRGateway* | tail -n1)
	NetNum=$(sudo tail -n1 "$fg" | cut -d " " -f 6)
	server=$(sed -n -r "/^\[DMR Network "${NetNum##*( )}"\]/ { :l /^Name[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/dmrgateway)
else
	ms=$(sudo sed -n '/^[^#]*'"$Addr"'/p' /usr/local/etc/DMR_Hosts.txt | head -n1 | sed -E "s/[[:space:]]+/|/g" | cut -d'|' -f1)
 	server=$(echo "$ms" | cut -d " " -f1)
fi
}

function getuserinfo(){
	if [ "$cm" != 6 ] && [ ! -z  "$call" ]; then
 		line=$(sed -n '/'",$call"',/p' /usr/local/etc/stripped.csv | head -n1)	

		if [ line ]; then
			name=$(echo "$line" | cut -d "," -f 3 | cut -d " " -f 1)
			city=$(echo "$line"| cut -d "," -f 5)
			state=$(echo "$line" | cut -d "," -f 6)
			country=$(echo "$line" | cut -d "," -f 7)
		else
			callinfo="No Info"
			name=""
			city=""
			state=""
			country=""
		fi
	fi
}

function checkcall(){ 
		if [ "$cm" != 6 ]; then 
			logline=$(sed -n '/'"$call"',/p' /home/pi-star/netlog.log) 
			if [ -z "$logline" ]; then 
     				callstat="New"
			else 
				callstat="Dup"
#				cnt2d=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n1 | cut -d "," -f 1)
				cnt2d=$(echo "$logline" | cut -d "," -f 1) 
				ck=$(echo "$logline" | cut -d "," -f 3) 
				ckt=$(echo "$logline" | cut -d "," -f 2)
			fi
		fi
}

function Logit(){ sudo mount -o remount,rw /
	## Write New Call to Log File
	echo "$cnt,$Time,$call,$name,$city,$state,$country " >> /home/pi-star/netlog.log
}


function getnewcall(){ 
	tg=""

	NewCall=$(echo "$nline1" | sed -n -e 's/^.*from //p' | cut -d " " -f1) 
	call="$NewCall"

if [ -z "$NewCall" ]; then
	call="$call1"
else
	call="$NewCall"
fi
	if [[ $nline1 =~ "RF voice header" ]]; then 
		cm=1 
		tg=$(echo "$nline1" | cut -d " " -f 15) 
		call1="$call" 
        	ln2=""
		lcm=0
	elif [[ $nline1 =~ "RF voice transmission lost" ]]; then 
		cm=1 
		tg=$(echo "$nline1" | cut -d " " -f 15) 
		call1="$call" 
        	ln2=""
			durt=$(echo "$nline1" | cut -d " " -f 16) 
			dur=$(printf "%1.0f\n" $durt) 
			ber=$(echo "$nline1" | sed -n -e 's/^.*BER: //p' | cut -d " " -f1) 
			cm=2 
			pl=0
			rf=1

	elif [[ $nline1 =~ "RF end of voice transmission" ]]; then
		cm=1 
		tg=$(echo "$nline1" | cut -d " " -f 17) 
		call1="$call" 
        	ln2=""
		durt=$(echo "$nline1" | cut -d " " -f 18) 
		dur=$(printf "%1.0f\n" $durt) 
		ber=$(echo "$nline1" | sed -n -e 's/^.*BER: //p' | cut -d " " -f1) 
		cm=2 
		pl=0
		rf=0

	elif [[ $nline1 =~ "network voice header" ]]; then 
		cm=1 
		tg=$(echo "$nline1" | cut -d " " -f 15) 
		call1="$call" 
        	ln2=""
		rf=0
	elif [[ $nline1 =~ "network end of voice transmission" ]]; then
		cm=1 
		tg=$(echo "$nline1" | cut -d " " -f 17) 
		call1="$call" 
        	ln2=""
		durt=$(echo "$nline1" | cut -d " " -f 18 ) 
		dur=$(printf "%1.0f\n" $durt) 
		pl=$(echo "$nline1" | cut -d " " -f 20 )
		ber=0 
		cm=2 
		rf=0
		lcm=0
	elif [[ $nline1 =~ "watchdog" ]]; then 
		cm=5
		checkcall 
		call5="$call1" 
		Logit

	elif [[ $nline1 =~ "overflow" ]]; then 
		cm=6 
		call2="NA"
	elif [[ $nline1 =~ "Data" ]]; then 
		cm=6 
		call2="NA" 
	fi
	
}

function ProcessNewCall(){ 
	if [ ! "$1" ]; then 
		getnewcall 
	fi 
	getuserinfo 
	checkcall 
	getserver 
	if [ "$1" ]; then 
	 dur=5 pl="" 
	fi

###  Active QSO	

#	if [ "$cm" == 1 ] && [ "$lastcall1" != "$call1" ] && [ "$lcm" != 1 ]; then 
	if [ "$cm" == 1 ] && [ "$lcm" != 1 ]; then 
		printf '\e[0;40m' 
		printf '\e[0;35m'
#		tput rmam
#		tput sc
		echo -en "    Active QSO from $call1 $name, $country, $tg,  $server\r"
		
	
 
#		tput rc
#		tput smam
		lcm=1
		call2=""
		lastcall2="n/a"
		lastcall1="$call1"
		lastcall5=""
		active=1
	#	netcontdone=1
	fi

	if [ "$cm" == 2 ]; then
		lastcall5=""
		lastcall1=""
		if [ active == 1 ]; then
			tput cuu 2
			tput el 1
			tput el
		fi

#		if [ "$call" == "$netcont" ] && [ "$netcontdone" == 1 ]; then
		if [ "$call" == "$netcont" ]; then
			sudo mount -o remount,rw /
#			tput el 1
#			tput el
	#		tput rmam
			printf '\e[0;40m'		
			if [ "$rf" == 1 ]; then
#				echo -e '\e[1;34m'"-------------------- $Time  Net Control $netcont $name BER:$ber  $tg   $server"          
				printf '\e[1;34m'"-------------------- $Time  Net Control $netcont $name BER:$ber  $tg   $server\n"          
			else	
				printf '\e[1;34m'"-------------------- $Time  Net Control $netcont $name, $durt sec,  $tg   $server\n"          
			fi	
			printf "$cnt,--------------------- $Time  Net Control $netcont $durt sec  \n" >> /home/pi-star/netlog.log
	#		tput smam

			name=""
			city=""
			state=""
			country=""
			callstat="NC"		
			netcontdone=1
			lastcm=2
		
		fi

		if [ "$call" != "$netcont" ]; then
			lastcall1=""
			call1=""
			netcontdone=0
			lastcall1=""
			if [ "$lastcall2" != "$call" ]; then
				if [ $dur -lt 2 ]; then
					#### Keyup < 2 seconds
		#			getuserinfo
					#lcm=0
					tput el 1
					tput el
					if [ "$callstat" == "New" ]; then
						printf '\e[0;40m'
						printf '\e[1;36m'
						cnt=$((cnt+1))
						tput rmam
						if [ "$rf" == 1 ]; then
							printf "%-3s New KeyUp  %-8s -- %-6s %s, %s, %s, %s, %s, %s, TG:%s  %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "Dur: $durt sec"  "BER: $ber" "RF: $tg" "$server"		
						else
							printf "%-3s New KeyUp  %-8s -- %-6s %s, %s, %s, %s, %s, %s, TG:%s  %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$tg" "$server"	
						fi
						tput smam
						Logit
					fi
				
					if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
						printf '\e[0;46m'
						printf '\e[0;33m'
						printf '\033[<1>A'
						cnt2d=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n1 | cut -d "," -f 1)
						if [ "$rf" == 1 ]; then
							printf "KeyUp Dupe %-3s %-15s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time/$ckt" "$call" "$name" "$city" "$state" "$country" "Dur: $durt sec"  "RF: BER: $ber "	
						else
							printf "KeyUp Dupe %-3s %-15s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time/$ckt" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl "	
						fi	
					fi
				#		echo "Dupe Callstat = $callstat $dur"
				else  # Real Call

					if [ "$callstat" == "New" ]; then
##						echo " Write New Call to Screen"
						cnt=$((cnt+1))
						printf '\e[0;40m'
						printf '\e[1;36m'
						if [ active == 1 ]; then
							tput cuu 1
						fi
						tput el 1
						tput el
						tput rmam
						if [ "$rf" == 1 ]; then
							printf "%-3s New Call   %-8s -- %-6s %s, %s, %s, %s, $s  Dur:%s Secs, BER:%s RF: TG:%s %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt"  "$ber" "$tg"  "$server"	
						else
					    		if [ "$1" ]; then
				#				tput cuu 2
								printf "%-3s New Call   %-8s -- %-6s %s, %s, %s, %s, %s  KeyBd, TG:%s %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$tg"  "$server"	
					    		else
								printf "%-3s New Call   %-8s -- %-6s %s, %s, %s, %s,  Dur:%s Secs, PL:%s, TG:%s %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt"  "$pl" "$tg"  "$server"	
					    		fi
						fi
				#		tput smam
						#lcm=0
						Logit
					fi

					if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
							## Write Duplicate Info to Screen

						if [ active == 1 ]; then
							tput cuu 2
		#				echo "Dup cuu 2 active 1"
						fi
						tput el 1
						tput el
						printf '\e[0;46m'
						printf '\e[0;33m'
						tput rmam
						if [ "$rf" == 1 ]; then
							printf " RF Dup %-3s %-15s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time/$ckt" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "RF: BER: $ber"	
						else			
					    		if [ "$1" ]; then
		#						tput cuu 2
								printf " KeyBd Dup %-3s %-15s %-6s %s, %s, %s, %s\n" "$cnt2d" "$Time/$ckt" "$call" "$name" "$city" "$state" "$country"	
					    		else
								printf " Net Dup %-3s %-15s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time/$ckt" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl               "	
					    		fi
						fi
						tput smam
						
					fi
			
				fi  # end of keyup loop
			fi   #end of lastcall2 loop
				lastcall2="$call"
		fi  #end of not netcont loop

		if [ active == 1 ]; then
			tput cuu 1
			active=0
		fi
		lcm=0
	fi
#Watchdog loop
	if [ "$cm" == 5 ] && [ "$lastcall5" != "$call" ] && [ "$lcm" != 5 ]; then
        	call5="$call1"
        	call="$call1"
		durt=$(echo "$nline1" | cut -d " " -f 11 )
		pl=$(echo "$nline1" | cut -d " " -f 13 )
		dur=$(printf "%1.0f\n" $durt)
		printf '\e[0;40m'
		printf '\e[1;31m'
		tput el 1
		tput el
		tput rmam
		checkcall
		if [ "$callstat" == "New" ]; then
			cnt=$((cnt+1))
#			echo "$cnt - New $Time - DMR Network Watchdog Timer has Expired for $call, $name, $dur Sec   PL:$pl        "
			printf "%-3s - New %-15s - DMR Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s\n" "$cnt" "$Time/$ckt" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
		fi	
		if [ "$callstat" == "Dup" ]; then
#			echo "$Time - Dup $cnt2d DMR Network Watchdog Timer has Expired for $call, $name, $dur Sec   PL:$pl        "
			printf "%-3s - New %-15s - DMR Network Watchdog Timer has Expired for %-6s %s, %s, %s, %s, %s\n" "$cnt" "$Time/$ckt" "$call" "$name" "Dur: $durt sec"  "PL: $pl"	
		fi	
		tput smam
		lastcall5="$call"
		lcm=5
	fi

	if [ "$lcm" != 1 ]; then
		lastcall1=""
	fi


	LPCall="$call"
}


function GetLastLine(){
        f1=$(ls -tv /var/log/pi-star/MMDVM* | tail -n 1 )
        nline1=$(tail -n 1 "$f1")
	fdate=$(echo "$nline1" | cut -d " " -f2)
	ftime=$(echo "$nline1" | cut -d " " -f3)
	fdts="$fdate"":""$ftime"
	fdts="$fdate"":""$ftime"

#	echo "$fdts"" --  ""$lfdts"
   
	if [ "$lfdts" != "$fdts" ] && [ ! -z "$lfdts" ]; then
		ProcessNewCall
		lfdts="$fdts"	
	fi 
	lfdts="$fdts"	

}

######## Start of Main Program
if [ "$netcont" != "ReStart" ]; then

	if [ "$netcont" == "HELP" ]; then
		help
		exit
	fi

	if [ "$netcont" == "NEW" ] || [ "$stat" == "NEW" ] || [ ! -f /home/pi-star/netlog.log ]; then
		## Delete and start a new data file starting with date line
		dates=$(date '+%A %Y-%m-%d %T')
        	header 
	elif [ "$netcont" != "ReStart" ]; then
		cntt=$(tail -n 1 /home/pi-star/netlog.log | cut -d "," -f 1)
		cnt=$((cntt))
		echo "Restart Program Ver:$ver - Counter = $cnt"
	fi


	if [ "$P1S" == "NODUPES" ] || [ "$P2S" == "NODUPES" ] || [ "$P3S" == "NODUPES" ]; then
		nodupes=1
		echo "Dupes Will Not be Displayed"
		echo ""
	else
		nodupes=0
		echo "Dupes Will Be Displayed"
		echo ""
	fi
fi
getnewcall
callstat=""
if [ ! "$call" ]; then
	call="$netcont"
	lastcall="$netcont"
	lastcall1="$netcont"
	lastcall2="$netcont"
fi

######### Main Loop Starts Here

while true
do 
	cm=0	
 	Time=$(date '+%T')  

	GetLastLine

	sleep 1.0
while read -t1  
  do getinput
done


done

