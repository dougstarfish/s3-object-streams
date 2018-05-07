#!/bin/sh

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

