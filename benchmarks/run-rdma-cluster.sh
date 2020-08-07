#!/bin/bash 

#set -x

primary="tiger1-1"
declare -a backups=(tiger1-2)

function cleanup {
  killall -9 ermia_SI 2> /dev/null
  rm -rf /dev/shm/*
  rm -rf /mnt/pmem0/ermia/*
  for b in "${backups[@]}"; do
    echo "Kill $b"
    ssh $b "killall -9 ermia_SI 2> /dev/null"
    ssh $b rm -rf /dev/shm/*
    ssh $b rm -rf /mnt/pmem0/ermia/*
  done
}

trap cleanup EXIT

run() {
  num_backups=$1
  t=$2
  policy=$3
  full=$4
  redoers=$5
  redoers=$t
  delay=$6
  nvram=$7
  persist_nvram_on_replay=$8
  read_view_ms=$9

  logbuf_mb=256
  group_commit_size_kb=${10} # RDMA based log ship: latency sensitive to this, not queue length
  group_commit_queue_length=500

  read_view_stat="/dev/shm/ermia_read_view.txt"
  offset_replay=1

  unset GLOG_logtostderr

  echo "----------"
  echo backups:$num_backups thread:$t $policy full_redo=$full redoers=$redoers delay=$delay nvram_log_buffer=$nvram group_commit_size_kb=$group_commit_size_kb
  echo "----------"
  ./run-cluster.sh SI $t 10 $t $logbuf_mb $read_view_stat ycsb ycsb \
    "-tmpfs_dir=/mnt/pmem0/ermia -log_ship_offset_replay=$offset_replay -group_commit -group_commit_queue_length=$group_commit_queue_length -group_commit_size_kb=$group_commit_size_kb -chkpt_interval=1000000 -node_memory_gb=16 -log_ship_by_rdma -truncate_at_bench_start -wait_for_backups -num_backups=$num_backups -persist_policy=sync -read_view_stat_interval_ms=$read_view_ms -read_view_stat_file=$read_view_stat" \
    "-primary_host=$primary -node_memory_gb=16 -log_ship_by_rdma -nvram_log_buffer=$nvram -quick_bench_start -wait_for_primary -replay_policy=$policy -full_replay=$full -replay_threads=$redoers -nvram_delay_type=$delay -persist_nvram_on_replay=$persist_nvram_on_replay -read_view_stat_interval_ms=$read_view_ms -read_view_stat_file=$read_view_stat" \
    "${backups[@]:0:$num_backups}"
  echo
}

sync_clock() {
  sudo ntpd -gq &> /dev/null
  for b in $backups; do
    ssh -o StrictHostKeyChecking=no $b "sudo ntp -gq &> /dev/null"
  done
}

multi_backup_replay() {
  #for policy in pipelined sync; do
  for policy in none; do
    for threads in 1 2 4 8 16; do
      for num_backups in 1; do
        echo "backups=$num_backups $policy redoers=$threads"
        run $num_backups $threads $policy 0 0 clflush 1 0 0 8192
      done
    done
  done
}

no_replay() {
  for delay in clflush; do
    for num_backups in 1; do
      echo "backups=$num_backups no_replay delay=$delay"
      run $num_backups 16 none 0 0 $delay 1 0 0 4096
    done
  done
}

no_nvram() {
  for num_backups in 1; do
    echo "backups:$num_backups thread:16 pipelined full_redo=0 redoers=4 delay=none nvram_log_buffer=0"
    run $num_backups 16 pipelined 0 4 none 0 0 0 4096

    echo "backups:$num_backups thread:16 none full_redo=0 redoers=0 delay=none nvram_log_buffer=0"
    run $num_backups 16 none 0 0 none 0 0 0 4096
  done
}

full_replay() {
  for num_backups in 1; do
    echo "backups:$num_backups pipelined full_redo redoers=4 delay=none"
    run $num_backups 16 pipelined 1 4 none 1 0 0 4096
  done
}

nvram_persist_on_replay() {
  for delay in clwb-emu clflush; do
    for num_backups in 1; do
      run $num_backups 16 pipelined 0 4 $delay 1 1 0 4096
      run $num_backups 16 pipelined 0 8 $delay 1 1 0 4096
    done
  done
}

read_view() {
  for num_backups in 1; do
    sync_clock $num_backups
    for redoers in 4; do
      for full_redo in 0; do
        run $num_backups 16 "pipelined" $full_redo $redoers none 1 0 20 4096
      done
    done
  done
}

#for r in 1 2 3; do
for r in 1; do
  echo "Running multi_backup_replay r$r"
  multi_backup_replay
  #run 1 1 sync 0 1 clflush 1 0 0 4096

#  echo "Running no_nvram r$r"
#  no_nvram
#
#  echo "Running no_replay r$r"
#  no_replay
#
#  echo "Running full_replay r$r"
#  full_replay
#
#  echo "Running nvram_persist_on_replay r$r"
#  nvram_persist_on_replay
done

#echo "Running read_view"
#read_view

###### Experiments not really used any more #####
#single_backup_pipelined_replay() {
#  policy="pipelined"
#
#  redoers=1
#  for t in 1 2 4; do
#    echo "backups=1 thread=$t $policy redoers=$redoers"
#    run 1 $t $policy 0 $redoers none 1 0 0 4096
#  done
#
#  t=8
#  redoers=2
#  echo "backups=1 thread=$t $policy redoers=$redoers"
#  run 1 $t $policy 0 $redoers none 1 0 0 4096
#}

#single_backup_sync_replay() {
#  policy="sync"
#
#  redoers=1
#  for t in 1 2; do
#    echo "backups=1 thread=$t $policy redoers=$redoers"
#    run 1 $t $policy 0 $redoers none 1 0 0 4096
#  done
#
#  t=4
#  redoers=2
#  echo "backups=1 thread=$t $policy redoers=$redoers"
#  run 1 $t $policy 0 $redoers none 1 0 0 4096
#
#  t=8
#  redoers=4
#  echo "backups=1 thread=$t $policy redoers=$redoers"
#  run 1 $t $policy 0 $redoers none 1 0 0 4096
#}

#nvram() {
#  for delay in clwb-emu clflush; do
#    for num_backups in 1; do
#      for redoers in 4 8; do
#        echo "backups:$num_backups pipelined redoers=$redoers delay=$delay"
#        run $num_backups 16 pipelined 0 $redoers $delay 1 0 0 4096
#      done
#    done
#  done
#}

#for r in 1 2 3; do
#  echo "Running nvram r$r"
#  nvram
#
#  echo "Running single_backup_pipelined_replay r$r"
#  single_backup_pipelined_replay
#
#  echo "Running single_backup_sync_replay r$r"
#  single_backup_sync_replay
#
#done
