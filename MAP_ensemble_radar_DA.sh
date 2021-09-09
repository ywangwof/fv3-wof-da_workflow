#! /bin/sh
#
# ---- April 3 2021, initially created by Y. Wang & X. Wang (OU MAP Lab)
#                    yongming.wang@ou.edu  xuguang.wang@ou.edu
# ---- July 21, 2021 Yunheng Wang, Modified for WoF to run on Jet
#
##########################################################################

. system_env.dat_rt

SH=/bin/sh

if_skip_all=no

if [ ${if_skip_all} == 'yes' ]; then
  if_skip_chgres=yes
  if_skip_convobs=yes
  if_skip_radarobs=yes
  if_skip_fv3=yes
  if_skip_fgmean=yes
  if_skip_gsimean=yes
  if_skip_gsimem=yes
  if_skip_enkf=yes
  if_skip_updateLBC=yes
  if_skip_recenter=yes
else
  if_skip_chgres=no
  if_skip_convobs=no
  if_skip_radarobs=no
  if_skip_fv3=no
  if_skip_fgmean=no
  if_skip_gsimean=no
  if_skip_gsimem=no
  if_skip_enkf=no
  if_skip_recenter=no
  if_skip_updateLBC=no
fi


#
# 0: do chgres only
# >= 1, starting cycle 1-N
#
icycle=${1-1}    # Starting from 1

if [[ $icycle -ge 1 ]]; then
    if_skip_chgres=yes
    if_gotofcst=no
else
    if_skip_chgres=no
    if_gotofcst=yes
fi

if [ ${if_skip_chgres} == 'no' ]; then

    mkdir -p ${LOG_DIR}

    # --- run real.exe for each member
    echo "$(date +%Y-%m-%d_%H:%M): Generate input files for each member"
    rm -f ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS ${DATAROOT_INI}/${INIT_DATE}_*/FAILED

    imem=0
    ens_size=${ENSSIZE_REAL}

    rm -f ${LOG_DIR}/chgres_m*sh

    cd ${LOG_DIR}
    #
    # 1. run chgres for all members
    #
    while [ ${imem} -le ${ens_size}  ]; do
        memstr4=$(printf "%04d" $imem)

        cat << EOF > ${LOG_DIR}/chgres_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J chgres_${memstr4}
#SBATCH -o ./jobchgres_${memstr4}_%j.out
#SBATCH -e ./jobchgres_${memstr4}_%j.err
#SBATCH -n ${COREPERNODE}
#SBATCH --partition=${QUEUE}
#SBATCH -t 02:30:00

  export START_TIME=${BGBEGTIME_WOF}
  export START_TIME_BG=${BGBEGTIME_HRRRE}
  export SOURCE_PATH=${HRRRE_DIR}
  export FCST_LENGTH=${FCST_LENGTH}
  export CHGRES_ROOT=${CHGRES_ROOT}
  export CHGRES_STATIC=${STATIC_DIR_CHGRES}
  export GFS_INDEX=${imem}
  export DATAHOME=${DATAROOT_INI}/${INIT_DATE}_${imem}
  export PROC=$(( 1 * ${COREPERNODE} ))
  export OMP_THREADS_NUM=1
  export FCST_INTERVAL=${DA_INTV}

  module load netcdf/4.7.4

  ${SCRIPTS}/CHGRES/chgres_cube.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "error" > \${DATAHOME}/FAILED
  else
    echo "done" > \${DATAHOME}/SUCCESS
  fi
EOF

      sleep 1

      ${showcmd} ${LOG_DIR}/chgres_${memstr4}.sh
      (( imem += 1 ))
    done

    success_size=`ls -1 ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS 2>/dev/null | wc -l`
    while [ ${success_size} -le ${ens_size} ]; do
      echo "${success_size} members run chgres successfully"
      sleep 60
      success_size=`ls -1 ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS 2>/dev/null | wc -l`
    done

fi

