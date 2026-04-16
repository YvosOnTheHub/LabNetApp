#!/bin/sh

# mariadb_mysql.sh
#
#
# Pre- and post-snapshot execution hooks for MariaDB and MySQL with NetApp Astra Control.
# Tested with MySQL 8.0.29 (deployed by Bitnami helm chart 9.1.7)/MariaDB 10.6.8 (deployed by Bitnami helm chart 11.0.13) and NetApp Astra Control Service 22.04.
#
# args: [pre|post]
# pre: Flush all tables with read lock
# post: Take database out of read-only mode
#

# Complex shell commands are difficult to get right through a remote execution api.
# For something like this obtuse procedure, an alternative approach is to mount a
# script into the container.

# To quiesce and hold mariadb/mysql databases we need to iterate over each one
# and open a client connection to it, then issue a 'flush tables with read lock'
# and then sleep, holding the connection open indefinitely.  When the snapshot
# is done, the read lock is released by terminating the mysql process (from
# outside this script)

# DB variants & config vars:
#
# It does not matter significantly if we are using Maria or MySQL, but in general the assumption
# is that if any of the relevant environment variables starting with 'MARIADB' are set, we're
# dealing with Maria and we should prefer those variables over the mysql versions.

#
# Invocation & auth variables
#
optfile="/tmp/freeze_opts_$$"
hostname="localhost"
mysql="mysql --defaults-extra-file=${optfile}"
user="root"
password=""

#
# Operational parameters and commands
#
sleeptime=86400
sleep="SELECT SLEEP(${sleeptime})"
flush="FLUSH TABLES WITH READ LOCK; ${sleep}"

#
# Error codes
# These are important for finding out what went wrong from the other end of the k8s api
# Only change existing ones (delete deprecated and shift codes, frex) across version boundaries.
#
ebase=20
#deprecated: $((ebase+1))
#deprecated: $((ebase+2))
efilecreate=$((ebase+3))
esleeptime=$((ebase+4))
ekill=$((ebase+5))
eaccess=$((ebase+6))
eusage=$((ebase+7))
ebadaction=$((ebase+8))

#
# setup_auth figures out what to use for user and password and writes the options file out
#
# The password handling here is based on the conventions established by the Bitnami MariaDB & MySQL
# docker images.  We may need to expand this to account for other usage models but as of the time of
# writing don't know of anything else vaguely standard in the container world.
#
# Documentation:
# https://github.com/bitnami/bitnami-docker-mariadb
# https://github.com/bitnami/bitnami-docker-mysql
#
setup_auth() {
  setup_user
  setup_pass
  setup_hostname
  write_opt_file
  rc=$?
  return ${rc}
}

#
# setup_user overrides defaults with env vars if set
#
setup_user() {
  if [ -n "${MARIADB_ROOT_USER}" ] ; then
    user=${MARIADB_ROOT_USER}
  elif [ -n "${MYSQL_ROOT_USER}" ] ; then
    user=${MYSQL_ROOT_USER}
  fi
}

#
# setup_hostname: intentionally does not use $HOSTNAME.
# In Kubernetes pods, HOSTNAME is always set to the pod name, which forces TCP connections
# instead of the Unix socket. TCP root login may be restricted or behave differently from
# socket-based root@localhost. All hook operations run inside the container, so the Unix
# socket (localhost) is always available and is the reliable choice.
#
setup_hostname() {
  : # no-op: always connect via Unix socket
}

# setup_pass_file optionally overrides defaults and vars with a file
#
setup_pass_file() {
  if [ -n "${MARIADB_ROOT_PASSWORD_FILE}" ] ; then
    password=$(cat "${MARIADB_ROOT_PASSWORD_FILE}")
  elif [ -n "${MYSQL_ROOT_PASSWORD_FILE}" ] ; then
    password=$(cat "${MYSQL_ROOT_PASSWORD_FILE}")
  fi
}

#
# setup_pass figures out if we have a password in an env var to use
#
setup_pass() {
  setup_pass_file
  if [ -n "${password}" ]; then
    return
  fi
  if [ -n "${MARIADB_ROOT_PASSWORD}" ] ; then
    password=${MARIADB_ROOT_PASSWORD}
  elif [ -n "${MYSQL_ROOT_PASSWORD}" ] ; then
    password=${MYSQL_ROOT_PASSWORD}

  # if only MARIADB_MASTER_ROOT_PASSWORD is set, then it's a replication db ("sl*v*")
  elif [ -n "${MARIADB_MASTER_ROOT_PASSWORD}" ] ; then
    password=${MARIADB_MASTER_ROOT_PASSWORD}

  elif [ -n "${MYSQL_MASTER_ROOT_PASSWORD}" ] ; then
    password=${MYSQL_MASTER_ROOT_PASSWORD}
  fi
}

#
# test_access makes sure we can issue commands to the database
#
# the real freeze processes are started in the background and we can't ensure that they
# were started based on return codes.  Make sure we can execute commands by using a simple one here.
test_access() {
  ${mysql} -A -e 'show processlist;' >/dev/null 2>&1
  rc=$?
  if [ "${rc}" -ne "0" ] ; then
    return ${eaccess}
  fi
  return 0
}

