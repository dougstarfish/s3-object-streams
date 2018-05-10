#!/bin/bash

set -euo pipefail

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

#*******************************************************
# Change Log
# v1.04 May 3, 2018 - Updated parsing of output to accomodate multiple lines  
#                   - Added emailfrom option and variable.
# v1.05 May 4, 2018 - Updated console output
#                   - Added verification that duplicates were found before moving on
#                   - Report on top 20 duplicates in terms of count and size
# v1.06 May 8, 2018 - set +e before mailing so it doesn't crash
#                   - Add logging

# Set variables
readonly VERSION="1.06 May 4, 2018"
readonly PROG="${0##*/}"
readonly SFHOME="${SFHOME:-/opt/starfish}"
readonly LOGDIR="$SFHOME/log/${PROG%.*}"
readonly SF="${SFHOME}/bin"
readonly NOW=$(date +"%Y%m%d-%H%M%S")
readonly LOGFILE="${LOGDIR}/$(basename ${BASH_SOURCE[0]} '.sh')-$NOW.log"

# global variables
EMAILTO=""
EMAILFROM="root"
LOG_EMAIL_CONTENT=""
VERBOSE=0
CHECK_UNIQUE_FILE_SIZE=""
JSON="--json"
MIN_SIZE="10M"
RESUME_FROM_DIR=""
TMP_DIR=""
VOLUMES=""
DUPLICATE_FILE_PATH=""
HIDDEN_OPTIONS=""

logprint () {
# logprint routine called to write to log file. This log is separate from the one called via the --log option at the command line. That log file is for sending results to a log - this log file is for tracking execution of the script
  echo "$(date +%D-%T): $*" >> $LOGFILE
}

email_alert() {
  (echo -e "$1") | mailx -s "$PROG Failed!" -a $LOGFILE -r $EMAILFROM $EMAILTO
}

email_notify() {
  (echo -e "$1") | mailx -s "$PROG Completed Successfully" -r $EMAILFROM $EMAILTO
}

fatal() {
  echo "$@"
  exit 1
}

check_parameters_value() {
  local param="$1"
  [ $# -gt 1 ] || fatal "Missing value for parameter ${param}"
}

usage() {
  cat <<EOF

Duplicate_check wrapper script
$VERSION

This script is a wrapper that is designed to enhance the user experience of the built-in duplicate_check tool.  This script can be called from cron, and it can email or log the results for further analysis. Execution log can be found at $LOGDIR

The duplicate_check tool that $PROG invokes is designed to calculate the total size of duplicated files.
It can operate across all starfish volumes or specific volume.
The calculation is performed over five phases:
 - Find all rows with a unique file size
 - Quick-hash all the candidate duplicates
 - Find entries with non unique quick-hash
 - Calculate a full hash of those entries
 - Find files with same hash

USAGE:
$PROG [--email AND/OR --log] [options] VOL:PATH [VOL:PATH ...]]

NOTE - One or both of the '--email' and '--log' options is required!

Required:
  --email 		Destination email(s) address (ex. --email "a@a.pl b@b.com")
                        If more than one recipient, then quotes are needed around the emails

         --- AND/OR ---

  --log			Save email contents to a specified file (it must be a path to not existing file in existing directory). 
                        It may contain datatime parts (see 'man date'), for example:
                        --log "/opt/starfish/log/$PROG-%Y%m%d-%H%M%S.log"
                        NOTE: When running from cron, escape the % chars using the following
                        --log "/opt/starfish/log/$PROG-\%Y\%m\%d-\%H\%M\%S.log"

options:
  -h, --help            show this help message and exit
  -v, --verbose         verbose output
  --check-unique-file-size
                        Runs additional step at beginning to run quick hash only on files with non unique size.
                        It may lead to performance gain when there is small number of files with non unique
                        size (for example when --min-size is set to large number like 1G). It may be slower
                        than default approach when number of entries with non unique size is large.
  --min-size SIZE       Minimal file size. Default: 10M
  --resume-from-dir DIR
                        Path to directory with logs from previous execution
  --tmp-dir DIR         Directory used to keep temporary files
  --from <email>	Specify email from address (default=root)

Examples:
$PROG --log "/opt/starfish/log/${PROG%.*}-%Y%m%d-%H%M%S.log" --check-unique-file-size sfvol:
This will run the duplicate checker, running a quick hash on files located on the sfvol: volumes that have a non unique size. Results will be sent to the "/opt/starfish/log/${PROG%.*}-%Y%m%d-%H%M%S.log" file

$PROG --min-size 25M --email "a@a.pl, b@b.com" sfvol1: sfvol2:
This will run the duplicate checker on both sfvol1 and sfvol2 volumes, looking for duplicates with a minimum size of 25M, and emailing the results to users a@a.pl, b@b.com
 
$PROG --email "user@company.com"
This will run the duplicate checker on all Starfish volumes, emailing results to user@company.com.


EOF
  exit 1
}

