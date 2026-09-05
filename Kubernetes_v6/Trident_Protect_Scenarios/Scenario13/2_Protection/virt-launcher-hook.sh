#!/bin/sh
#
# Trident Protect ExecHook script.
# Runs in the KubeVirt virt-launcher *compute* container.
#
# Uses libvirt qemu-agent-command / guest-exec to run
# /usr/local/bin/db-hook.sh inside the guest.
#
# args: [pre|post]
#

set -e

action=$1
if [ -z "${action}" ]; then
  echo "Usage: $0 <pre|post>"
  exit 1
fi

if [ "${action}" != "pre" ] && [ "${action}" != "post" ]; then
  echo "Invalid subcommand: ${action}"
  exit 1
fi

# Non-root virt-launcher (KubeVirt default) uses qemu:///session.
# Privileged / older virt-launcher uses qemu:///system.
LIBVIRT_URI=qemu:///session
DOMAIN=$(virsh -c "${LIBVIRT_URI}" list --name 2>/dev/null | head -n 1 || true)
if [ -z "${DOMAIN}" ]; then
  LIBVIRT_URI=qemu:///system
  DOMAIN=$(virsh -c "${LIBVIRT_URI}" list --name 2>/dev/null | head -n 1 || true)
fi
if [ -z "${DOMAIN}" ]; then
  echo "No libvirt domain found in this virt-launcher pod"
  exit 1
fi
echo "Using libvirt URI: ${LIBVIRT_URI}"
echo "Using libvirt domain: ${DOMAIN}"

CMD=$(printf '{"execute":"guest-exec","arguments":{"path":"/usr/local/bin/db-hook.sh","arg":["%s"],"capture-output":true}}' "${action}")
OUT=$(virsh -c "${LIBVIRT_URI}" qemu-agent-command "${DOMAIN}" "${CMD}")
echo "guest-exec: ${OUT}"

PID=$(echo "${OUT}" | sed -n 's/.*"pid":\([0-9][0-9]*\).*/\1/p')
if [ -z "${PID}" ]; then
  echo "Could not parse guest-exec pid from qemu-agent-command output"
  exit 1
fi

i=0
ST=""
while [ "${i}" -lt 30 ]; do
  ST=$(virsh -c "${LIBVIRT_URI}" qemu-agent-command "${DOMAIN}" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":${PID}}}")
  echo "${ST}" | grep -q '"exited": *true' && break
  sleep 1
  i=$((i + 1))
done

echo "guest-exec-status: ${ST}"
if ! echo "${ST}" | grep -q '"exited": *true'; then
  echo "guest-exec did not exit within 30s"
  exit 1
fi
if ! echo "${ST}" | grep -q '"exitcode": *0'; then
  echo "guest-exec returned a non-zero exit code"
  exit 1
fi

exit 0
