# dash-mnTax
Simple [bash script](dash-mnTax.sh) for listing past dash.org masternode payments in USD.

## Usage:
- save [dash-mnTax.sh](dash-mnTax.sh) and execute `chmod 755 dash-mnTax.sh`
- Usage: `bash dash-mnTax.sh <DASH ADDRESS> [<START DATE> <END DATE>]`
- Example: `bash dash-mnTax.sh XdEmOjfadjfiieur8fjdkewi7849jfdls "2016-01-01 00:00:00" "2016-12-31 23:59:59"`

## Requirements:
- install calculator `bc` e.g. `apt-get install bc`

## Description:
This script will list all masternode payments (earliest starting June 2014) and their US Dollar value at that given time.

Algorithm:
- Get MN transaction data from Dash block explorer
- Get BTC/USD data from Bitstamp for each MN payment
- Get DASH/BTC data from Poloniex for each MN payment
- Printing History and calculating Total USD Value

Note: Because Bitstamp API does not provide proper trading history, the script will download BTC history in CSV format from bitcoincharts.com. 600 MB are required for this. The script reads the file several times, this causes high harddisk load and long runtime.

## History:
- Initial release