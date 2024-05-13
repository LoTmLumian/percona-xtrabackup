########################################################################
# RENAME TABLE CAUSES BACKUP INCONSISTENT.
########################################################################

. inc/common.sh
start_server
mkdir -p $topdir/backup

pid=
pid_file=
xb_pid=

function wait_pid() {
    # Wait for xtrabackup to suspend
    i=0
    sleep 1
    while [ ! -f "$pid_file" ]
    do
        sleep 1
        i=$((i+1))
        echo "Waited $i seconds for $pid_file to be created"
    done
}

$MYSQL $MYSQL_ARGS -Ns -e " \
DROP DATABASE IF EXISTS test; \
DROP DATABASE IF EXISTS test1; \
CREATE DATABASE test; \
CREATE DATABASE test1; \
CREATE TABLE test.rename_test (id int(11)) ENGINE=INNODB; "

$XB_BIN $XB_ARGS \
  --backup \
  --debug-sync="rename_before_load_tablespaces" \
  --target-dir=$topdir/backup &

pid=$!
pid_file=$topdir/backup/xtrabackup_debug_sync

wait_pid
### XtraBackup will suspend while encounter rename_test.ibd in schema test
$MYSQL $MYSQL_ARGS -Ns -e " \
RENAME TABLE test.rename_test TO test1.rename_test;"
xb_pid=`cat $pid_file`
kill -SIGCONT $xb_pid

run_cmd wait $pid
renamed_ibd=`find $topdir/backup -name "rename_test.ibd"`
stop_server
rm -rf $topdir/backup

if [ "${renamed_ibd}" == "" ]; then
    die "renamed tablespace doesn't exist"
fi
