#!/bin/bash 
primary="192.168.1.106" # apt059
declare -a backups=("apt061" "apt064" "apt051" "apt007" "apt044" "apt055" "apt039")

function cleanup {
  killall -9 ermia_SI 2> /dev/null
  for b in "${backups[@]}"; do
    echo "Kill $b"
    ssh $b "killall -9 ermia_SI 2> /dev/null"
  done
}

trap cleanup EXIT

run() {
  num_backups=$1
  t=$2
  policy=$3
  full=$4
  redoers=$5
  delay=$6
  nvram=$7
  persist_nvram_on_replay=$8

  echo "----------"
  echo backups:$num_backups thread:$t $policy full_redo=$full redoers=$redoers delay=$delay nvram_log_buffer=$nvram
  echo "----------"
  ./run-cluster.sh SI $t 10 $t tpcc_org tpccr \
    "-chkpt_interval=1000000 -node_memory_gb=19 -log_ship_by_rdma -fake_log_write -wait_for_backups -num_backups=$num_backups -pipelined_persist=0" \
    "-primary_host=$primary -node_memory_gb=20 -log_ship_by_rdma -nvram_log_buffer=$nvram -quick_bench_start -wait_for_primary -replay_policy=$policy -full_replay=$full -replay_threads=$redoers -nvram_delay_type=$delay -persist_nvram_on_replay=$persist_nvram_on_replay" \
    "${backups[@]:0:$num_backups}"
  echo
}

nvram_persist_on_replay() {
  for delay in clwb-emu clflush; do
    for num_backups in 1 2 3 4 5 6 7; do
      run $num_backups 16 pipelined 0 4 $delay 1 1
      run $num_backups 16 pipelined 0 8 $delay 1 1
    done
  done
}

single_backup_replay() {
  delay="none"
  for full_redo in 1 0; do
    for t in 16 8 4 2; do
      for policy in pipelined sync; do
        for redoers in 8 4 2 1; do
          if [ "$redoers" -ge "$t" ]; then
            continue
          fi
          num_backups=1
          echo "backups:$num_backups thread:$t $policy full_redo=$full_redo redoers=$redoers delay=$delay"
          run $num_backups $t $policy $full_redo $redoers $delay 1 0
        done
      done
    done
  done
}

multi_backup_replay() {
  delay="none"
  full_redo=0
  for redoers in 4 2 1 8; do
    for policy in sync pipelined; do
      for num_backups in 2 3 4 5 6 7; do
        t=16
        echo "backups:$num_backups thread:$t $policy full_redo=$full_redo redoers=$redoers delay=$delay"
        run $num_backups $t $policy $full_redo $redoers $delay 1 0
      done
    done
  done
}

nvram() {
  for delay in clwb-emu clflush; do
    full_redo=0
    for num_backups in 1 2 3 4 5 6 7; do
      t=16

      policy="none"
      redoers=0
      echo "backups:$num_backups thread:$t $policy full_redo=$full_redo redoers=$redoers delay=$delay"
      run $num_backups $t $policy $full_redo $redoers $delay 1 0

      for policy in pipelined ; do
        for redoers in 4; do
          echo "backups:$num_backups thread:$t $policy full_redo=$full_redo redoers=$redoers delay=$delay"
          run $num_backups $t $policy $full_redo $redoers $delay 1 0
        done
      done
    done
  done
}

no_nvram() {
  for num_backups in 1 2 3 4 5 6 7; do
    echo "backups:$num_backups thread:16 pipelined full_redo=0 redoers=4 delay=none nvram_log_buffer=0"
    run $num_backups 16 "pipelined" 0 4 "none" 0 0

    echo "backups:$num_backups thread:16 none full_redo=0 redoers=0 delay=none nvram_log_buffer=0"
    run $num_backups 16 "none" 0 0 "none" 0 0
  done
}

no_replay() {
  delay="none"
  for t in 1 2 4 8 16; do
    run 1 $t none 0 0 $delay 1 0
  done

  for num_backups in 2 3 4 5 6 7; do
    t=16
    run $num_backups $t none 0 0 $delay 1 0
  done
}

full_replay() {
  delay="none"
  full_redo=1
  for num_backups in 1 2 3 4 5 6 7; do
    policy="pipelined"
    redoers=4
    t=16
    echo "backups:$num_backups thread:$t $policy full_redo=$full_redo redoers=$redoers delay=$delay"
    run $num_backups $t $policy $full_redo $redoers $delay 1 0
  done
}

for r in 1 2 3; do
  echo "Running nvram_persist_on_replay r$r"
  nvram_persist_on_replay
done

for r in 1 2 3; do
  echo "Running no_replay r$r"
  no_replay
done

for r in 1 2 3; do
  echo "Running single_backup_replay r$r"
  single_backup_replay
done

for r in 1 2 3; do
  echo "Running full_replay r$r"
  full_replay
done

for r in 1 2 3; do
  echo "Running multi_backup_replay r$r"
  multi_backup_replay
done

for r in 1 2 3; do
  echo "Running nvram r$r"
  nvram
done

for r in 1 2 3; do
  echo "Running no_nvram r$r"
  no_nvram
done