parse_input_parameters() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    "--email"|"--email")
      check_parameters_value "$@"
      shift
      EMAILTO=($1)
      ;;
    "--from")
      check_parameters_value "$@"
      shift
      EMAILFROM=$1
      ;;
    "-v"|"--verbose")
      VERBOSE=1
      ;;
    "--log") 
      check_parameters_value "$@"
      shift
      LOG_EMAIL_CONTENT=$(date +"$1")
      ;;
    "--check-unique-file-size")
      CHECK_UNIQUE_FILE_SIZE="--check-unique-file-size"
      ;;
    "--json")
      JSON="--json"
      ;;
    "--min-size")
      check_parameters_value "$@"
      shift
      MIN_SIZE="$1"
      ;;
    "--resume-from-dir")
      check_parameters_value "$@"
      shift
      RESUME_FROM_DIR="--resume-from-dir=$1"
      ;;
    "--tmp-dir")
      check_parameters_value "$@"
      shift
      TMP_DIR="--tmp-dir=$1"
      ;;
    "--tag-batch-size")
      check_parameters_value "$@"
      HIDDEN_OPTIONS="$HIDDEN_OPTIONS $@"
      shift
      ;;
    *)
      if [[ ${1:0:1} != "-" ]]; then
        VOLUMES="$VOLUMES $1"
      fi
      ;;
    esac;
    shift
  done
  logprint "email to: $EMAILTO"
  logprint "email from: $EMAILFROM"
  logprint "log email content: $LOG_EMAIL_CONTENT"
  logprint "verbose: $VERBOSE"
  logprint "check_unique_file_size: $CHECK_UNIQUE_FILE_SIZE"
  logprint "json: $JSON"
  logprint "min_size: $MIN_SIZE"
  logprint "resume_from_dir: $RESUME_FROM_DIR"
  logprint "tmp_dir: $TMP_DIR"
  logprint "volumes: $VOLUMES"
  if [[ "$HIDDEN_OPTIONS" != "" ]]; then
    logprint "hidden options: $HIDDEN_OPTIONS"
  fi
}

verify_required_params() {
if [[ "$EMAILTO" == "" ]] && [[ "$LOG_EMAIL_CONTENT" == "" ]]; then
  logprint "Neither email or log was specified, exiting.."
  echo "Neither email or log was specified, exiting.."
  usage
  exit 1
fi    
}

build_cmd_line() {
  MIN_SIZE_CMD="--min-size=$MIN_SIZE"
  CMD_TO_RUN="$SF/duplicate_check $CHECK_UNIQUE_FILE_SIZE $JSON $MIN_SIZE_CMD $RESUME_FROM_DIR $TMP_DIR $HIDDEN_OPTIONS $VOLUMES"
  logprint "command to run: $CMD_TO_RUN"
}

run_duplicate_check() {
  local errorcode
  STARTTIME=$(date +"%H:%M:%S %m/%d/%Y")
  set +e
  mapfile -t CMD_OUTPUT < <( $CMD_TO_RUN 2>&1 )
  errorcode=$?
  set -e
  logprint "==========="
  logprint "${CMD_OUTPUT[@]}"
  logprint "==========="
  if [[ $errorcode -ne 0 ]]; then
    echo -e "duplicate_check command failed. Output follows: ${CMD_OUTPUT[@]}"
    logprint "duplicate_check command failed. Output follows: ${CMD_OUTPUT[@]}"
    email_alert "duplicate_check command failed. Output follows: ${CMD_OUTPUT[@]}"
    exit 1
  fi
  ENDTIME=$(date +"%H:%M:%S %m/%d/%Y")
}

