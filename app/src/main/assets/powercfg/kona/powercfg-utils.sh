# /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
# 300000 403200 518400 614400 691200 787200 883200 979200 1075200 1171200 1248000 1344000 1420800 1516800 1612800 1708800 1804800

# /sys/devices/system/cpu/cpu4/cpufreq/scaling_available_frequencies
# 710400 825600 940800 1056000 1171200 1286400 1382400 1478400 1574400 1670400 1766400 1862400 1958400 2054400 2150400 2246400 2342400 2419200

# /sys/devices/system/cpu/cpu7/cpufreq/scaling_available_frequencies
#  844800 960000 1075200 1190400 1305600 1401600 1516800 1632000 1747200 1862400 1977600 2073600 2169600 2265600 2361600 2457600 2553600 2649600 2745600 2841600

# GPU
# 587000000 525000000 490000000 441600000 400000000 305000000

throttle() {
hint_group=""
if [[ "$top_app" != "" ]]; then
distinct_apps="
game=com.miHoYo.Yuanshen,com.miHoYo.ys.bilibili,com.miHoYo.ys.mi

mgame=com.bilibili.gcg2.bili

heavy=com.taobao.idlefish,com.taobao.taobao,com.miui.home,com.android.browser,com.baidu.tieba_mini,com.baidu.tieba,com.jingdong.app.mall

music=com.netease.cloudmusic,com.kugou.android,com.kugou.android.lite

video=com.ss.android.ugc.awem,tv.danmaku.bili
"

  hint_group=$(echo -e "$distinct_apps" | grep "$top_app" | cut -f1 -d "=")
  current_hint=$(getprop vtools.powercfg_hint)
  hint_mode="${action}:${hint_group}"

  if [[ "$hint_mode" == "$current_hint" ]]; then
    echo "$top_app [$hint_mode > $current_hint] skip!" >> /cache/powercfg_skip.log
    exit 0
  fi

else
  hint_mode="${action}"
fi

setprop vtools.powercfg_hint "$hint_mode"
}

# throttle

# GPU频率表
gpu_freqs=`cat /sys/class/kgsl/kgsl-3d0/devfreq/available_frequencies`
# GPU最大频率
gpu_max_freq='585000000'
# GPU最小频率
gpu_min_freq='257000000'
# GPU最小 power level
gpu_min_pl=5
# GPU最大 power level
gpu_max_pl=0

# MaxFrequency、MinFrequency
for freq in $gpu_freqs; do
  if [[ $freq -gt $gpu_max_freq ]]; then
    gpu_max_freq=$freq
  fi;
  if [[ $freq -lt $gpu_min_freq ]]; then
    gpu_min_freq=$freq
  fi;
done

# Power Levels
if [[ -f /sys/class/kgsl/kgsl-3d0/num_pwrlevels ]];then
  gpu_min_pl=`cat /sys/class/kgsl/kgsl-3d0/num_pwrlevels`
  gpu_min_pl=`expr $gpu_min_pl - 1`
fi;
if [[ "$gpu_min_pl" -lt 0 ]];then
  gpu_min_pl=0
fi;


reset_basic_governor() {
  echo 1 > /sys/devices/system/cpu/cpu0/online
  echo 1 > /sys/devices/system/cpu/cpu4/online
  echo 1 > /sys/devices/system/cpu/cpu7/online
  # CPU
  governor0=`cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor`
  governor4=`cat /sys/devices/system/cpu/cpufreq/policy4/scaling_governor`
  governor7=`cat /sys/devices/system/cpu/cpufreq/policy7/scaling_governor`

  if [[ ! "$governor0" = "schedutil" ]]; then
    echo 'schedutil' > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
  fi
  if [[ ! "$governor4" = "schedutil" ]]; then
    echo 'schedutil' > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
  fi
  if [[ ! "$governor7" = "schedutil" ]]; then
    echo 'schedutil' > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
  fi

  # GPU
  gpu_governor=`cat /sys/class/kgsl/kgsl-3d0/devfreq/governor`
  if [[ ! "$gpu_governor" = "msm-adreno-tz" ]]; then
    echo 'msm-adreno-tz' > /sys/class/kgsl/kgsl-3d0/devfreq/governor
  fi
  # echo $gpu_max_freq > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq
  echo $gpu_min_freq > /sys/class/kgsl/kgsl-3d0/devfreq/min_freq
  echo $gpu_min_pl > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
  echo $gpu_max_pl > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
}

