#!/usr/bin/env bash
#
# catalog-chan
# version 1.0
#
# / what a shame. /
#

# usage
USAGE="\n\tLatest Sequence - get latest log sequence for a database.\n\n \
\tlasq.sh [-h] -s <ORACLE_SID>\n\n \
\t-h - print this message\n \
\t-s - database name\n\n \
\tExample:\n\n \
\t- get latest sequence for database orcl:\n\n \
\t  lasq.sh -s orcl\n"

# options
while getopts 'hs:' opt
do
  case $opt in
  h) echo -e "${USAGE}"
     exit 0
     ;;
  s) SID=${OPTARG}
     ;;
  :) echo "option -$opt requires an argument"
     ;;
  *) echo -e "${USAGE}"
     exit 1
     ;;
  esac
done
shift $(($OPTIND - 1))

# variables
CATALOGS="catalog1 catalog2"
LOGINS="user/pwd@catalog1 user/pwd@catalog2"

# env check
if [[ ${#ORACLE_BASE} == 0 ]]; then
  printf "ORACLE_BASE is not set! Manually set it via export command.\n"
  exit 1
fi
if [[ -z ${SID} ]]; then
  printf "<ORACLE_SID> is mandatory. Use -h.\n"
  exit 1
fi

# red color
function red () {
  RED=$(echo -e "\e[91m$1\e[0m")
  echo $RED
}

# latest sequence
function catalogseq () {
   printf "
   set head off verify off trimspool on feed off line 2000
   set numformat 9999999999999999999
   col seq word_wrapped
   select max(sequence#) seq
          from rc_backup_redolog a
          where db_name = upper ('${1}')
          and a.dbinc_key =
          (select b.dbinc_key
          from rc_database_incarnation b
          where b.status = upper ('current') and b.name = upper ('${1}'));
   exit
   " | sqlplus -s ${2} | grep . | sed 's/ //g'
}

# tns check
for cat in ${CATALOGS}
do
   TNSPING="$(tnsping ${cat} | tail -1)"
   if [[ $TNSPING =~ "OK" ]]; then
      :
   elif [[ $TNSPING =~ "timed out" ]]; then
      ERRMSG="It looks like ${cat} is not reachable.\n"
      printf "${ERRMSG}"
      exit 1
   elif [[ $TNSPING =~ "Failed to resolve" ]]; then
      ERRMSG="It appears that ${cat} is not in tnsnames.ora file.\n"
      printf "${ERRMSG}"
      exit 1
   else
      ERRMSG="Unknown network-related error.\n"
      printf "${ERRMSG}"
      exit 1
   fi
done

# sequence
for c in ${LOGINS}
do
   SEQ="$(catalogseq ${SID} ${c})"
   CAT="$(echo ${c} | cut -d@ -f2)"
   case ${SEQ} in
   [0-9]*)      printf "$(red ${CAT}): Latest sequence for ${SID} is ${SEQ}.\n"
                ;;
   *)           printf "$(red ${CAT}): Couldn't find sequence.\n"
                ;;
   esac
done

# exit
exit 0
