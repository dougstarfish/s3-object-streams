#!/bin/sh
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

gawk -F, '
BEGIN {
	# gawk 4 feature - sort by array values descending
	PROCINFO["sorted_in"] = "@val_num_desc"
}
NR > 1 {
	dupcnt[$4]++
	dupsize[$4] = $3; 
	totalsize += $3
	n = split(tolower($2), basename, "/")
	o = split(basename[n], extarr, ".")
	if (o > 1) {
		ext = extarr[o]
		# print "ext of", basename[n], "is", ext
		extensioncnt[ext] ++
		extensionsize[ext] += $3
		extnum[ext] ++
	}
} 
END {
	print length(dupcnt), "dups of", NR, "entries"; 
	for (c in dupcnt) sumdupsize += dupsize[c]; 
	print totalsize / 1000/1000/1000 ,"GB of totalspace consumed by all copies"; print (sumdupsize) / 1000/1000/1000, "GB of unique space"
	printf("%.1f%% overhead\n",  (totalsize / sumdupsize * 100.0) - 100.0)
	print "-----"
	print "Top extensions by cnt"
	i = 0
	for (k in extensioncnt) {
		printf("%-8s %8d   ", k, extensioncnt[k]) 
		i++
		if (i % 4 == 0) printf("\n")
	}
	printf("\n")
	print "Top extensions by size (GB)"
	i = 0
	printf("%-8s %7s %7s  ", "Extname", "GBtotal", "AvgSzMB");
	printf("%-8s %7s %7s  ", "Extname", "GBtotal", "AvgSzMB");
	printf("%-8s %7s %7s\n", "Extname", "GBtotal", "AvgSzMB");
	for (k in extensionsize) {
		printf("%-8s %7.1f %7.0f  ", k, extensionsize[k]/ 1000.0/1000.0/1000.0, extensionsize[k] / extnum[k] / 1000 / 1000) 
		i++
		if (i % 3 == 0) printf("\n")
	}
	printf("\n")
} 
' $1/duplicated_files_list_*.csv

