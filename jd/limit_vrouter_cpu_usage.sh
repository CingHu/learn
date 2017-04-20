#!/bin/sh

mkdir -p /sys/fs/cgroup/cpu/foo
echo 50000 > /sys/fs/cgroup/cpu/foo/cpu.cfs_quota_us

ps -eLo lwp,command | grep -w vrouter | grep -v grep
procs=(`ps -eLo lwp,command | grep -w vrouter | grep -v grep | awk '{print $1}'`)
echo ${procs[@]}
for p in ${procs[@]}; do
    echo $p > /sys/fs/cgroup/cpu/foo/tasks;
done

echo "/sys/fs/cgroup/cpu/foo/cpu.cfs_quota_us: "
cat /sys/fs/cgroup/cpu/foo/cpu.cfs_quota_us
echo "/sys/fs/cgroup/cpu/foo/tasks"
cat /sys/fs/cgroup/cpu/foo/tasks