parse_output(){
  for line in "${CMD_OUTPUT[@]}"
  do
    if [[ ${line:0:1} == "{" ]]; then
      IFS=','
      read -ra OUTPUTARRAY <<< "$line"
      unset IFS
      logprint "${OUTPUTARRAY[@]}"
    fi
  done
  COUNT=${OUTPUTARRAY[0]:10}
  DUPLICATE_FILE=${OUTPUTARRAY[1]:20}
  SKIP_COUNT=${OUTPUTARRAY[2]:16}
  SIZE_WITH_ORIGINAL_FILE=${OUTPUTARRAY[3]:28}
  SIZE=${OUTPUTARRAY[4]:9:${#OUTPUTARRAY[4]}-10}
  logprint "Count: $COUNT"
  logprint "Duplicates file: $DUPLICATE_FILE"
  logprint "Skip Count: $SKIP_COUNT"
  logprint "Size with original files: $SIZE_WITH_ORIGINAL_FILE"
  logprint "Size: $SIZE"
  if [[ $COUNT == 0 ]]; then
    logprint "No duplicates found. Exiting.."
    echo "No duplicates found. Exiting.."
    exit 1
  fi
}

extract_path_and_filename() {
  IFS='/'
  read -ra PATHARRAY <<< "$DUPLICATE_FILE"
  unset IFS
  PATHARRAYLENGTH=${#PATHARRAY[@]}
  FILENAME=${PATHARRAY[$PATHARRAYLENGTH-1]}
  for ((i=1; i<($PATHARRAYLENGTH-1); i++))
  do
    DUPLICATE_FILE_PATH="$DUPLICATE_FILE_PATH/${PATHARRAY[i]}"
  done
}

determine_scanned_volumes() {
  if [[ $VOLUMES = "" ]]; then
    local volume_array
    local tmp_var
    read -ra volume_array <<< `cat $DUPLICATE_FILE_PATH/02*`
    for i in "${volume_array[@]}"
    do
      IFS=','
      read -ra tmp_var <<< "$i"
      unset IFS
      if [[ ${tmp_var[0]} != "volume" ]]; then
        VOLUMES="$VOLUMES ${tmp_var[0]}"
      fi
    done
    logprint "Volume(s) not specified, so the following were scanned: $VOLUMES"
  fi
}

generate_email_content() {
  local total_files
  local total_size
  local sizegb
  local sizewithoriginalgb
  local percent_dup_size
  local percent_dup_count
  local subject
  local body
  local vol_files
  local vol_size
  declare -A dup_size
  declare -A dup_count
  logprint "Generating email/log content"
  read -a volume_array <<< "$VOLUMES"
  for i in "${volume_array[@]}"
  do
    vol_files=`sf query $i -H --format "rec_aggrs.files" --maxdepth=0`
    vol_size=`sf query $i -H --format "rec_aggrs.size" --maxdepth=0`
    total_files=$((total_files+vol_files))
    total_size=$((total_size+vol_size))
  done
  sizegb=`awk "BEGIN {print ($SIZE/(1024*1024*1024))}"`
  sizewithoriginalgb=`awk "BEGIN {print ($SIZE_WITH_ORIGINAL_FILE/(1024*1024*1024))}"`
  percent_dup_size=`awk "BEGIN {print ($SIZE * 100 / $total_size)}"`
  percent_dup_count=`awk "BEGIN {print ($COUNT * 100 / $total_files)}"`
  DUPLICATE_FILE="${DUPLICATE_FILE:1:-1}"
  for unique_hash in $(cat $DUPLICATE_FILE | awk -F',' 'seen[$4]++== 1' | awk -F',' {'print $4'})
  do
    hash_array+=($unique_hash)
    dup_count[$unique_hash]=$(awk -F',' -v hash=$unique_hash '{if ($4 == hash) { dc++ }} END { print dc }' $DUPLICATE_FILE)
    dup_size[$unique_hash]=$(awk -F',' -v hash=$unique_hash '{if ($4 == hash) { ds+=$3 }} END { print ds }' $DUPLICATE_FILE)
  done
  for i in ${hash_array[@]}
  do
    fn=$(awk -F',' -v hash=$i '{if ($4 == hash) {print $2}}' $DUPLICATE_FILE | awk -F'/' 'seen[$NF]++== 1 {print $NF}')
    ifsize=$((${dup_size[$i]} / ${dup_count[$i]}))
    echo "$fn,$ifsize,${dup_count[$i]},${dup_size[$i]}" >> $DUPLICATE_FILE_PATH/${PROG%.*}-report.tmp
  done
  set +e
  toptwentycount=$(sort -rVt, -k3 $DUPLICATE_FILE_PATH/${PROG%.*}-report.tmp | awk -F',' '{print "File " $1 " with size of " $2 " bytes has " $3 " duplicates, occupying " $4 " bytes of space "}' | head -n 20)
  toptwentysize=$(sort -rVt, -k4 $DUPLICATE_FILE_PATH/${PROG%.*}-report.tmp | awk -F',' '{print "File " $1 " with size of " $2 " bytes has " $3 " duplicates, occupying " $4 " bytes of space "}' | head -n 20)
  set -e
  SUBJECT="Duplicate check report for Starfish volumes ($VOLUMES) - $COUNT Duplicates over $MIN_SIZE, occupying $sizegb GB"
  BODY="
Duplicate check started at $STARTTIME, and took $SECONDS seconds to finish. 

- $total_files files were scanned.
- There were $COUNT duplicate files found on volumes ($VOLUMES ) that were over $MIN_SIZE, and those duplicates occupy $sizegb GB of space.
- The size of the duplicates plus their original files is $sizewithoriginalgb GB.
- Duplicates over $MIN_SIZE occupy $percent_dup_count% of the total file count, and occupy $percent_dup_size% of the total file size within $VOLUMES

The list of duplicate files can be found at: $DUPLICATE_FILE

TOP TWENTY DUPLICATE FILES BY COUNT:
$toptwentycount


TOP TWENTY FILES BY AGGREGATE SIZE:
$toptwentysize
"
  if [ -n "$LOG_EMAIL_CONTENT" ]; then
    logprint "Writing output to logfile"
    echo -e "$SUBJECT" > $LOG_EMAIL_CONTENT
    echo -e "$BODY" >> $LOG_EMAIL_CONTENT
  fi

  if [ -n "$EMAILTO" ]; then
    logprint "Emailing results to $EMAILTO"
    (echo -e "$BODY") | mailx -s "$SUBJECT" -r $EMAILFROM $EMAILTO
  fi
}

# if first parameter is -h or --help, call usage routine
if [ $# -gt 0 ]; then
  [[ "$1" == "-h" || "$1" == "--help" ]] && usage
fi

# Check if logdir and logfile exists, and create if it doesnt
[[ ! -e $LOGDIR ]] && mkdir $LOGDIR
[[ ! -e $LOGFILE ]] && touch $LOGFILE
logprint "---------------------------------------------------------------"
logprint "Script executing"
logprint "Version: $VERSION"

# Check that mailx exists
logprint "Checking for mailx"
if [[ $(type -P mailx) == "" ]]; then
  logprint "Mailx not found, exiting.."
  echo "mailx is required for this script. Please install mailx with yum or apt-get and re-run" 2>&1
  exit 1
else
   logprint "Mailx found"
fi

echo "Step 1: Parse input parameters"
parse_input_parameters $@
echo "Step 1 Complete"
echo "Step 2: Verify prereq's"
verify_required_params
echo "Step 2 Complete"
echo "Step 3: Build command line"
build_cmd_line
echo "Step 3 Complete"
echo "Step 4: Run duplicate check"
run_duplicate_check
echo "Step 4 complete"
echo "Step 5: Parse output"
parse_output
echo "Step 5 complete"
echo "Step 6: Post processing"
extract_path_and_filename
determine_scanned_volumes
echo "Step 6 complete"
echo "Step 7: Generate email"
generate_email_content
echo "Step 7 complete"
echo "Script complete"

