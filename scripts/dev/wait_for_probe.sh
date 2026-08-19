#!/bin/bash
# Blocks until the watched work is gone, then exits 0. Two modes:
#
#     scripts/dev/wait_for_probe.sh --pid 12345 [poll_seconds]      # preferred
#     scripts/dev/wait_for_probe.sh '[C]hargerAudit.tscn' [poll_s]  # fallback
#
# ⚠️ WHY THIS FILE EXISTS: A `pgrep -f` POLL LOOP CAN WAIT ON ITSELF, FOREVER.
#
# `pgrep -f` scans full command lines and excludes only its own PID -- never
# the shell that spawned it. A poller written inline as
#
#     while pgrep -f "path . --import" >/dev/null; do sleep 10; done
#
# matches its OWN `bash -c ... while pgrep -f "path . --import" ...` line, so
# the condition never goes false. Measured here on 19 aout 2026: ELEVEN such
# loops outlived their work by 1 h 44 with zero godot processes alive. The
# failure is silent and looks exactly like work still in progress, which is
# what makes it expensive.
#
# The bracket idiom -- `[C]hargerAudit` is a regex matching "ChargerAudit",
# while the poller's own line contains "[C]hargerAudit" WITH brackets, which
# that regex does not match -- fixes the SELF match. It is necessary and it is
# NOT sufficient, measured the same day: it does nothing about an ANCESTOR
# shell whose command line happens to carry the plain text, which under the
# agent Bash tool is the common case (several commands share one `bash -c`).
# So this script also walks /proc and drops every ancestor PID from the match.
#
# --pid mode has neither problem and is the right default whenever the launch
# site can capture `$!`. Reach for the pattern only when it cannot.
set -u

exclude_ancestors() { # stdin: pids, stdout: pids that are not us or an ancestor
	local anc=" $$ $PPID " p=$PPID
	while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
		p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null) || break
		[ -n "$p" ] && anc="$anc$p "
	done
	local pid
	while read -r pid; do
		case "$anc" in *" $pid "*) ;; *) echo "$pid" ;; esac
	done
}

if [ "${1:-}" = "--pid" ]; then
	TARGET=${2:?usage: --pid PID [poll_seconds]}
	INTERVAL=${3:-10}
	while kill -0 "$TARGET" 2>/dev/null; do sleep "$INTERVAL"; done
	exit 0
fi

PATTERN=${1:?usage: wait_for_probe.sh --pid PID | PATTERN [poll_seconds]}
INTERVAL=${2:-10}
case "$PATTERN" in
	\[*) ;;
	*) echo "wait_for_probe.sh: refusing unbracketed pattern '$PATTERN'." >&2
	   echo "  Write '[${PATTERN:0:1}]${PATTERN:1}' -- see this file's header." >&2
	   exit 2 ;;
esac
while [ -n "$(pgrep -f -- "$PATTERN" 2>/dev/null | exclude_ancestors)" ]; do
	sleep "$INTERVAL"
done
