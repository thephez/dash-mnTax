#!/usr/bin/env bash
#
# Copyright (C) 2017 rockbit (https://github.com/rockbit)
#
# This program is free software: you can redistribute it and/or modify  
# it under the terms of the GNU General Public License as published by  
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License 
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

EXPLORER="https://explorer.dash.org/address/"
POLONIEX='https://poloniex.com/public?command=returnChartData&currencyPair=BTC_DASH'
BTCCHART='https://api.bitcoincharts.com/v1/csv/bitstampUSD.csv.gz'
BTCCHARTARCHIVE='bitstampUSD.csv.gz'
BTC_FILE='bitstampUSD.csv'

declare -i error=0
declare -i ind n cnt
declare -a expdate date time unixtime
declare -a dashamount
declare -a dash btc usd

if [[ $# -eq 0 || $# -eq 2 || $# > 3 ]]; then
  echo "Usage:   bash dash-mnTax.sh <DASH ADDRESS> [<START DATE> <END DATE>]"
  echo "Example: bash dash-mnTax.sh XdEmOjfadjfiieur8fjdkewi7849jfdls \"2016-01-01 00:00:00\" \"2016-12-31 23:59:59\""
  exit 1
fi

ADDR=$1
EXPLORER="$EXPLORER$ADDR"

## Check for bitstampUSD.csv and download it if missing
if [[ -f $BTC_FILE ]]; then
   echo "## Found $BTC_FILE"
else
   printf "\n############## File \"$BTC_FILE\" in directory \"$(pwd)\" does not exist. ###############\n\n"
   echo "You can download manually from https://api.bitcoincharts.com/v1/csv/bitstampUSD.csv.gz and extract \"$BTC_FILE\""
   echo "Or you wait and let the script download (80MB) and extract (500MB)"
   printf "\nStarting Download in 15 Seconds\n\n"
   sleep 15
   curl -O $BTCCHART
   gzip -d $BTCCHARTARCHIVE
   printf "\nFinished downloading and extracting\n\n" 
fi

## Start printing on console
echo "## Using DASH Address: \"$ADDR\""

if [[ $# -eq 3 ]]; then
    startdate=$2
    enddate=$3
else
    startdate="2016-01-01 00:00:00"
    enddate="2016-12-31 23:59:59"
    echo "## No Date specified, using defaults"
fi
echo "## Using Start Date: $startdate"
echo "## Using End Date:   $enddate"

cmd=$(echo date -d \'UTC $startdate\' +\"%s\")
startunixtime=$(eval $cmd)
cmd=$(echo date -d \'UTC $enddate\' +\"%s\")
endunixtime=$(eval $cmd)

##########################################################
echo "## Get MN transaction data from Dash block explorer"
# Dash explorer and Poloniex both using UTC time
# expdate array contains 2 lines for date and time tuple, $ind is used to split
expdate=($(curl -s $EXPLORER | grep -Po '.*"time">\K.*?(?=<.*)'))

# amount array contains 1 line for each value
amount=($(curl -s $EXPLORER | grep -Po '.*"amount">\K.*?(?=<.*)'))

cnt=${#expdate[@]}

n=0
for((i=0;i<$cnt/2;i++))
do
  ind=$i*2

  # exclude outgoing and 1000 dash transaction
  if [[ ${amount[$i]} != "("* ]] && [[ ${amount[$i]} != "1000" ]]; then
    cmd=$(echo date -d \'UTC ${expdate[$ind]} ${expdate[$ind+1]}\' +\"%s\")
    tmptime=$(eval $cmd)
    if [[ $tmptime > $startunixtime && $tmptime < $endunixtime ]]; then
      date[$n]=${expdate[$ind]}
      time[$n]=${expdate[$ind+1]}
      unixtime[$n]=$tmptime
      dashamount[$n]=${amount[$i]}
      (( n++ ))
    fi
  fi
done

cnt=${#date[@]}
echo "Found $cnt Masternode payments"

############################################################
echo "## Get BTC/USD data from Bitstamp for each MN payment"
## API not working
# Earliest possible MN payment starting ~ 1. June 2014 (timestamp=1401600000)
#apiurl="http://api.bitcoincharts.com/v1/trades.csv?symbol=bitstampUSD&start=1401600000"
#charts=($(curl -s "$apiurl"))
#cnt=${#charts[@]}
#echo $cnt
#echo ${charts[0]}

## Loop through data using grep (TODO: replace with more efficient solution)
for((i=0;i<$cnt;i++))
do
  # try to get btc price at same time than mn payment
  tmptime=$(echo ${unixtime[$i]:0:7})
  cmd=$(echo "cat $BTC_FILE | grep -Po -m 1 '^$tmptime...,\K.*?(?=,.*)'")
  tmpres=$(eval $cmd)
  # increase time delta to 3 hours if no price is found
  if [[ $tmpres == ""  ]]; then
    tmptime=$(echo ${unixtime[$i]:0:6})
    cmd=$(echo "cat $BTC_FILE | grep -Po -m 1 '^$tmptime....,\K.*?(?=,.*)'")
    tmpres=$(eval $cmd)
    if [[ $tmpres == ""  ]]; then
      tmpres="0" # mark as error
    fi
  fi
  
  btc[$i]=$tmpres
  printf "."
done
printf "\n"

#############################################################
echo "## Get DASH/BTC data from Poloniex for each MN payment"
for((i=0;i<$cnt;i++))
do
  timestart=${unixtime[$i]}
  ## add 120 minutes to timestamp for 7200 seconds polo candles
  timeend=$((timestart + 120 * 60 ))
  param=$(echo \&start=$timestart\&end=$timeend\&period=7200)
  POLONIEXURL=$(echo $POLONIEX$param)
  tmpres=($(curl -s "$POLONIEXURL" | grep -Po '.*"weightedAverage":\K.*?(?=}.*)'))
  dash[$i]=$tmpres
  sleep 1 # dont spam polo api
  printf "."
done
printf "\n"

###########################################################
echo "## Printing History and calculating Total USD Value"
totalusd="0.0"
totaldash="0.0"

for((i=0;i<$cnt;i++))
do
  tmpres=$(echo "${btc[$i]} * ${dash[$i]} * ${dashamount[$i]}" | bc)
  usd[$i]=$tmpres
  if [[ $tmpres == "0" ]]; then
    (( error++ ))
    echo "(ERROR) [$i] Date: ${date[$i]} ${time[$i]}, Amount: ${dashamount[$i]} DASH, Exchange price: ${dash[$i]} DASH/BTC and ${btc[$i]} BTC/USD, Value: ${usd[$i]} USD"
  else
    totalusd=$(echo "$totalusd + ${usd[$i]}" | bc)
    totaldash=$(echo "$totaldash + ${dashamount[$i]}" | bc)
    echo "[$i] Date: ${date[$i]} ${time[$i]}, Amount: ${dashamount[$i]} DASH, Exchange price: ${dash[$i]} DASH/BTC and ${btc[$i]} BTC/USD, Value: ${usd[$i]} USD"
  fi
done

echo 
echo "Start Date: $startdate  --  First Payment: ${date[0]} ${time[0]}"
echo "End Date:   $enddate  --  Last Payment: ${date[$cnt-1]} ${time[$cnt-1]}"
echo "Total DASH Received:  $totaldash DASH"
echo "Total USD Value:      $totalusd USD"
echo 
echo "Finished with $error Errors (missing price info)"