devfreq_backup () {
  local devfreq_backup=/cache/devfreq_backup.prop
  local backup_state=`getprop vtools.dev_freq_backup`
  if [[ ! -f $devfreq_backup ]] || [[ "$backup_state" != "true" ]]; then
    echo '' > $devfreq_backup
    local dir=/sys/class/devfreq
    for file in `ls $dir`; do
      if [ -f $dir/$file/governor ]; then
        governor=`cat $dir/$file/governor`
        echo "$file#$governor" >> $devfreq_backup
      fi
    done
    setprop vtools.dev_freq_backup true
  fi
}

devfreq_performance () {
  devfreq_backup

  local dir=/sys/class/devfreq
  local devfreq_backup=/cache/devfreq_backup.prop
  local backup_state=`getprop vtools.dev_freq_backup`

  if [[ -f "$devfreq_backup" ]] && [[ "$backup_state" == "true" ]]; then
    for file in `ls $dir`; do
      if [ -f $dir/$file/governor ]; then
        # echo $dir/$file/governor
        echo performance > $dir/$file/governor
      fi
    done
  fi
}

devfreq_restore () {
  local devfreq_backup=/cache/devfreq_backup.prop
  local backup_state=`getprop vtools.dev_freq_backup`

  if [[ -f "$devfreq_backup" ]] && [[ "$backup_state" == "true" ]]; then
    local dir=/sys/class/devfreq
    while read line; do
      if [[ "$line" != "" ]]; then
        echo ${line#*#} > $dir/${line%#*}/governor
      fi
    done < $devfreq_backup
  fi
}

set_value() {
  value=$1
  path=$2
  if [[ -f $path ]]; then
    current_value="$(cat $path)"
    if [[ ! "$current_value" = "$value" ]]; then
      chmod 0664 "$path"
      echo "$value" > "$path"
    fi;
  fi;
}

set_input_boost_freq() {
  local c0="$1"
  local c1="$2"
  local c2="$3"
  local ms="$4"
  echo "0:$c0 1:$c0 2:$c0 3:$c0 4:$c1 5:$c1 6:$c1 7:$c2" > /sys/module/cpu_boost/parameters/input_boost_freq
  echo $ms > /sys/module/cpu_boost/parameters/input_boost_ms
}

set_cpu_freq() {
  echo "0:$2 1:$2 2:$2 3:$2 4:$4 5:$4 6:$4 7:$6" > /sys/module/msm_performance/parameters/cpu_max_freq
  echo $1 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
  echo $2 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
  echo $3 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
  echo $4 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
  echo $5 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
  echo $6 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq
}

sched_config() {
  echo "$1" > /proc/sys/kernel/sched_downmigrate
  echo "$2" > /proc/sys/kernel/sched_upmigrate
  echo "$1" > /proc/sys/kernel/sched_downmigrate
  echo "$2" > /proc/sys/kernel/sched_upmigrate

  echo "$3" > /proc/sys/kernel/sched_group_downmigrate
  echo "$4" > /proc/sys/kernel/sched_group_upmigrate
  echo "$3" > /proc/sys/kernel/sched_group_downmigrate
  echo "$4" > /proc/sys/kernel/sched_group_upmigrate
}

sched_limit() {
  echo $1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
  echo $2 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us
  echo $3 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us
  echo $4 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us
  echo $5 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us
  echo $6 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us
}

set_cpu_pl() {
  echo $1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl
  echo $1 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/pl
  echo $1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl
}

set_gpu_min_freq() {
  index=$1

  # GPU频率表
  gpu_freqs=`cat /sys/class/kgsl/kgsl-3d0/devfreq/available_frequencies`

  target_freq=$(echo $gpu_freqs | awk "{print \$${index}}")
  if [[ "$target_freq" != "" ]]; then
    echo $target_freq > /sys/class/kgsl/kgsl-3d0/devfreq/min_freq
  fi

  # gpu_max_freq=`cat /sys/class/kgsl/kgsl-3d0/devfreq/max_freq`
  # gpu_min_freq=`cat /sys/class/kgsl/kgsl-3d0/devfreq/min_freq`
  # echo "Frequency: ${gpu_min_freq} ~ ${gpu_max_freq}"
}

ctl_on() {
  echo 1 > /sys/devices/system/cpu/$1/core_ctl/enable
  if [[ "$2" != "" ]]; then
    echo $2 > /sys/devices/system/cpu/$1/core_ctl/min_cpus
  else
    echo 0 > /sys/devices/system/cpu/$1/core_ctl/min_cpus
  fi
}

ctl_off() {
  echo 0 > /sys/devices/system/cpu/$1/core_ctl/enable
}

set_ctl() {
  echo $2 > /sys/devices/system/cpu/$1/core_ctl/busy_up_thres
  echo $3 > /sys/devices/system/cpu/$1/core_ctl/busy_down_thres
  echo $4 > /sys/devices/system/cpu/$1/core_ctl/offline_delay_ms
}

set_hispeed_freq() {
  echo $1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
  echo $2 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq
  echo $3 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq
}

set_hispeed_load() {
  echo $1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load
  echo $2 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load
  echo $3 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_load
}

sched_boost() {
  echo $1 > /proc/sys/kernel/sched_boost_top_app
  echo $2 > /proc/sys/kernel/sched_boost
}

stune_top_app() {
  echo $1 > /dev/stune/top-app/schedtune.prefer_idle
  echo $2 > /dev/stune/top-app/schedtune.boost
}

cpuset() {
  echo $1 > /dev/cpuset/background/cpus
  echo $2 > /dev/cpuset/system-background/cpus
  echo $3 > /dev/cpuset/foreground/cpus
  echo $4 > /dev/cpuset/top-app/cpus
}

# [min/max/def] pl(number)
set_gpu_pl(){
  echo $2 > /sys/class/kgsl/kgsl-3d0/${1}_pwrlevel
}

# GPU MinPowerLevel To Up
gpu_pl_up() {
  local offset="$1"
  if [[ "$offset" != "" ]] && [[ ! "$offset" -gt "$gpu_min_pl" ]]; then
    echo `expr $gpu_min_pl - $offset` > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
  elif [[ "$offset" -gt "$gpu_min_pl" ]]; then
    echo 0 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
  else
    echo $gpu_min_pl > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
  fi
}

# GPU MinPowerLevel To Down
gpu_pl_down() {
  local offset="$1"
  if [[ "$offset" != "" ]] && [[ ! "$offset" -gt "$gpu_min_pl" ]]; then
    echo $offset > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
  elif [[ "$offset" -gt "$gpu_min_pl" ]]; then
    echo $gpu_min_pl > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
  else
    echo $gpu_min_pl > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
  fi
}

adjustment_by_top_app() {
  case "$top_app" in
    # YuanShen
    "com.miHoYo.Yuanshen" | "com.miHoYo.ys.mi" | "com.miHoYo.ys.bilibili")
        ctl_off cpu4
        ctl_off cpu7
        if [[ "$action" = "powersave" ]]; then
          sched_boost 0 0
          stune_top_app 0 0
          sched_config "50 80" "67 95" "300" "400"
          gpu_pl_down 4
          set_cpu_freq 1036800 1804800 1478400 1766400 1075200 2265600
          set_hispeed_freq 1708800 1766400 2073600
          sched_limit 5000 0 5000 0 5000 0
        elif [[ "$action" = "balance" ]]; then
          sched_boost 1 0
          stune_top_app 1 10
          sched_config "50 68" "67 80" "300" "400"
          gpu_pl_down 1
          set_cpu_freq 1036800 1804800 1056000 2054400 1075200 2457600
          set_hispeed_freq 1708800 1056000 1075200
          sched_limit 5000 0 5000 0 5000 0
        elif [[ "$action" = "performance" ]]; then
          sched_boost 1 0
          stune_top_app 1 10
          gpu_pl_down 1
          set_cpu_freq 1036800 1420800 1056000 2419200 1075200 2841600
          set_hispeed_freq 1708800 1766400 1747200
          sched_limit 5000 0 5000 0 5000 0
        elif [[ "$action" = "fast" ]]; then
          sched_boost 1 1
          stune_top_app 1 100
          sched_limit 5000 0 10000 0 5000 0
          # sched_config "40 60" "50 75" "120" "150"
        fi
        cpuset '0-1' '0-3' '0-3' '0-7'
    ;;

    # ShuangShengShiJie
    "com.bilibili.gcg2.bili")
        if [[ "$action" = "powersave" ]]; then
          gpu_pl_down 5
        elif [[ "$action" = "balance" ]]; then
          gpu_pl_down 3
        elif [[ "$action" = "performance" ]]; then
          gpu_pl_down 1
        elif [[ "$action" = "fast" ]]; then
          gpu_pl_down 0
        fi
        sched_config "60 68" "68 72" "140" "200"
        stune_top_app 0 0
        sched_boost 1 0
        cpuset '0-1' '0-3' '0-3' '0-7'
    ;;

    # XianYu, TaoBao, MIUI Home, Browser, TieBa Fast, TieBa、JingDong、TianMao
    "com.taobao.idlefish" | "com.taobao.taobao" | "com.miui.home" | "com.android.browser" | "com.baidu.tieba_mini" | "com.baidu.tieba" | "com.jingdong.app.mall" | "com.tmall.wireless")
      if [[ "$action" != "powersave" ]]; then
        sched_boost 1 1
        stune_top_app 1 1
        echo 4-6 > /dev/cpuset/top-app/cpus
      fi
    ;;

    # NeteaseCloudMusic, KuGou, KuGou Lite
    "com.netease.cloudmusic" | "com.kugou.android" | "com.kugou.android.lite")
      echo 0-6 > /dev/cpuset/foreground/cpus
    ;;

    # DouYin, BiliBili
    "com.ss.android.ugc.awem" | "tv.danmaku.bili")
      ctl_on cpu4
      ctl_on cpu7

      set_ctl cpu4 85 45 0
      set_ctl cpu7 80 40 0

      sched_boost 0 0
      stune_top_app 0 0
      set_cpu_pl 0
      echo 0-3 > /dev/cpuset/foreground/cpus

      if [[ "$action" = "powersave" ]]; then
        echo 0-5 > /dev/cpuset/top-app/cpus
      elif [[ "$action" = "balance" ]]; then
        echo 0-6 > /dev/cpuset/top-app/cpus
      elif [[ "$action" = "performance" ]]; then
        echo 0-6 > /dev/cpuset/top-app/cpus
      elif [[ "$action" = "fast" ]]; then
        echo 0-7 > /dev/cpuset/top-app/cpus
      fi
      pgrep -f $top_app | while read pid; do
        # echo $pid > /dev/cpuset/foreground/tasks
        echo $pid > /dev/stune/background/tasks
      done

      sched_config "85 85" "100 100" "240" "400"
    ;;

    "default")
      echo '未适配的应用'
    ;;
  esac
}
