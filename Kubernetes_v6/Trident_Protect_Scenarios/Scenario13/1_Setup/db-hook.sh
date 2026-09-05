#!/bin/sh
#
# In-guest pre/post snapshot hook for MariaDB on Alpine.
# Called via qemu-guest-agent guest-exec from the virt-launcher compute container.
#
# args: [pre|post]
# pre:  FLUSH TABLES WITH READ LOCK and hold the connection with SLEEP
# post: KILL the sleeper so the lock is released
#
# The pre action must exit immediately. The background mariadb client keeps the
# lock until post (or until SLEEP times out). This matches the Verda mysql.sh
# pattern used for container ExecHooks in Scenario 08.
#

mysql="mariadb --socket=/run/mysqld/mysqld.sock"
flush="FLUSH TABLES WITH READ LOCK; SELECT SLEEP(86400)"

freeze() {
  ${mysql} -e "${flush}" >/dev/null 2>&1 &
}

wait_sleeper() {
  timeout=30
  while [ "${timeout}" -gt 0 ]; do
    n=$(${mysql} -N -e "SHOW PROCESSLIST" 2>/dev/null | grep -c "User sleep" || true)
    if [ "${n}" -ge 1 ]; then
      return 0
    fi
    sleep 1
    timeout=$((timeout - 1))
  done
  echo "timed out waiting for MariaDB sleeper"
  return 1
}

kill_sleepers() {
  for id in $(${mysql} -N -e "SHOW PROCESSLIST" 2>/dev/null | grep "User sleep" | awk '{print $1}'); do
    echo "killing sleeper ${id}"
    ${mysql} -e "KILL ${id};" >/dev/null 2>&1 || true
  done
}

action=$1
if [ -z "${action}" ]; then
  echo "Usage: $0 <pre|post>"
  exit 1
fi

if [ "${action}" = "pre" ]; then
  freeze
  if ! wait_sleeper; then
    kill_sleepers
    exit 1
  fi
  echo "__Hook_Ready_State__"
  exit 0
fi

if [ "${action}" = "post" ]; then
  kill_sleepers
  exit 0
fi

echo "Invalid subcommand: ${action}"
exit 1
