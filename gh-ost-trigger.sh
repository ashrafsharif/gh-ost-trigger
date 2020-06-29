#!/bin/bash
# This script will run gh-ost against a table with or without trigger.
# If a trigger exist for the table, it will make a backup of it and restore
# it again after gh-ost finishes.
# Supported options: run, test
# Example: 
#   ./gh-ost-trigger.sh test
#   ./gh-ost-trigger.sh run


#### Update this ###
# This MySQL host
HOST='10.2.0.80'
# Master MySQL server (to restore trigger)
MHOST='10.2.0.82'
# Database
DB='mydatabase'
# Table name
TABLE='tablename'
# Alter statement
ALTER_STMT="MODIFY COLUMN btx_depositoraccno varchar(30) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT '' NOT NULL COMMENT 'Depositor bank account no'"
###

### Setting ###
# gh-ost postpone failover
POSTPONE_CUTOVER=1
# remove trigger if exists (will be restored back once gh-ost finishes)
REMOVE_TRIGGER=1
# gh-ost's max_load=Threads_connected value
MAX_THREADS=40
# gh-ost's chunk size
CHUNK_SIZE=5000
# gh-ost's login dir, e.g, /root/.gh-ost.cnf
GH_OST_LOGIN=/root/.gh-ost.cnf
###

if [ -z "$1" ]; then
        echo 'Option to specify: run, test'
        exit 0
else
        OPTION=$1
fi

PFILE=/tmp/ghost.postpone.flag
TRIGGERDIR=/root/gh-ost/${DB}
TRIGGERFILE=${TRIGGERDIR}/${DB}_${TABLE}_triggers.sql
TMPFILE=/tmp/st
GOT_TRIGGER=0

GH_USER=$(cat ${GH_OST_LOGIN} | grep user | sed 's/^user=//g')
GH_PASS=$(cat ${GH_OST_LOGIN} | grep password | sed 's/^password=//g')

backup_remove_triggers() {
        echo "[Script] Checking if ${DB}.${TABLE} has triggers..."
        check_trigger=$(mysql -u${GH_USER} -p${GH_PASS} -A -Bse "select trigger_name from information_schema.triggers where trigger_schema = '${DB}' and event_object_table = '${TABLE}'")
        if [ ! -z "$check_trigger" ]; then
                GOT_TRIGGER=1
                mysql -u${GH_USER} -p${GH_PASS} -A -Bse "select trigger_name from information_schema.triggers where trigger_schema = '${DB}' and event_object_table = '${TABLE}'" > $TMPFILE

                no_of_triggers=$(cat $TMPFILE | wc -l)
                echo "[Script] Found $no_of_triggers trigger(s).."

		[ -d $TRIGGERDIR ] || mkdir -p $TRIGGERDIR

                echo "[Script] Backing up triggers for table ${DB}.${TABLE}"
                mysqldump --triggers --no-data --no-create-info ${DB} ${TABLE} > ${TRIGGERFILE}

                if [ $? -eq 0 ]; then
                        echo "[Script] Triggers backed up at ${TRIGGERFILE}"
                        echo "[Script] Removing triggers for ${DB}.${TABLE}"

                        if [ -e ${TRIGGERFILE} ]; then
                                for i in $(cat $TMPFILE); do
                                        echo "[Script] Deleting $i on database ${DB} and table ${TABLE} on ${MHOST}"
                                        mysql -u${GH_USER} -p${GH_PASS} -h${MHOST} -P3306 -e "DROP TRIGGER ${DB}.${i}"
                                        [ $? -eq 0 ] && echo '.........OK' || exit 1
                                done
                        fi
                        echo "[Script] We can now safe to perform schema change operation.."
                else
                        echo "[Script] Failed to backup triggers. Nothing is changed. Aborting.."
                        exit 1
                fi

        else
                echo "[Script] Found no trigger.. We can proceed to schema change operation.."
        fi

}

restore_add_triggers () {
        echo "[Script] Restoring triggers on master: ${MHOST}.."
        #mysql -u ${DB} < ${TRIGGERFILE}
	mysql -u${GH_USER} -p${GH_PASS} -h${MHOST} -P3306 ${DB} < ${TRIGGERFILE}

        if [ $? -eq 0 ]; then
                echo "[Script] Triggers restored."
        else
                echo "[Script] Triggers restoration failed. Try to do manually on master:"
                echo "mysql -u${GH_USER} -p${GH_PASS} -h${MHOST} -P3306 ${DB} < ${TRIGGERFILE}"
                exit 1
        fi
}

if [ $OPTION == "run" ]; then

	if [ $POSTPONE_CUTOVER -eq 1 ]; then
        	[ -e $PFILE ] || touch $PFILE
	        echo "[Script] Cutover is postponed until you remove $PFILE"
	else
        	[ -e $PFILE ] && rm -f $PFILE
	        echo '[Script] Cutover will be immediate!!'
	fi

	if [ $REMOVE_TRIGGER -eq 1 ]; then
        	backup_remove_triggers
	fi

	echo "DB             : ${DB}"
	echo "TABLE          : ${TABLE}"
	echo "ALTER STATEMENT: ${ALTER_STMT}"
	echo
	read -p "Confirm to start the exercise? [Y for yes, others for no]:  " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
        	[ $GOT_TRIGGER -eq 1 ] && echo "[Script] You have to restore the triggers manually" && echo "mysql ${DB} < ${TRIGGERFILE}"
	        exit 1
	fi


	echo
	echo "################# Over to gh-ost #################"

gh-ost \
--host=${HOST} \
--conf=${GH_OST_LOGIN} \
--database=${DB} \
--table=${TABLE} \
--alter="${ALTER_STMT}" \
--chunk-size=${CHUNK_SIZE} \
--max-load=Threads_connected=${MAX_THREADS} \
--exact-rowcount \
--concurrent-rowcount \
--verbose \
--execute

#--postpone-cut-over-flag-file=${PFILE} \

	RESULT=$?

	if [ $REMOVE_TRIGGER -eq 1 ]; then
		if [ $GOT_TRIGGER -eq 1 ]; then
	        	restore_add_triggers
		fi
	fi

	[ -e $TMPFILE ] && rm -f $TMPFILE
	echo
	echo "[Script] Process completes"

elif [ $OPTION == "test" ]; then

gh-ost \
--host=${HOST} \g
--conf=${GH_OST_LOGIN} \
--database=${DB} \
--table=${TABLE} \
--alter="${ALTER_STMT}" \
--chunk-size=${CHUNK_SIZE} \
--max-load=Threads_connected=${MAX_THREADS} \
--exact-rowcount \
--concurrent-rowcount \
--verbose

else
	echo '[Script] Unknown option'
	exit 1
fi
