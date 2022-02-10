#! /bin/sh
#
# ---- April 3 2021, initially created by Y. Wang & X. Wang (OU MAP Lab)
#                    yongming.wang@ou.edu  xuguang.wang@ou.edu
# ---- July 21, 2021 Yunheng Wang, Modified for WoF to run on Jet
#
##########################################################################

print_help () {
  echo " "
  echo "  Usage: $0 [options] COMMANDS EVENTDATE"
  echo "  "
  echo "  Valid commands are:"
  echo "  "
  echo "     0. chgres    0.1 chgres_ics 0.2 chgres_lbcs"
  echo "     1. convobs   2. radarobs    3. fv3"
  echo "     4. fgmean    5. gsimean     6. gsimem"
  echo "     7. enkf      8. recenter    9. updateLBC"
  echo "     all: all DA cycle programs from 1 to 9 (DEFAULT)"
  echo "  "
  echo "  EVENTDATE:  YYYYMMDD"
  echo " "
  echo "  Options: "
  echo "         -h | --help        Show this help"
  echo "         -v | --verbose     Show more outputs while executing"
  echo "         -d | -n            Show commands but do not execute them"
  echo "         -s | --bgnc        Starting number of cycle (from 1, 0 is reserved to run CHGRES only)"
  echo "         -e | --endc        End number of cycle (terminated by \$END_DATE)"
  echo "         -c | --continue    Continue to run commands from the given one in the above order (DEFAULT no unless command is 'all')"
  echo "         -m | --map         Show mapping between number of cycles and data-time."
  echo "         -p | --ccpp        CCPP suite to be used (HRRR or NSSL)."
  echo " "
  echo "               --- by Yunheng Wang (10/27/2021) - version 1.0 ---"
  echo "  "
  exit $1
}

function join_by { local IFS="$1"; shift; echo "$*"; }

SH=/bin/sh

#-----------------------------------------------------------------------
# Parsing arguments
#-----------------------------------------------------------------------
showcmd="sbatch" # "sbatch" or "echo sbatch"
help=false;
verbose=false;

todaydate=20200515
istart=1    # Starting from 1
icontinue=0
iend=99
command="all"
showmap=false
thistime=""
ccpp="NSSL"

while [ $# -ge 1 ]; do
  case $1 in
    "-h" | "--help"    ) print_help 0   ;;
    "-v" | "--verbose" ) verbose=true   ;;
    "-d" | "-n"        ) showcmd='echo' ;;
    "-c"               ) icontinue=1    ;;
    "-m" | "-map"      ) showmap=true   ;;
    "-s" )
        istart=$2
        shift
        ;;
    "-e" )
        iend=$2
        shift
        ;;
    "-p" )
        if [[ $2 =~ HRRR|NSSL ]]; then
            ccpp=$2
        else
            echo "ERROR: Unsupport argument \"-p $2\". "
            print_help 1
        fi
        shift
        ;;
    all|chgres|chgres_ics|chgres_lbcs|convobs|radarobs|fv3|fgmean|gsimean|gsimem|enkf|recenter|updateLBC )
        command="$1"
        ;;
    * )

        if [[ $1 =~ ^[0-9]{12}$ ]]; then
            thisdate=${1:0:8}
            thistime=${1:8:4}
            if [[ $thistime -lt 1500 ]]; then
                todaydate=$(date -d "$thisdate 1 day ago" +%Y%m%d)
            else
                todaydate=${thisdate}
            fi
        elif [[ $1 =~ ^[0-9]{8}$ ]]; then
            todaydate=$1
        else
            echo "ERROR: Unsupport argument: $1."
            print_help 1
        fi
        ;;
  esac
  shift
done

nextdate=$(date -d "$todaydate 1 day" +%Y%m%d)

. system_env.dat_rt

export CCPP_SUITE="$ccpp"
export DATABASE_DIR="/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap/rundir/${CCPP_SUITE}/${todaydate}"
export LOG_DIR=${DATABASE_DIR}/log
export DATAROOT_INI=${DATABASE_DIR}/ini

if $showmap ; then
    ymd=${BEG_DATE:0:8}
    hhr=${BEG_DATE:8:2}
    min=${BEG_DATE:10:2}
    beginseconds=$(date +%s -d "${ymd} ${hhr}:${min}")

    echo "Event date: $todaydate; Next day: $nextdate"
    for ((icycle=4;icycle<48;icycle+=4));do
      secfrombeg=$(( DA_INTV*icycle*60 ))
      thisinseconds=$(( beginseconds + secfrombeg ))

      #thiscycle=$(date +%Y%m%d%H%M -d @$thisinseconds)
      thiscycletime=$(date +%H%M   -d @$thisinseconds)
      thiscyclehour=$(date +%H   -d @$thisinseconds)

      secfromlast=$(( DA_INTV*60 ))
      lastinseconds=$(( thisinseconds - secfromlast ))
      #lastcycle=$(date +%Y%m%d%H%M -d @$lastinseconds)
      lastcycletime=$(date +%H%M   -d @$lastinseconds)
      echo "icycle=$icycle: cycletime: ${thiscycletime}Z, FV3 forward: ${lastcycletime}Z; $((icycle+1))-${thiscyclehour}15Z; $((icycle+2))-${thiscyclehour}30Z; $((icycle+3))-${thiscyclehour}45Z;"
    done

    exit 0
fi

if [[ $thistime != "" ]]; then
    ymd=${BEG_DATE:0:8}
    hhr=${BEG_DATE:8:2}
    min=${BEG_DATE:10:2}
    beginseconds=$(date +%s -d "${ymd} ${hhr}:${min}")

    thisseconds=$(date +%s -d "$thisdate $thistime")
    icycle=$(( (thisseconds-beginseconds)/(DA_INTV*60) ))
    #echo "Event date: $todaydate; Next day: $nextdate; icycle = $icycle"
    istart=$icycle
fi

echo "Event date: $todaydate; CCPP_SUITE = ${CCPP_SUITE}; icycle = $istart"
echo "Run dir   : ${DATABASE_DIR}"

#-----------------------------------------------------------------------
# Programs to be run
#-----------------------------------------------------------------------
if_skip_chgres=yes
if_gotofcst=no

