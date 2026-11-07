#!/system/bin/sh
# Switch the active boot slot from the phone itself. Needs root.
#
#   su -c 'sh /data/local/tmp/slot-switch.sh b'    # next boot: slot b (the probe image)
#   su -c 'sh /data/local/tmp/slot-switch.sh a'    # next boot: Android
#   su -c 'sh /data/local/tmp/slot-switch.sh show' # just print the current slot
#
# This only changes the slot /bootloader picks. It does not touch /data.

set -e
slot="$1"

case "$slot" in
  a|b)
    echo "current: $(bootctl get-active-boot-slot 2>/dev/null || echo unknown)"
    bootctl set-active-boot-slot "$slot"
    echo "next boot: slot $slot"
    echo "run 'reboot' to use it"
    ;;
  show|"")
    echo "current: $(bootctl get-active-boot-slot 2>/dev/null || echo unknown)"
    echo "suffix : $(bootctl get-current-slot 2>/dev/null || echo unknown)"
    ;;
  *)
    echo "usage: sh $0 a|b|show" >&2
    exit 2
    ;;
esac
