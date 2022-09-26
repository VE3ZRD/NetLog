#!/bin/bash

call=$1

f1=$(ls -atr /var/log/pi-star/MMDVM-2022-* | tail -n1)

#echo  "$f1"

endtime=$(date | cut -d " " -f4)

List1=$(sed -n '/00:00/,/"$endtime"/p' "$f1" | grep 'received network end of voice transmission')
echo "$List1"  > /home/pi-star/NetCountList1.txt
#echo "$List1"


#| sort -u > /home/pi-star/NetCountList2.txt
#cat /home/pi-star/NetCountList2.txt

cat /home/pi-star/NetCountList1.txt | awk '{ print $14, $3}' |sort -u -k 1,1 > /home/pi-star/netcount.txt

cnt=$(cat /home/pi-star/netcount.txt | wc -l )

#echo "Call Sign Count = $cnt" >> /home/pi-star/netcount.txt

cat /home/pi-star/netcount.txt
echo "------------------------"

echo "Start Time = 00:00:00 GMT"
echo  "  End Time = $endtime GMT"
echo "Call Sign Count = $cnt" 
echo "------------------------"
grep "$call" /home/pi-star/NetCountList1.txt |  awk '{ print $14, $3}'
