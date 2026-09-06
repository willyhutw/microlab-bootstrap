#!/bin/bash
#
# The 'join' task has no standalone script: run.sh handles it inline by piping
# the saved join command (~/.kube/<CLUSTER_NAME>-join-cmd, produced by the
# 'init' task) to `sudo bash` on each worker. This file exists only so run.sh's
# `tasks/<task>.sh` existence check passes for `--task join`.
#
echo "!!! 'join' is handled inline by run.sh, not by this script. !!!" >&2
echo "!!! Run: ./run.sh --task join --server <workers> --ssh-user <user> !!!" >&2
exit 1