#
# write_opt_file writes out a temporary authentication options file for the mysql client
#
write_opt_file() {
  echo "[client]" > ${optfile}
  echo "user=${user}" >> ${optfile}
  if [ -n "${password}" ] ; then
    echo "password=${password}" >> ${optfile}
  fi
  if [ ! -e ${optfile} ] ; then
    return ${efilecreate}
  fi
  #make sure opt file is not world write-able 
  chmod o-w ${optfile} 
  rc=$?
  if [ "${rc}" -ne "0" ] ; then
	return ${efilecreate}
  fi

  # Success
  return 0
}

#
# cleanup deletes any temporary files
#
cleanup() {
  rm -f ${optfile}
}

#
# freeze executes the actual freeze command for a specified database
#
freeze() {
  db=$1

  echo "freezing ${db}.."

  ${mysql} "${db}" -e "${flush}" >/dev/null 2>&1 &
  return $?
}

#
# freeze_all issues freezes for each database
#
freeze_all() {
  rc=0
  for i in $(${mysql} -e 'show databases' | grep -v Database); do
    freeze "${i}"
    rc=$?
    if [ ${rc} -ne 0 ] ; then
      echo "Error freezing ${i}"
      break
    fi

    wait_for_sleeper_to_start "${i}"
    rc=$?
    if [ ${rc} -ne 0 ] ; then
      echo "Error flushing database ${i}"
      break
    fi
  done
  return ${rc}
}

#
# wait for sleeper waits up to a timeout for a sleep process to start
#
wait_for_sleeper_to_start() {
  db=$1

  searching=0
  timeout=60
  while [ "${searching:-0}" -eq 0 ]
  do
    sleep 1
    searching=$(${mysql} -N -A -e "SHOW PROCESSLIST" | grep -c "User sleep")

    timeout=$((timeout-1))
    if [ ${timeout} -eq 0 ]; then
      echo "timed out waiting for sleeper for ${db}"
      return ${esleeptime}
    fi
  done
  return 0
}

# wait for sleepers to end, however, if they do not end within 45 minutes, kill them
# polls every 10 seconds 270 times to arrive at 2700 seconds which is 45 minutes
# snapshots with hooks are limited to 30 minutes, 45 minutes provides a buffer for that to finish before timing out
# under normal operation, the "thaw" option will kill these sleepers which will allow this to exit normally before the 45 minute timeout
wait_for_sleepers_to_end() {
  searching=1
  timeout=270
  while [ "${searching:-0}" -ne 0 ]
  do
    sleep 10
    searching=$(${mysql} -N -A -e "SHOW PROCESSLIST" | grep -c "User sleep")

    timeout=$((timeout-1))
    if [ ${timeout} -eq 0 ]; then
      echo "timed out waiting for all sleepers"
      kill_sleepers
      return ${esleeptime}
    fi
  done
  return 0
}

#
# kill_sleepers shuts down all sleeping lock threads
#
kill_sleepers() {
  for sleeper in $(${mysql} -N -A -e "SHOW PROCESSLIST" | grep "User sleep" | cut -f1); do
    echo "killing sleeper ${sleeper}"
    # this complains about losing connection, but the error code can be trusted
    if ! ${mysql} -A -e "KILL ${sleeper};"; then
      echo "Error killing sleeping connection ${sleeper}"
      return ${ekill}
    fi
  done

  return 0
}

#
# thaw resumes all databases
#
thaw() {
  kill_sleepers
  rc=$?
  if [ ${rc} -ne 0 ]; then
    echo "Error resuming databases"
    return ${rc}
  fi
}

#
# prepare_for_action sets up common parameters and auth for a primary action
#
prepare_for_action() {
  setup_auth
  rc=$?
  if [ ${rc} -ne 0 ] ; then
    echo "Error during setup"
    return ${rc}
  fi

  test_access
  rc=$?
  if [ ${rc} -ne 0 ]; then
    echo "Problem accessing database"
    return ${rc}
  fi
}

#
# "main"
#
action=$1
if [ -z "${action}" ]; then
  echo "Usage: $0 <pre|post>"
  exit ${eusage}
fi

if [ "${action}" != "pre" ] && [ "${action}" != "post" ]; then
  echo "Invalid subcommand: ${action}"
  exit ${ebadaction}
fi

prepare_for_action
rc=$?
if [ ${rc} -ne 0 ]; then
  echo "Error setting up for ${action}"
  cleanup
  exit ${rc}
fi

if [ "${action}" = "pre" ]; then
  freeze_all
  rc=$?
  if [ ${rc} -ne 0 ]; then
    echo "Error freezing databases"
    # fall through to cleanup
    kill_sleepers
  else
    echo "__Hook_Ready_State__"
    # Exit immediately. The background mysql processes holding FTWRL + SLEEP
    # survive in the container (reparented to PID 1). Trident Protect will
    # take the snapshot, then launch the post-hook to kill the sleepers.
  fi
else
  thaw
  rc=$?
  if [ ${rc} -ne 0 ] ; then
    echo "Error thawing databases"
    # fall through to cleanup
  fi
fi

cleanup
exit ${rc}