if [ ${if_gotofcst} == 'no' ]; then

  ymd=${BEG_DATE:0:8}
  hhr=${BEG_DATE:8:2}
  min=${BEG_DATE:10:2}
  beginseconds=$(date +%s -d "${ymd} ${hhr}:${min}")

  while [ ${icycle} -le 99 ]; do

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
      break
    fi

    if [ ${if_skip_convobs} == 'no' ]; then
      echo "$(date +%Y-%m-%d_%H:%M): Copy prepbufr file for cycle ${thiscycle}"
      export START_TIME=${thiscycle}
      export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}/obsprd
      export PREPBUFR=${PREPBUFR_DIR}
      export EARLY=0
      ${SCRIPTS}/GSI/conventional.ksh
    fi

    if [ ${if_skip_radarobs} == 'no' ]; then
      echo "$(date +%Y-%m-%d_%H:%M): Copy radar obs. for cycle ${thiscycle}"
      export START_TIME=${thiscycle}
      export SUBH_TIME="00"
      export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}/obsprd
      export NSSLMOSAICNC=${RADAR_DIR}
      export GSIEXEC=${GSI_ROOT}
      ${SCRIPTS}/GSI/radar_cp.ksh
    fi

    SBATCHSELLDIR=${DATABASE_DIR}/cycle/${thiscycle}/shdir
    mkdir -p ${SBATCHSELLDIR}

    cd ${SBATCHSELLDIR}

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
#SBATCH -t 02:30:00

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


      success_size=`ls -1 ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem*/SUCCESS 2>/dev/null | wc -l`
      echo "Waiting for ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem*/SUCCESS ...."
      while [ ${success_size} -lt ${ENSSIZE_REAL} ]; do
          #echo "${success_size} members run FV3 successfully"
          sleep 10
          fail_size=`ls -1 ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem*/FAILED 2>/dev/null | wc -l`
          while [ ${fail_size} -gt 0 ]; do
            echo "${fail_size} members FV3 failed."
            exit 1
            #sleep 60
            #fail_size=`ls -1 ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem*/FAILED 2>/dev/null | wc -l`
          done
          success_size=`ls -1 ${DATABASE_DIR}/cycle/${lastcycle}/fv3prd_mem*/SUCCESS 2>/dev/null | wc -l`
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

  rm -f \${DATAHOME}/${thiscycle}/ensmeanFAILED \${DATAHOME}/${thiscycle}/ensmeanSUCCESS

  ${SCRIPTS}/GSI/firstguess_ensmean.ksh

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
  export GSIPROC=68
  export ANALYSIS_TIME=${thiscycle}
  export WORK_ROOT=\${DATAHOME}/\${ANALYSIS_TIME}
  export NUM_DOMAINS=1
  export CONV_RADAR=0
  export RADAR_ONLY=${if_radar}
  export CONV_ONLY=${if_conv}
  export PROC=${corenum}
  export OMP_THREADS_NUM=2

  # Jet environment specific
  source /etc/profile.d/modules.sh
  module purge
  module load cmake/3.16.1
  module load intel/18.0.5.274
  module load impi/2018.4.274
  module load netcdf/4.7.0 #don't load netcdf/4.7.4 from hpc-stack, GSI does not compile with it.

  module use /lfs4/HFIP/hfv3gfs/nwprod/hpc-stack/libs/modulefiles/stack
  module load hpc/1.1.0
  module load hpc-intel/18.0.5.274
  module load hpc-impi/2018.4.274
  module load bufr/11.4.0
  module load bacio/2.4.1
  module load crtm/2.3.0
  module load ip/3.3.3
  module load nemsio/2.5.2
  module load sp/2.3.3
  module load w3emc/2.7.3
  module load w3nco/2.4.1
  module load sfcio/1.4.1
  module load sigio/2.3.2
  module load wrf_io/1.2.0
  module load szip
  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/szip/2.1/lib
  # End of Jet environment

  rm -f \${DATAHOME}/${thiscycle}/${gsiprdname}/gsimeanFAILED \${DATAHOME}/${thiscycle}/${gsiprdname}/gsimeanSUCCESS

  ${SCRIPTS}/GSI/gsi_diag.ksh

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

            echo 'Member-'${imem}

            rm -f ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/FAILED_${imem}
            rm -f ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_${imem}

            cat << EOF > ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J gsimem_${thiscycletime}_${imem}
#SBATCH -o ./jobgsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}_%j.out
#SBATCH -e ./jobgsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}_%j.err
#SBATCH -n ${corenum}
#SBATCH --partition=${QUEUE}
#SBATCH -t 02:30:00

  export DATAHOME=${DATABASE_DIR}/cycle
  export ENS_MEM_START=${imem}
  export ENS_MEMNUM_THIS=1
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  export GSI_ROOT=${GSI_ROOT}
  export STATIC_DIR_GSI=${STATIC_DIR_GSI}
  export GSIPROC=68
  export ANALYSIS_TIME=${thiscycle}
  export WORK_ROOT=\${DATAHOME}/\${ANALYSIS_TIME}
  export NUM_DOMAINS=1
  export CONV_RADAR=0
  export RADAR_ONLY=${if_radar}
  export CONV_ONLY=${if_conv}
  export PROC=${corenum}
  export OMP_THREADS_NUM=2

  # Jet environment specific
  source /etc/profile.d/modules.sh
  module purge
  module load cmake/3.16.1
  module load intel/18.0.5.274
  module load impi/2018.4.274
  module load netcdf/4.7.0 #don't load netcdf/4.7.4 from hpc-stack, GSI does not compile with it.

  module use /lfs4/HFIP/hfv3gfs/nwprod/hpc-stack/libs/modulefiles/stack
  module load hpc/1.1.0
  module load hpc-intel/18.0.5.274
  module load hpc-impi/2018.4.274
  module load bufr/11.4.0
  module load bacio/2.4.1
  module load crtm/2.3.0
  module load ip/3.3.3
  module load nemsio/2.5.2
  module load sp/2.3.3
  module load w3emc/2.7.3
  module load w3nco/2.4.1
  module load sfcio/1.4.1
  module load sigio/2.3.2
  module load wrf_io/1.2.0
  module load szip
  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/szip/2.1/lib
  # End of Jet environment

  rm -f \${DATAHOME}/${thiscycle}/${gsiprdname}/FAILED_${imem}
  rm -f \${DATAHOME}/${thiscycle}/${gsiprdname}/SUCCESS_${imem}

  ${SCRIPTS}/GSI/gsi_diag_mem.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > \${DATAHOME}/${thiscycle}/${gsiprdname}/FAILED_${imem}
  else
    echo "" > \${DATAHOME}/${thiscycle}/${gsiprdname}/SUCCESS_${imem}
  fi

