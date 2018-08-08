#!/bin/sh


########################################################
#
# SF wrapper to enhance user experience of built-in duplicate_check tool 
#
########################################################

#********************************************************
#
# Starfish Storage Corporation ("COMPANY") CONFIDENTIAL
# Unpublished Copyright (c) 2011-2018 Starfish Storage Corporation, All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property of COMPANY. The intellectual and
# technical concepts contained herein are proprietary to COMPANY and may be covered by U.S. and Foreign
# Patents, patents in process, and are protected by trade secret or copyright law. Dissemination of this
# information or reproduction of this material is strictly forbidden unless prior written permission is
# obtained from COMPANY.  Access to the source code contained herein is hereby forbidden to anyone except
# current COMPANY employees, managers or contractors who have executed Confidentiality and Non-disclosure
# agreements explicitly covering such access.
#
# ANY REPRODUCTION, COPYING, MODIFICATION, DISTRIBUTION, PUBLIC  PERFORMANCE, OR PUBLIC DISPLAY OF OR
# THROUGH USE  OF THIS  SOURCE CODE  WITHOUT  THE EXPRESS WRITTEN CONSENT OF COMPANY IS STRICTLY PROHIBITED,
# AND IN VIOLATION OF APPLICABLE LAWS AND INTERNATIONAL TREATIES.  THE RECEIPT OR POSSESSION OF  THIS SOURCE
# CODE AND/OR RELATED INFORMATION DOES NOT CONVEY OR IMPLY ANY RIGHTS TO REPRODUCE, DISCLOSE OR DISTRIBUTE
# ITS CONTENTS, OR TO MANUFACTURE, USE, OR SELL ANYTHING THAT IT  MAY DESCRIBE, IN WHOLE OR IN PART.  
#
# FOR U.S. GOVERNMENT CUSTOMERS REGARDING THIS DOCUMENTATION/SOFTWARE
#   These notices shall be marked on any reproduction of this data, in whole or in part.
#   NOTICE: Notwithstanding any other lease or license that may pertain to, or accompany the delivery of,
#   this computer software, the rights of the Government regarding its use, reproduction and disclosure are
#   as set forth in Section 52.227-19 of the FARS Computer Software-Restricted Rights clause.
#   RESTRICTED RIGHTS NOTICE: Use, duplication, or disclosure by the Government is subject to the
#   restrictions as set forth in subparagraph (c)(1)(ii) of the Rights in Technical Data and Computer
#   Software clause at DFARS 52.227-7013.
#
#********************************************************

# This script checks for conflicts on known ports that we need in operations

#*******************************************************
# Change Log
# v1.0 Aug 9, 2018 - doug; pre-check fro STAR-5302


rpm -qV starfish
if [ $? -eq 0 ]; then
	echo "starfish is already installed. Exiting."
	#exit 0
fi

pgcount=`rpm -qa | egrep -c '^postgresql'`
if [[ $pgcount > 0 ]]; then
	echo "postgres is already installed. This may conflict with bundled version. Checking."
	syscnt=`systemctl -a | grep -c 'postgresql.*service'`
	if [[ $syscnt > 0 ]]; then
		echo -e "[1mPostgres service is running. This should be disabled.\n\n[0m"
	else
		echo Postgres service is not running. should be ok.
	fi
fi

echo "checking open ports"

for port in 80 443 8080; do
	stuff=`lsof -i :$port`
	if [[ $? == 0 ]]; then 
		echo -e "[1mA web service is running on port $port This will conflict with Starfish. [0m"
		echo -e "$stuff" | head -n 2
		echo "-----"
	fi
done

for port in 5432 5433; do
	# echo "checking port $port"
	stuff=`lsof -i :$port`
	if [[ $? == 0 ]]; then 
		echo -e "[1mSomething is running on port $port. This will conflict with Postgres. [0m"
		echo -e "$stuff" | head -n 2
		echo "-----"
	fi
done

echo "checking starfish API ports. Any thing below here may end up conflicting with Starfish services API."
for port in `seq 30000 30100`; do
	# echo "checking port $port"
	stuff=`lsof -i :$port` 
	if [[ $? == 0 ]]; then
		echo "[1m A service is using port $port. This could conflict with Starfish:[0m"
		echo -e "$stuff" | head -n 2
		echo "------"
	fi
done