if_skip_all=no

allcyclecommands=(convobs radarobs fv3 fgmean gsimean gsimem enkf recenter updateLBC)
if [[ "$command" =~ chgres.*$ ]]; then
    if_skip_chgres=no
    if_gotofcst=yes
    case $command in
        chgres_ics )
            if_skip_ics=no
            if_skip_lbcs=yes
            ;;
        chgres_lbcs )
            if_skip_ics=yes
            if_skip_lbcs=no
            ;;
        chgres )
            if_skip_ics=no
            if_skip_lbcs=no
            ;;
        * )
            echo "ERROR: Unsupport command: $command."
            print_help 1
            ;;
    esac
elif [[ "$command" == "all" ]]; then
    commands=("${allcyclecommands[@]}")
else
    if [[ $icontinue -eq 0 ]]; then
        commands=($command)
        let iend=istart           # only run this cycle
    else
        for i in "${!allcyclecommands[@]}"; do
           if [[ "${command}" == "${allcyclecommands[$i]}" ]]; then
               idx=${i}
               break
           fi
        done
        commands=("${allcyclecommands[@]:$idx}")
    fi
fi


#if [ ${if_skip_all} == 'yes' ]; then
#  if_skip_chgres=yes
#  if_skip_convobs=yes
#  if_skip_radarobs=yes
#  if_skip_fv3=yes
#  if_skip_fgmean=yes
#  if_skip_gsimean=yes
#  if_skip_gsimem=yes
#  if_skip_enkf=yes
#  if_skip_updateLBC=yes
#  if_skip_recenter=yes
#else
#  if_skip_chgres=no
#  if_skip_convobs=no
#  if_skip_radarobs=no
#  if_skip_fv3=no
#  if_skip_fgmean=no
#  if_skip_gsimean=no
#  if_skip_gsimem=no
#  if_skip_enkf=no
#  if_skip_recenter=no
#  if_skip_updateLBC=no
#fi
#
#
##
## 0: do chgres only
## >= 1, starting cycle 1-N
##
#
#
#if [[ $icycle -ge 1 ]]; then
#    if_skip_chgres=yes
#    if_gotofcst=no
#else
#    if_skip_chgres=no
#    if_gotofcst=yes
#fi
#
if [ ${if_skip_chgres} == 'no' ]; then

    mkdir -p ${LOG_DIR}

    ens_size=${ENSSIZE_REAL}

    #
    # 0.1 run chgres for ICS of all members
    #
    if [[ "${if_skip_ics}" == 'no' ]]; then
      echo "$(date +%Y-%m-%d_%H:%M): Generate input files for each member"
      rm -f ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS.ics ${DATAROOT_INI}/${INIT_DATE}_*/FAILED.ics
      rm -f ${LOG_DIR}/chgres_ICS.sh

      cd ${LOG_DIR}

      cat << EOF > ${LOG_DIR}/chgres_ICS.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J chgres_ICS
#SBATCH -o ./jobchgres_ICS_%a_%j.out
#SBATCH -e ./jobchgres_ICS_%a_%j.err
#SBATCH -n ${COREPERNODE}
#SBATCH --partition=${QUEUE}
#SBATCH -t 00:30:00

export eventdate=${todaydate}
export START_TIME=${BEG_DATE}
export START_TIME_BG=${BGBEGTIME_HRRRE}
export SOURCE_PATH=${HRRRE_DIR}
export FCST_LENGTH=${FCST_LENGTH}
export CHGRES_ROOT=${CHGRES_ROOT}
export CHGRES_STATIC=${STATIC_DIR_CHGRES}
export GFS_INDEX=\${SLURM_ARRAY_TASK_ID}
export DATAHOME=${DATAROOT_INI}/${INIT_DATE}_\${SLURM_ARRAY_TASK_ID}
export PROC=${COREPERNODE}
export OMP_THREADS_NUM=1
export FCST_INTERVAL=${DA_INTV}

${SCRIPTS}/CHGRES/chgres_ICS.bash

error=\$?
if [ \${error} -ne 0 ]; then
  echo "error" > \${DATAHOME}/FAILED.ics
else
  echo "done" > \${DATAHOME}/SUCCESS.ics
fi