EOF
            sbatch ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}_${conv_radar_flag}.sh

            (( imem += 1 ))
          done

          echo "waiting for ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_1 ..."
          while [[ ! -e ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_1 ]]; do
              sleep 20
          done

          success=()
          while [[ ${#success[@]} -lt ${ens_size} ]]; do
              echo "success=[${success[@]}]"
              echo "failed=[${failed[@]}]"
              echo "running=[${running[@]}]"

              sleep 10
              for imem in $(seq 1 ${ens_size}); do
                if [[ -e ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_$imem ]]; then
                  success+=($imem)
                elif [[ -e ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/FAILED_$imem ]]; then
                  failed+=($imem)
                else
                  running+=($imem)
                fi
              done
          done
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
  export HOME_ROOT=${DATABASE_DIR}/cycle
  export WORK_ROOT=\${HOME_ROOT}/\${ANALYSIS_TIME}
  export DOMAIN=1
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  export ENS_MEMNUM_THIS=1
  export NLONS=${nlon}
  export NLATS=${nlat}
  export NLEVS=${nlev}
  export ENKF_STATIC=${STATIC_DIR_GSI}
  export RADAR_ONLY=${if_radar}
  export CONV_ONLY=${if_conv}
  export IF_RH=${if_rh}
  #export BEGPROC=5600
  export PROC=${TASKNUM_enkf}
  export OMP_NUM_THREADS=${OMPTHREADS_enkf}
  #export IBRUN_TASKS_PER_NODE=$(( 56 / ${OMPTHREADS_enkf} ))

  # Jet environment specific
  source /etc/profile.d/modules.sh
  module purge
  module load cmake/3.16.1
  module load intel/18.0.5.274
  module load impi/2018.4.274
  module load netcdf/4.7.0 #don't load netcdf/4.7.4 from hpc-stack, GSI does not compile with it.

  module use /lfs4/HFIP/hfv3gfs/nwprod/hpc-stack/libs/modulefiles/stack
  module load hpc/1.1.0
  module load hpc-intel/18.0.5.274
  module load hpc-impi/2018.4.274
  module load bufr/11.4.0
  module load bacio/2.4.1
  module load crtm/2.3.0
  module load ip/3.3.3
  module load nemsio/2.5.2
  module load sp/2.3.3
  module load w3emc/2.7.3
  module load w3nco/2.4.1
  module load sfcio/1.4.1
  module load sigio/2.3.2
  module load wrf_io/1.2.0
  module load szip
  module load nco/4.9.3
  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/szip/2.1/lib
  # End of Jet environment

  rm -f \${WORK_ROOT}/enkfFAILED \${WORK_ROOT}/enkfSUCCESS

  ${SCRIPTS}/GSI/run_enkf_fv3.ksh

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
#SBATCH -J recent${thiscycle}
#SBATCH -o ./jobrecent${thiscycle}_%j.out
#SBATCH -e ./jobrecent${thiscycle}_%j.err
#SBATCH -n 48
#SBATCH --partition=${QUEUE1}
#SBATCH -t 02:30:00

  export DATAHOME=${DATABASE_DIR}/cycle
  export GSI_ROOT=${GSI_ROOT}
  export ENSEMBLE_SIZE=${ENSSIZE_REAL}
  export ANALYSIS_TIME=${thiscycle}
  export WORK_ROOT=\${DATAHOME}/\${ANALYSIS_TIME}
  export NUM_DOMAINS=1
  export NVAR=${NVARNUM}
  export PROC=48

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

      imem=0
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
#SBATCH -t 02:30:00

  export START_TIME=${thiscycle}
  export GSI_ROOT=${GSI_ROOT}
  export HOME_ROOT=${DATABASE_DIR}/cycle
  export WORK_ROOT=\${HOME_ROOT}/\${START_TIME}/movedaprd/movedaprd_${imem}
  export MEM_INDEX=${imem}
  export PROC=1
  export OMP_THREADS_NUM=1

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
