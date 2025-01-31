#########################################################################
# Bug #1254227: xtrabackup_56 does not roll back prepared XA transactions
#########################################################################

is_galera && skip_test "Requires a server without Galera support"

start_server

mkfifo $topdir/fifo

$MYSQL $MYSQL_ARGS <$topdir/fifo &

client_pid=$!

# Open the pipe for writing. This is required to prevent cat from closing the
# pipe when stdout is redirected to it

exec 3>$topdir/fifo

cat >&3 <<EOF
CREATE TABLE test.t(a INT) ENGINE=InnoDB;
XA START 'xatrx';
INSERT INTO test.t VALUES(1);
XA END 'xatrx';
XA PREPARE 'xatrx';
EOF

# Let the client complete the above set of statements
vlog "waiting for 3 seconds to ensure transaction on XA prepared state"
sleep 3

xtrabackup --backup --target-dir=$topdir/full

# Terminate the background client
echo "exit" >&3
exec 3>&-
wait $client_pid

xtrabackup --prepare --target-dir=$topdir/full --rollback-prepared-trx

if ! egrep -q "Rollback of trx with id [0-9]+ completed" $OUTFILE ; then
  die "XA prepared transaction was not rolled back!"
fi

stop_server

rm -rf $MYSQLD_DATADIR/*

xtrabackup --copy-back --target-dir=$topdir/full

# The server will fail to start if it has MySQL bug #47134 fixed.
start_server