EOF
      ${showcmd} --array=1-${ens_size} ${LOG_DIR}/chgres_ICS.sh

      echo "Waiting for ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS.ics ...."
      success=()
      checkset=( $(seq 1 ${ens_size}) )
      while [[ ${#success[@]} -lt ${ens_size} ]]; do
          sleep 10
          failed=()
          for i in "${!checkset[@]}"; do
              mem=${checkset[$i]}
              if [[ -f ${DATAROOT_INI}/${INIT_DATE}_${mem}/SUCCESS.ics ]]; then
                  success+=($mem)
                  unset checkset[$i]
              elif [[ -f ${DATAROOT_INI}/${INIT_DATE}_${mem}/FAILED.ics ]]; then
                  failed+=($mem)
              fi
          done

          if [[ ${#failed[@]} -gt 0 ]]; then
              failedstr=$(join_by , "${failed[@]}")
              echo "Resubmitting $failedstr ..."
              ${showcmd} --array=${failedstr} ${LOG_DIR}/chgres_ICS.sh
          fi
      done
    fi

    da_intv_sec=$(( 60*DA_INTV ))
    lbcs_members=${ENSSIZE_BNDY}

    #
    # 0.2 run chgres for LBCS of all members
    #
    if [[ "${if_skip_lbcs}" == "no" ]]; then
      hrrre_sec=$(date -d "${BGBEGTIME_HRRRE:0:8} ${BGBEGTIME_HRRRE:8:4}" +%s)

      da_init_sec=$(date -d "${INIT_DATE:0:8}  ${INIT_DATE:8:4}" +%s)
      da_bgn_sec=$(date -d "${BEG_DATE:0:8}  ${BEG_DATE:8:4}" +%s)
      da_end_sec=$(date -d "${END_DATE:0:8}  ${END_DATE:8:4}" +%s)
      fcst_bgn_sec=$((da_bgn_sec+da_intv_sec))
      fcst_end1_sec=$((da_end_sec+3600))            # 1-hour later than DA end time for DA cycle boundary
      fcst_end2_sec=$((da_end_sec+6*3600))          # 6-hour later than DA end time for free forecast purpose

      cd ${LOG_DIR}
      rm -f ${LOG_DIR}/chgres_LBCS_*.sh

      bndy_times=()
      da_times=()
      #
      # For DA cycles
      #
      for ((isec=fcst_bgn_sec;isec<fcst_end1_sec;isec+=da_intv_sec)); do
          bndysec=$(( isec-hrrre_sec ))
          fhr=$((bndysec/3600))
          fmin=$(( (bndysec%3600)/60 ))
          fcst_time=$(printf "%02d%02d" $fhr $fmin)
          bndy_times+=($fcst_time)

          mysec=$(( isec-da_init_sec ))
          myhr=$(( mysec/3600 ))
          mymin=$(( (mysec%3600)/60 ))
          da_time=$(printf "%02d:%02d" $myhr $mymin)
          da_times+=($da_time)
      done

      #
      # For free forecast at the last DA cycle
      #
      for ((isec=fcst_end1_sec;isec<=fcst_end2_sec;isec+=3600)); do
          #relative to $BGBEGTIME_HRRRE
          bndysec=$(( isec-hrrre_sec ))
          fhr=$((bndysec/3600))
          fmin=$(( (bndysec%3600)/60 ))
          fcst_time=$(printf "%02d%02d" $fhr $fmin)
          bndy_times+=($fcst_time)

          # relative to $INIT_DATE
          mysec=$(( isec-da_init_sec ))
          myhr=$(( mysec/3600 ))
          mymin=$(( (mysec%3600)/60 ))
          da_time=$(printf "%02d:%02d" $myhr $mymin)
          da_times+=($da_time)
      done

      for i in "${!bndy_times[@]}"; do

          fcst_time=${bndy_times[$i]}
          da_time=${da_times[$i]}

          echo "$(date +%Y-%m-%d_%H:%M): Generate LBC files at HRRRE forecast time: ${fcst_time} for each member"
          rm -f ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS.lbc_${fcst_time} ${DATAROOT_INI}/${INIT_DATE}_*/FAILED.lbc_${fcst_time}

          cat << EOF > ${LOG_DIR}/chgres_LBCS_${fcst_time}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J LBCS_${fcst_time}
#SBATCH -o ./jobchgres_LBCS_${fcst_time}_%a_%j.out
#SBATCH -e ./jobchgres_LBCS_${fcst_time}_%a_%j.err
#SBATCH -n ${COREPERNODE}
#SBATCH --partition=${QUEUE}
#SBATCH -t 00:30:00

  export eventdate=${todaydate}
  export START_TIME=${BEG_DATE}
  export START_TIME_BG=${BGBEGTIME_HRRRE}
  export SOURCE_PATH=${HRRRE_DIR}
  export FCST_LENGTH=${FCST_LENGTH}
  export CHGRES_ROOT=${CHGRES_ROOT}
  export CHGRES_STATIC=${STATIC_DIR_CHGRES}
  export GFS_INDEX=\${SLURM_ARRAY_TASK_ID}
  export FCST_TIME=${fcst_time}
  export DATAHOME=${DATAROOT_INI}/${INIT_DATE}_\${SLURM_ARRAY_TASK_ID}
  export PROC=${COREPERNODE}
  export OMP_THREADS_NUM=1
  export FCST_INTERVAL=${DA_INTV}

  ${SCRIPTS}/CHGRES/chgres_LBCS.bash

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "error" > \${DATAHOME}/FAILED.lbc_${fcst_time}
  else
    echo "done" > \${DATAHOME}/SUCCESS.lbc_${fcst_time}
  fi
EOF

        ${showcmd} --array=1-${lbcs_members} ${LOG_DIR}/chgres_LBCS_${fcst_time}.sh

        echo "Waiting for ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS.lbc_${fcst_time} ...."
        success=()
        checkset=( $(seq 1 ${lbcs_members}) )
        while [[ ${#success[@]} -lt ${lbcs_members} ]]; do
            sleep 10
            failed=()
            for i in "${!checkset[@]}"; do
                mem=${checkset[$i]}
                if [[ -f ${DATAROOT_INI}/${INIT_DATE}_${mem}/SUCCESS.lbc_${fcst_time} ]]; then
                    success+=($mem)
                    unset checkset[$i]
                elif [[ -f ${DATAROOT_INI}/${INIT_DATE}_${mem}/FAILED.lbc_${fcst_time} ]]; then
                    failed+=($mem)
                fi
            done

            if [[ ${#failed[@]} -gt 0 ]]; then
                failedstr=$(join_by , "${failed[@]}")
                echo "Resubmitting $failedstr ..."
                ${showcmd} --array=${failedstr} ${LOG_DIR}/chgres_LBCS_${fcst_time}.sh
            fi
        done

        #
        # 0.3 Link LBC file for other members
        #
        imem=$(( lbcs_members+1 ))
        while [[ $imem -le $ens_size ]]; do
            target_mem=$(( imem%lbcs_members ))
            if [[ $target_mem -eq 0 ]]; then
                target_mem=${lbcs_members}
            fi
            target_file="gfs_bndy.tile7.${da_time}.nc"

            target_dir="${DATAROOT_INI}/${INIT_DATE}_${target_mem}/chgresprd"
            my_dir="${DATAROOT_INI}/${INIT_DATE}_${imem}/chgresprd"

            echo "Linking LBCS files at ${fcst_time} from ${target_dir} to ${my_dir} ..."
            ln -sf ${target_dir}/${target_file}  ${my_dir}/${target_file}

            let imem+=1
        done
      done
    fi
fi

icycle=$istart

if [ ${if_gotofcst} == 'no' ]; then

  ymd=${BEG_DATE:0:8}
  hhr=${BEG_DATE:8:2}
  min=${BEG_DATE:10:2}
  beginseconds=$(date +%s -d "${ymd} ${hhr}:${min}")

  while [ ${icycle} -le $iend ]; do

    #
    # determine programs to be run
    #
    if [[ $icycle -eq $istart ]]; then          # first starting command from argument
        for cmd in ${allcyclecommands[@]}; do
            if [[ " ${commands[*]} " =~ " ${cmd} " ]]; then
                export "if_skip_$cmd=no"
            else
                export "if_skip_$cmd=yes"
            fi
        done
    else                                        # run all DA cycle commands for all following cycles
        for cmd in ${allcyclecommands[@]}; do
            export "if_skip_$cmd=no"
        done
    fi

    #echo "$istart, $iend, $icycle"
    #echo "${commands[@]}"
    #echo "if_skip_chgres=        $if_skip_chgres"
    #echo "if_skip_convobs=       $if_skip_convobs"
    #echo "if_skip_radarobs=      $if_skip_radarobs"
    #echo "if_skip_fv3=           $if_skip_fv3"
    #echo "if_skip_fgmean=        $if_skip_fgmean"
    #echo "if_skip_gsimean=       $if_skip_gsimean"
    #echo "if_skip_gsimem=        $if_skip_gsimem"
    #echo "if_skip_enkf=          $if_skip_enkf"
    #echo "if_skip_recenter=      $if_skip_recenter"
    #echo "if_skip_updateLBC=     $if_skip_updateLBC"
    #
    #exit 0

    secfrombeg=$(( DA_INTV*icycle*60 ))
    thisinseconds=$(( beginseconds + secfrombeg ))

    thiscycle=$(date +%Y%m%d%H%M -d @$thisinseconds)
    thiscycletime=$(date +%H%M   -d @$thisinseconds)
    minthis=$(date +%M           -d @$thisinseconds)

    secfromlast=$(( DA_INTV*60 ))
    lastinseconds=$(( thisinseconds - secfromlast ))
    lastcycle=$(date +%Y%m%d%H%M -d @$lastinseconds)
    lastcycletime=$(date +%H%M   -d @$lastinseconds)
    FCST_LENG=${secfromlast}   # in seconds


    if [ ${thiscycle} -lt ${radar_cycle_date} ]; then
       both_conv_radar=0
       conv_only=1
       radar_only=0
       if_skip_radarobs="yes"
    elif [[ "$minthis" == "00" ]]; then
       both_conv_radar=1
       conv_only=0
       radar_only=0
       if_skip_convobs="no"
    else
       both_conv_radar=0
       conv_only=0
       radar_only=1
       if_skip_convobs="yes"
    fi

    #
    # cycle break
    #
    if [ ${thiscycle} -gt ${END_DATE} ]; then
      echo "$(date +%Y-%m-%d_%H:%M): DA finished !"
      exit 0
    fi

    if [ ${if_skip_convobs} == 'no' ]; then
      echo "$(date +%Y-%m-%d_%H:%M): Copy prepbufr file for cycle ${thiscycle}"
      export START_TIME=${thiscycle}
      export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}/obsprd
      export PREPBUFR=${PREPBUFR_DIR}
      export EARLY=0
      ${SCRIPTS}/GSI/conventional.ksh
    fi

    SBATCHSELLDIR=${DATABASE_DIR}/cycle/${thiscycle}/shdir
    mkdir -p ${SBATCHSELLDIR}

    cd ${SBATCHSELLDIR}

    if [ ${if_skip_radarobs} == 'no' ]; then
        echo "$(date +%Y-%m-%d_%H:%M): Copy radar obs. for cycle ${thiscycle}"

        export START_TIME=${thiscycle}
        export SUBH_TIME="00"
        export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}/obsprd
        export OBSDIR=${OBS_DIR}
        ${SCRIPTS}/GSI/radar_wof_obs.sh

        #export NSSLMOSAICNC=${RADAR_DIR}
        #export GSIEXEC=${GSI_ROOT}
        #${SCRIPTS}/GSI/radar_cp.ksh

#      cat << EOF > ${SBATCHSELLDIR}/radar_cp_${thiscycle}.sh
##!/bin/bash
##SBATCH -A ${ACCOUNT}
##SBATCH -J radar_cp_${thiscycletime}
##SBATCH -o ./jobradar_cp_${thiscycle}_%j.out
##SBATCH -e ./jobradar_cp_${thiscycle}_%j.err
##SBATCH -n 1
##SBATCH --partition=${QUEUE}
##SBATCH -t 00:30:00
#
#export START_TIME=${thiscycle}
#export SUBH_TIME="00"
#export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}/obsprd
##export NSSLMOSAICNC=${RADAR_DIR}
#export OBSDIR=${OBS_DIR}
#export GSIEXEC=${GSI_ROOT}
#
##${SCRIPTS}/GSI/radar_cp.ksh
#${SCRIPTS}/GSI/radar_wof_obs.sh
#
#error=\$?
#if [ \${error} -ne 0 ]; then
#  echo "" > \${DATAHOME}/FAILED_radar_cp
#else
#  echo "" > \${DATAHOME}/SUCCESS_radar_cp
#fi
#
#EOF
#        sleep 1
#        sbatch ${SBATCHSELLDIR}/radar_cp_${thiscycle}.sh
#
#        echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/obsprd/SUCCESS_radar_cp ...."
#        while [ ! -e "${DATABASE_DIR}/cycle/${thiscycle}/obsprd/SUCCESS_radar_cp" ]; do
#            if [[ -e "${DATABASE_DIR}/cycle/${thiscycle}/obsprd/FAILED_radar_cp" ]]; then
#                echo "${SCRIPTS}/GSI/radar_cp.ksh failed."
#                exit 1
#            else
#                sleep 20
#            fi
#        done
    fi


    if [ ${if_skip_fv3} == 'no' ]; then

      # --- run wrf.exe for each member
      echo "$(date +%Y-%m-%d_%H:%M): Forecasting to cycle ${thiscycle}"

      #flagdate=`date -u +%Y%m%d%H00 -d "${INIT_DATE:0:8} ${INIT_DATE:8:2}  1 hours"`

      imem=1
      ens_size=${ENSSIZE_REAL}

      corenum=100

      rm -f ${SBATCHSELLDIR}/fv3_${thiscycletime}_*.sh

      while [ ${imem} -le ${ens_size}  ]; do

        memstr4=$(printf "%04d" ${imem})
        #rm -rf ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}
        rm -rf ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/FAILED
        rm -rf ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/SUCCESS
        rm -rf ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/INPUT
        rm -rf ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/RESTART
        rm -rf ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/*.out

        cat << EOF > ${SBATCHSELLDIR}/fv3_${lastcycletime}_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J fv3_${lastcycletime}-$memstr4
#SBATCH -o ./jobfv3_${lastcycletime}-${memstr4}_%j.out
#SBATCH -e ./jobfv3_${lastcycletime}-${memstr4}_%j.err
#SBATCH -n ${corenum}
#SBATCH --partition=${QUEUE}
#SBATCH -t 00:30:00

  export eventdate=${todaydate}
  export INIT_TIME=${INIT_DATE}
  export START_TIME=${lastcycle}
  export FCST_LENGTH=${FCST_LENG}
  export FV3LAM_ROOT=${FV3LAM_ROOT}
  export FV3LAM_STATIC=${STATIC_DIR_FV3LAM}
  export DATAHOME=${DATABASE_DIR}/cycle
  export WORK_ROOT=\${DATAHOME}/${thiscycle}
  export INIHOME=${DATAROOT_INI}
  export ENS_MEM_START=${imem}
  export ENS_MEMNUM_THIS=1
  export PROC=${corenum}
  export CCPP_SUITE=${CCPP_SUITE}

  rm -f \${DATAHOME}/${lastcycle}/fv3prd_mem${memstr4}/FAILED \${DATAHOME}/${lastcycle}/fv3prd_mem${memstr4}/SUCCESS

  ${SCRIPTS}/FV3LAM/fv3lam_cycle.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${DATAHOME}/${lastcycle}/fv3prd_mem${memstr4}/FAILED
  else
    echo "" > \${DATAHOME}/${lastcycle}/fv3prd_mem${memstr4}/SUCCESS
  fi

EOF
        sleep 1
        sbatch ${SBATCHSELLDIR}/fv3_${lastcycletime}_${memstr4}.sh

        (( imem += 1 ))
      done

      echo "Waiting for ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem*/SUCCESS ...."
      success=()
      checkset=( $(seq 1 ${ENSSIZE_REAL}) )
      while [[ ${#success[@]} -lt ${ENSSIZE_REAL} ]]; do
          sleep 10
          failed=()
          for i in "${!checkset[@]}"; do
              mem=${checkset[$i]}
              memstr4=$(printf "%04d" ${mem})
              if [[ -f ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/SUCCESS ]]; then
                  success+=($mem)
                  unset checkset[$i]
              elif [[ -f ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/FAILED ]]; then
                  failed+=($mem)
              fi
          done

          #for i in "${!checkset[@]}"; do
          #    mem=${checkset[$i]}
          #    memstr4=$(printf "%04d" ${mem})
          #    jobreturn=( $(sacct --name "fv3_${lastcycletime}-$memstr4" -n -o "JobName%-30,State" -X) )
          #    jobname=${jobreturn[0]}
          #    jobstatus=${jobreturn[1]}
          #    case ${jobstatus} in
          #        TIMEOUT )
          #            failed+=($mem)
          #            ;;
          #        PENDING|RUNNING|COMPLETED )
          #            continue
          #            ;;
          #        * )
          #            echo "$jobname for $mem has status <$jobstatus>. Exiting ..."
          #            exit 1
          #            ;;
          #    esac
          #done

          if [[ ${#failed[@]} -gt 0 ]]; then
              for mem in ${failed[@]}; do
                  memstr4=$(printf "%04d" ${mem})
                  jobscript="${SBATCHSELLDIR}/fv3_${lastcycletime}_${memstr4}.sh"
                  rm -rf ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem${memstr4}/FAILED
                  echo "Resubmitting $jobscript ..."
                  ${showcmd} $jobscript
              done
          fi
      done

    fi

    if [ ${both_conv_radar} -eq 1 ]; then
      conv_only=0
      radar_only=0
    fi

    if [ ${both_conv_radar} -eq 1 ] || [ $conv_only -eq 1 ] ; then
      conv_radar_flag=1
    elif [ $radar_only -eq 1 ]; then
      conv_radar_flag=2
    fi

    while [ ${conv_radar_flag} -le 2 ]; do

        if [ ${conv_radar_flag} -eq 1 ] ; then
          if_conv=1
          if_radar=0
          NVARNUM=6
          NVARNUM1=14
          IF_STATIC_BEC=no
          #
          NODENUM_hyb=60
          TASKNUM_hyb=240
          QUEUE_hyb=${QUEUE1}
          RESNAME_hyb=${RESNAME_skx}
          OMPTHREADS_hyb=14

          NODENUM_enkf=60
          TASKNUM_enkf=72
          QUEUE_enkf=${QUEUE1}
          RESNAME_enkf=${RESNAME_skx}
          OMPTHREADS_enkf=56

        elif [ ${conv_radar_flag} -eq 2 ]; then
          if_conv=0
          if_radar=1
          NVARNUM=14
          NVARNUM1=14
          IF_STATIC_BEC=${STATIC_BEC}

          #
          NODENUM_hyb=60
          TASKNUM_hyb=240
          QUEUE_hyb=${QUEUE1}
          RESNAME_hyb=${RESNAME_skx}
          OMPTHREADS_hyb=14

          NODENUM_enkf=60
          TASKNUM_enkf=60
          QUEUE_enkf=${QUEUE1}
          RESNAME_enkf=${SBATCH_OPT}
          OMPTHREADS_enkf=14

        fi


        if [ ${if_skip_fgmean} == 'no' ]; then
          echo "$(date +%Y-%m-%d_%H:%M): Calculate mean of first-guess ensemble for cycle ${thiscycle}"
          rm -f ${DATABASE_DIR}/cycle/${thiscycle}/ensmeanFAILED ${DATABASE_DIR}/cycle/${thiscycle}/ensmeanSUCCESS

          cat << EOF > ${SBATCHSELLDIR}/fg_mean${thiscycle}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J fgmean_${thiscycletime}
#SBATCH -o ./jobfg_mean${thiscycle}_%j.out
#SBATCH -e ./jobfg_mean${thiscycle}_%j.err
#SBATCH -n 48
#SBATCH --partition=${QUEUE}
#SBATCH -t 00:30:00

  export DATAHOME=${DATABASE_DIR}/cycle
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  export GSI_ROOT=${GSI_ROOT}
  export STATIC_DIR_GSI=${STATIC_DIR_GSI}
  export ANALYSIS_TIME=${thiscycle}
  export WORK_ROOT=\${DATAHOME}/\${ANALYSIS_TIME}
  export NUM_DOMAINS=1
  export NVAR=${NVARNUM1}
  export IF_CONV=${if_conv}
  export PROC=48
  export CCPP_SUITE=${CCPP_SUITE}

  rm -f \${DATAHOME}/${thiscycle}/ensmeanFAILED \${DATAHOME}/${thiscycle}/ensmeanSUCCESS

  ${SCRIPTS}/GSI/firstguess_ensmean.sh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${DATAHOME}/${thiscycle}/ensmeanFAILED
  else
    echo "" > \${DATAHOME}/${thiscycle}/ensmeanSUCCESS
  fi

EOF
          rm -f ${SBATCHSELLDIR}/FG_mean_ready
          #chmod u+x ${SBATCHSELLDIR}/fg_mean${thiscycle}_${conv_radar_flag}.sh
          #${SH} ${SBATCHSELLDIR}/fg_mean${thiscycle}_${conv_radar_flag}.sh >& ${SBATCHSELLDIR}/fg_mean${thiscycle}_${conv_radar_flag}.log

          sbatch ${SBATCHSELLDIR}/fg_mean${thiscycle}_${conv_radar_flag}.sh

        fi

        echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/ensmeanSUCCESS ...."
        while [ ! -e "${DATABASE_DIR}/cycle/${thiscycle}/ensmeanSUCCESS" ] ; do
          sleep 20
        done
        touch ${SBATCHSELLDIR}/FG_mean_ready

        if [ ${conv_radar_flag} -eq 2 ]; then
           gsiprdname="gsiprd_radar_d01"
           enkfprdname="enkfprd_radar_d01"
        else
           gsiprdname="gsiprd_d01"
           enkfprdname="enkfprd_d01"
        fi

        if [ ${if_skip_gsimean} == 'no' ]; then

          dynphyvar="${DATABASE_DIR}/cycle/${thiscycle}/${enkfprdname}/ensmean_finished"
          echo "Waiting for ${dynphyvar} ...."
          while [ ! -e "${dynphyvar}" ] ; do
            sleep 10
          done

          nodenum=5
          corenum=96

          echo "$(date +%Y-%m-%d_%H:%M): Generate Hx for ensmean for cycle ${thiscycle}"
          rm -f ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/gsimeanFAILED ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/gsimeanSUCCESS

          cat << EOF > ${SBATCHSELLDIR}/gsi_mean${thiscycle}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J gsimean_${thiscycletime}
#SBATCH -o ./jobgsi_mean${thiscycle}_${conv_radar_flag}_%j.out
#SBATCH -e ./jobgsi_mean${thiscycle}_${conv_radar_flag}_%j.err
#SBATCH -n ${corenum}
#SBATCH --partition=${QUEUE}
#SBATCH -t 01:30:00

  export DATAHOME=${DATABASE_DIR}/cycle
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  export GSI_ROOT=${GSI_ROOT}
  export STATIC_DIR_GSI=${STATIC_DIR_GSI}
  export ANALYSIS_TIME=${thiscycle}
  export WORK_ROOT=\${DATAHOME}/\${ANALYSIS_TIME}
  export CONV_RADAR=0
  export RADAR_ONLY=${if_radar}
  export CONV_ONLY=${if_conv}
  export PROC=${corenum}
  export CCPP_SUITE=${CCPP_SUITE}

  rm -f \${DATAHOME}/${thiscycle}/${gsiprdname}/gsimeanFAILED \${DATAHOME}/${thiscycle}/${gsiprdname}/gsimeanSUCCESS

  ${SCRIPTS}/GSI/gsi_diag.sh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${DATAHOME}/${thiscycle}/${gsiprdname}/gsimeanFAILED
  else
    echo "" > \${DATAHOME}/${thiscycle}/${gsiprdname}/gsimeanSUCCESS
  fi

EOF

          #chmod u+x ${SBATCHSELLDIR}/gsi_mean${thiscycle}_${conv_radar_flag}.sh
          #${SBATCHSELLDIR}/gsi_mean${thiscycle}_${conv_radar_flag}.sh >& ${SBATCHSELLDIR}/gsi_mean${thiscycle}_${conv_radar_flag}.log
          sbatch ${SBATCHSELLDIR}/gsi_mean${thiscycle}_${conv_radar_flag}.sh

        fi

        echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/gsimeanSUCCESS ...."
        while [ ! -e "${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/gsimeanSUCCESS" ] ; do
          sleep 20
        done

        if [ ${if_skip_gsimem} == 'no' ]; then
          echo "$(date +%Y-%m-%d_%H:%M): Generate Hx for each member for cycle ${thiscycle}"

          nodenum=5
          corenum=96

          imem=1
          ens_size=${ENSSIZE_REAL}

          rm -f ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}.sh

          while [ ${imem} -le ${ens_size}  ]; do

            memstr4=$(printf "%04d" ${imem})

            #echo 'Member-'${imem}

            rm -f ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/FAILED_${imem}
            rm -f ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_${imem}

            declare -A jobs_gsi_mem

            cat << EOF > ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J gsimem_${thiscycletime}_${imem}
#SBATCH -o ./jobgsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}_%j.out
#SBATCH -e ./jobgsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}_%j.err
#SBATCH -n ${corenum}
#SBATCH --partition=${QUEUE}
#SBATCH -t 00:15:00

  export DATAHOME=${DATABASE_DIR}/cycle
  export ENS_MEM_START=${imem}
  export ENS_MEMNUM_THIS=1
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  export GSI_ROOT=${GSI_ROOT}
  export STATIC_DIR_GSI=${STATIC_DIR_GSI}
  export ANALYSIS_TIME=${thiscycle}
  export WORK_ROOT=\${DATAHOME}/\${ANALYSIS_TIME}
  export RADAR_ONLY=${if_radar}
  export CONV_ONLY=${if_conv}
  export PROC=${corenum}
  export OMP_THREADS_NUM=2

  rm -f \${DATAHOME}/${thiscycle}/${gsiprdname}/FAILED_${imem}
  rm -f \${DATAHOME}/${thiscycle}/${gsiprdname}/SUCCESS_${imem}

  ${SCRIPTS}/GSI/gsi_diag_mem.sh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${DATAHOME}/${thiscycle}/${gsiprdname}/FAILED_${imem}
  else
    echo "" > \${DATAHOME}/${thiscycle}/${gsiprdname}/SUCCESS_${imem}
  fi

EOF
            jobreturn=$(sbatch ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}.sh)
            jobs_gsi_mem[$memstr4]=${jobreturn##* }
            echo "Member-${imem}, $jobreturn"

            (( imem += 1 ))
          done

          echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_* ..."
          #while [[ ! -e ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_1 ]]; do
          #    sleep 20
          #done

          success=()
          while [[ ${#success[@]} -lt ${ens_size} ]]; do
              sleep 10
              #failed=()
              for mem in "${!jobs_gsi_mem[@]}"; do
                  jobid=${jobs_gsi_mem[$mem]}
                  jobreturn=( $(sacct -j $jobid -n -o "JobName%-30,State" -X) )
                  jobname=${jobreturn[0]}
                  jobstatus=${jobreturn[1]}

                  case ${jobstatus} in
                      TIMEOUT )
                          #failed+=($mem)
                          jobscript=${SBATCHSELLDIR}/gsi_mem${thiscycle}_${mem}_${conv_radar_flag}.sh
                          echo "Resubmitting ${jobscript} ......"
                          jobreturn=$(sbatch ${jobscript})
                          jobs_gsi_mem[$mem]=${jobreturn##* }
                          ;;
                      COMPLETED )
                          success+=($mem)
                          unset jobs_gsi_mem[$mem]
                          ;;
                      PENDING|RUNNING )
                          continue
                          ;;
                      * )
                          echo "$jobname for $mem has status <$jobstatus>. Exiting ..."
                          exit 1
                          ;;
                  esac
              done

          done


          #success=()
          #while [[ ${#success[@]} -lt ${ens_size} ]]; do
          #    #echo "running=[${running[@]}]"
          #
          #    sleep 10
          #    success=()
          #    failed=()
          #    running=()
          #    for imem in $(seq 1 ${ens_size}); do
          #      if [[ -e ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_$imem ]]; then
          #        success+=($imem)
          #      elif [[ -e ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/FAILED_$imem ]]; then
          #        failed+=($imem)
          #      else
          #        running+=($imem)
          #      fi
          #    done
          #
          #    if [[ ${#success[@]} -gt 0 ]]; then  # at lest one is done
          #      if [[ ${#running[@]} -gt 0 || ${#failed[@]} -gt 0 ]]; then
          #          #echo "success=[${success[@]}]"
          #          members=( ${failed[*]} ${running[*]} )
          #          echo "failed/running = [${members[@]}]"
          #          for imem in ${members[@]}; do
          #              memstr4=$(printf "%04d" ${imem})
          #              if compgen -G "${SBATCHSELLDIR}/jobgsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}_*.err" > /dev/null; then
          #                    joberrfs=($(ls ${SBATCHSELLDIR}/jobgsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}_*.err))
          #                    if grep -q "DUE TO TIME LIMIT" "${joberrfs[-1]}"; then
          #                        echo "Resubmitting $imem ...."
          #                        sbatch ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}.sh
          #                    fi
          #              fi
          #          done
          #      fi
          #    fi
          #done

          #successcnt=$(ls ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_* | wc -l)
          #echo "waiting for ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_* ..."
          #while [[ $successcnt -lt ${ens_size} ]]; do
          #    echo "${successcnt} members run gsi.x successfully."
          #    sleep 10
          #    successcnt=$(ls ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_* | wc -l)
          #done

        fi

        if [ ${if_skip_enkf} == 'no' ]; then

          echo "$(date +%Y-%m-%d_%H:%M): Run EnKF for cycle ${thiscycle} with conv_radar_flag = ${conv_radar_flag}"
          rm -f ${DATABASE_DIR}/cycle/${thiscycle}/EnKF_DONE_RADAR

          cat << EOF > ${SBATCHSELLDIR}/EnKF${thiscycle}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J EnKF_${thiscycletime}_${conv_radar_flag}
#SBATCH -o ./jobEnKF${thiscycle}_${conv_radar_flag}_%j.out
#SBATCH -e ./jobEnKF${thiscycle}_${conv_radar_flag}_%j.err
#SBATCH -n ${TASKNUM_enkf}
#SBATCH --partition=${QUEUE}
#SBATCH --tasks-per-node=2
#SBATCH -t 01:30:00

  export GSI_ROOT=${GSI_ROOT}
  export ANALYSIS_TIME=${thiscycle}
  #export HOME_ROOT=${DATABASE_DIR}/cycle
  export WORK_ROOT=${DATABASE_DIR}/cycle/\${ANALYSIS_TIME}
  #export DOMAIN=1
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  #export ENS_MEMNUM_THIS=1
  export NLONS=${nlon}
  export NLATS=${nlat}
  export NLEVS=${nlev}
  export ENKF_STATIC=${STATIC_DIR_GSI}
  export RADAR_ONLY=${if_radar}
  export CONV_ONLY=${if_conv}
  export IF_RH=${if_rh}
  #export BEGPROC=5600
  export PROC=${TASKNUM_enkf}
  #export OMP_NUM_THREADS=${OMPTHREADS_enkf}
  #export IBRUN_TASKS_PER_NODE=$(( 56 / ${OMPTHREADS_enkf} ))
  export CCPP_SUITE=${CCPP_SUITE}

  rm -f \${WORK_ROOT}/enkfFAILED \${WORK_ROOT}/enkfSUCCESS

  ${SCRIPTS}/GSI/run_enkf_fv3.sh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${WORK_ROOT}/enkfFAILED
  else
    echo "" > \${WORK_ROOT}/enkfSUCCESS
  fi

EOF

          #chmod u+x ${SBATCHSELLDIR}/EnKF${thiscycle}_${conv_radar_flag}.sh
          #${SBATCHSELLDIR}/EnKF${thiscycle}_${conv_radar_flag}.sh >& ${SBATCHSELLDIR}/EnKF${thiscycle}_${conv_radar_flag}.log
          sbatch ${SBATCHSELLDIR}/EnKF${thiscycle}_${conv_radar_flag}.sh

        fi

        if [ ${conv_radar_flag} -eq 1 ]; then
            echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/EnKF_DONE_CONV ...."
            while [ ! -e ${DATABASE_DIR}/cycle/${thiscycle}/EnKF_DONE_CONV ] ; do
              sleep 20
            done
        fi

        if [ ${conv_radar_flag} -eq 2 ]; then
            echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/EnKF_DONE_RADAR ...."
            while [ ! -e ${DATABASE_DIR}/cycle/${thiscycle}/EnKF_DONE_RADAR ] ; do
              sleep 20
            done
        fi

        if [ ${both_conv_radar} -ne 1 ] ; then
          conv_radar_flag=3
        fi

        if_skip_convobs=no
        if_skip_radarobs=no
        if_skip_fv3=no
        if_skip_fgmean=no

        (( conv_radar_flag = conv_radar_flag + 1 ))
    done

    if [ ${if_skip_recenter} == 'no'  ]; then
      echo "$(date +%Y-%m-%d_%H:%M): Recenter procedure for cycle ${thiscycle}"
      rm -f ${DATABASE_DIR}/cycle/${thiscycle}/recentSUCCESS

      cat << EOF > ${SBATCHSELLDIR}/recent${thiscycle}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J recent_${thiscycletime}
#SBATCH -o ./jobrecent${thiscycle}_%j.out
#SBATCH -e ./jobrecent${thiscycle}_%j.err
#SBATCH -n 48
#SBATCH --partition=${QUEUE1}
#SBATCH -t 00:30:00

  export DATAHOME=${DATABASE_DIR}/cycle
  export GSI_ROOT=${GSI_ROOT}
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  export ANALYSIS_TIME=${thiscycle}
  export WORK_ROOT=\${DATAHOME}/\${ANALYSIS_TIME}
  #export NUM_DOMAINS=1
  export NVAR=${NVARNUM}
  export PROC=48
  export CCPP_SUITE=${CCPP_SUITE}

  rm -f \${WORK_ROOT}/recentFAILED \${WORK_ROOT}/recentSUCCESS

  ${SCRIPTS}/GSI/analyis_ensmean.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${WORK_ROOT}/recentFAILED
  else
    echo "" > \${WORK_ROOT}/recentSUCCESS
  fi

EOF
      #chmod u+x ${SBATCHSELLDIR}/recent${thiscycle}.sh

      #${SH} ${SBATCHSELLDIR}/recent${thiscycle}.sh >& ${SBATCHSELLDIR}/recent${thiscycle}.log
      sbatch ${SBATCHSELLDIR}/recent${thiscycle}.sh
    fi

    echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/recentSUCCESS"
    while [[ ! -f ${DATABASE_DIR}/cycle/${thiscycle}/recentSUCCESS ]]; do
        sleep 10
    done

    if [ ${if_skip_updateLBC} == 'no' ]; then

      # --- run LBC update for each member
      echo "$(date +%Y-%m-%d_%H:%M): Generate updated BC files for each member"

      imem=1
      ens_size=${ENSSIZE_REAL}
      while [ ${imem} -le ${ens_size}  ]; do
        memstr4=$(printf "%04d" $imem)

        rm -f ${DATABASE_DIR}/cycle/${thiscycle}/movedaprd/movedaprd_${imem}/SUCCESS
        rm -f ${DATABASE_DIR}/cycle/${thiscycle}/movedaprd/movedaprd_${imem}/FAILED

        cat << EOF > ${SBATCHSELLDIR}/moveda_${thiscycletime}_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J moveda_${thiscycletime}_${imem}
#SBATCH -o ./moveda${thiscycletime}_${memstr4}_%j.out
#SBATCH -e ./moveda${thiscycletime}_${memstr4}_%j.err
#SBATCH -n 1
#SBATCH --partition=${QUEUE}
#SBATCH -t 00:30:00

  export START_TIME=${thiscycle}
  export GSI_ROOT=${GSI_ROOT}
  export HOME_ROOT=${DATABASE_DIR}/cycle
  export WORK_ROOT=\${HOME_ROOT}/\${START_TIME}/movedaprd/movedaprd_${imem}
  export MEM_INDEX=${imem}
  export PROC=1
  #export OMP_THREADS_NUM=1

  rm -f \${WORK_ROOT}/FAILED \${WORK_ROOT}/SUCCESS

  ${SCRIPTS}/GSI/MOVEDA.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${WORK_ROOT}/FAILED
  else
    echo "" > \${WORK_ROOT}/SUCCESS
  fi
EOF
        sbatch ${SBATCHSELLDIR}/moveda_${thiscycletime}_${memstr4}.sh

        (( imem += 1 ))
      done

      success_size=`ls -1 ${DATABASE_DIR}/cycle/${thiscycle}/movedaprd/movedaprd_*/SUCCESS 2>/dev/null | wc -l`
      echo "Checking ${DATABASE_DIR}/cycle/${thiscycle}/movedaprd/movedaprd_*/SUCCESS  ...."
      while [ ${success_size} -lt ${ens_size} ]; do
        echo "${success_size} members run moveda.ksh successfully."
        sleep 60
        success_size=`ls -1 ${DATABASE_DIR}/cycle/${thiscycle}/movedaprd/movedaprd_*/SUCCESS 2>/dev/null | wc -l`
      done

    fi

    (( icycle = icycle + 1  ))

    if [ ${thiscycle} -ge ${radar_cycle_date} ] && [ ${thiscycle} -le ${END_DATE} ]; then
      DA_INTV=${radar_cycle_intv}
    fi
  done
fi #if_gotofcst

exit 0
