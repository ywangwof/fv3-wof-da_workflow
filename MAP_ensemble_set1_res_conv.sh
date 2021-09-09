#! /bin/sh
#SBATCH -J HWT_rtA
#SBATCH -o ./HWT_rtA.log
#SBATCH -n 3360
#SBATCH --partition=sjet,vjet,xjet,kjet
#SBATCH -t 05:30:00
#SBATCH -A hpc-wof1

# ---- April 3 2021, initially created by Y. Wang & X. Wang (OU MAP Lab)
#                    yongming.wang@ou.edu  xuguang.wang@ou.edu
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
  if_skip_fcst18h=yes
  if_skip_upp=yes
else
  if_skip_chgres=yes
  if_skip_convobs=no
  if_skip_radarobs=no
  if_skip_fv3=no
  if_skip_fgmean=no
  if_skip_gsimean=no
  if_skip_gsimem=no
  if_skip_enkf=no
  if_skip_updateLBC=no
  if_skip_recenter=no
  if_skip_fcst6h=no
  if_skip_upp=no
fi

if_gotofcst=no

mkdir -p ${LOG_DIR}

if [ ${if_gotofcst} == 'no' ]; then

  if [ ${if_skip_chgres} == 'no' ]; then

    # --- run real.exe for each member
    echo 'Generate input files for each member at --- ' `date +%Y-%m-%d_%H:%M`
    rm -f ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS ${DATAROOT_INI}/${INIT_DATE}_*/FAILED

    imem=0
    isub=0
    sub_mem=1
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
#SBATCH -t 01:30:00

  export START_TIME=${BGBEGTIME_WOF}
  export START_TIME_BG=${BGBEGTIME_HRRRE}
  export SOURCE_PATH=${HRRRE_DIR}
  export FCST_LENGTH=${FCST_LENGTH}
  export CHGRES_ROOT=${CHGRES_ROOT}
  export CHGRES_STATIC=${STATIC_DIR_CHGRES}
  export GFS_INDEX=${imem}
  export DATAHOME=${DATAROOT_INI}/${INIT_DATE}_${imem}
  export PROC=$(( 1 * ${COREPERNODE} ))
  #export BEGPROC=$(( ${isub} * ${COREPERNODE} * 1 ))
  export OMP_THREADS_NUM=1

  module load netcdf/4.7.4

  ${SCRIPTS}/CHGRES/chgres_cube.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "error" > \${DATAHOME}/FAILED
  else
    echo "done" > \${DATAHOME}/SUCCESS
  fi
EOF
      #chmod u+x ${LOG_DIR}/chgres_${imem}.sh

      #(( isub += 1 ))
      #echo ${LOG_DIR}/chgres_${imem}.sh" >& "${LOG_DIR}/chgres_${imem}."log &" \
      #      >> ${LOG_DIR}/chgres_m${sub_mem}.sh
      sleep 1
      #if [ ${isub} -ge 37 ] || [ ${imem} -eq ${ens_size} ] ; then
      #  echo "wait" >> ${LOG_DIR}/chgres_m${sub_mem}.sh
      #  sleep 3
      #  isub=0
      #  sub_mem=`expr ${sub_mem} + 1`
      #fi

      ${showcmd} ${LOG_DIR}/chgres_${memstr4}.sh
      (( imem += 1 ))
    done

    #ig=1
    #while [ ${ig} -le $(( ${sub_mem} - 1 )) ]; do
    #  #chmod u+x ${LOG_DIR}/chgres_m${ig}.sh
    #  ${LOG_DIR}/chgres_m${ig}.sh >& ${LOG_DIR}/chgres_m${ig}.log
    #  (( ig = ig + 1 ))
    #done

    success_size=`ls -1 ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS 2>/dev/null | wc -l`
    while [ ${success_size} -le ${ens_size} ]; do
      echo "${success_size} members run chgres successfully"
      sleep 60
      success_size=`ls -1 ${DATAROOT_INI}/${INIT_DATE}_*/SUCCESS 2>/dev/null | wc -l`
    done

#    #
#    # 2. run chgres for boundary
#    #
#
#    cat << EOF > ${LOG_DIR}/chgres_dabndy.sh
##!/bin/bash
##SBATCH -A ${ACCOUNT}
##SBATCH -J chgres_dabndy
##SBATCH -o ./jobchgres_dabndy.out
##SBATCH -e ./jobchgres_dabndy.err
##SBATCH -n $(( 2 * ${COREPERNODE} ))
##SBATCH --partition=${QUEUE}
##SBATCH -t 01:30:00
#
#  export START_TIME=${BGBEGTIME_WOF}
#  export START_TIME_BG=${BGBEGTIME_HRRRE}
#  export SOURCE_PATH=${HRRRE_DIR}
#  export FCST_LENGTH=${FCST_LENGTH}
#  export CHGRES_ROOT=${CHGRES_ROOT}
#  export CHGRES_STATIC=${STATIC_DIR_CHGRES}
#  export GFS_INDEX=0
#  export DATAHOME=${DATAROOT_INI}/${INIT_DATE}_DA
#  export PROC=$(( 2 * ${COREPERNODE} ))
#  #export BEGPROC=$(( ${isub} * ${COREPERNODE} * 2 ))
#  export OMP_THREADS_NUM=1
#
#  module load netcdf/4.7.4
#
#  ${SCRIPTS}/CHGRES/chgres_cube_DAbndy.ksh
#
#  error=\$?
#  if [ \${error} -ne 0 ]; then
#    echo "error" > \${DATAHOME}/FAILED
#  else
#    echo "done" > \${DATAHOME}/SUCCESS
#  fi
#EOF
#    #chmod u+x ${LOG_DIR}/chgres_dabndy.sh
#
#    ${showcmd} sbatch ${LOG_DIR}/chgres_dabndy.sh
  fi
#
#  #chmod -R g+rx ${DATAROOT_INI}
#
#  echo "Waiting for ${DATAROOT_INI}/${INIT_DATE}_DA/SUCCESS ...."
#  while [ ! -e ${DATAROOT_INI}/${INIT_DATE}_DA/SUCCESS ] ; do
#    sleep 20
#  done
##  cd ${DATAROOT_INI}
##  ln -sf ${DATAROOT_INI}/${INIT_DATE}_0 ${INIT_DATE}_DA

  touch ${DATABASE_DIR}/READY_FOR_SYSTEM2

  ymd=${BEG_DATE:0:8}
  hhr=${BEG_DATE:8:2}
  min=${BEG_DATE:10:2}

  icycle=3
  while [ ${icycle} -le 99 ]; do

    minfrombeg=$(( DA_INTV*icycle ))

    thiscycle=$(date +%Y%m%d%H%M -d "${ymd} ${hhr}:${min} ${minfrombeg} minutes")
    ymdthis=`echo ${thiscycle} | cut -c1-8`
    hhrthis=`echo ${thiscycle} | cut -c9-10`
    minthis=`echo ${thiscycle} | cut -c11-12`
    if [[ $icycle -gt 1 ]]; then
        minfromlast=${DA_INTV}
    else
        minfromlast=60
    fi
    lastcycle=$(date +%Y%m%d%H%M -d "${ymdthis} ${hhrthis}:${minthis} ${minfromlast} minutes ago")
    FCST_LENG=$(( minfromlast*60 ))

    conv_only=1

    #
    # cycle break
    #
    if [ ${thiscycle} -gt ${END_DATE} ]; then
      echo "DA finished !"
      break
    fi

    if [ ${if_skip_convobs} == 'no' ]; then
      echo 'Copy prepbufr file for cycle '${thiscycle}' at --- ' `date +%Y-%m-%d_%H:%M`
      export START_TIME=${thiscycle}
      export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}/obsprd
      export PREPBUFR=${PREPBUFR_DIR}
      export EARLY=0
      ${SCRIPTS}/GSI/conventional.ksh
    fi

    SBATCHSELLDIR=${DATABASE_DIR}/cycle/${thiscycle}/shdir
    mkdir -p ${SBATCHSELLDIR}

    cd ${SBATCHSELLDIR}

    if [ ${if_skip_fv3} == 'no' ]; then

      # --- run wrf.exe for each member
      echo 'Forecasting to cycle '${thiscycle}' at --- ' `date +%Y-%m-%d_%H:%M`

      flagdate=`date -u +%Y%m%d%H00 -d "${INIT_DATE:0:8} ${INIT_DATE:8:2}  1 hours"`

      imem=1
      isub=0
      sub_mem=1
      ens_size=${ENSSIZE_REAL}

      corenum=100

      rm -f ${SBATCHSELLDIR}/fv3_${thiscycle}_m*sh

      while [ ${imem} -le ${ens_size}  ]; do

        memstr4=$(printf "%04d" ${imem})

        cat << EOF > ${SBATCHSELLDIR}/fv3_${thiscycle}_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J fv3_${icycle}-$memstr4
#SBATCH -o ./jobfv3_${icycle}-${memstr4}_%j.out
#SBATCH -e ./jobfv3_${icycle}-${memstr4}_%j.err
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
        #chmod u+x ${SBATCHSELLDIR}/fv3_${thiscycle}_${imem}.sh

        #(( isub += 1 ))
        #echo ${SBATCHSELLDIR}/fv3_${thiscycle}_${imem}.sh" >& "${SBATCHSELLDIR}/fv3_${thiscycle}_${imem}."log &" \
        #      >> ${SBATCHSELLDIR}/fv3_${thiscycle}_m${sub_mem}.sh
        sleep 1
        #if [ ${isub} -ge 10 ] || [ ${imem} -eq ${ens_size} ] ; then
        #  echo "wait" >> ${SBATCHSELLDIR}/fv3_${thiscycle}_m${sub_mem}.sh
        #  sleep 3
        #  isub=0
        #  sub_mem=`expr ${sub_mem} + 1`
        #fi
        sbatch ${SBATCHSELLDIR}/fv3_${thiscycle}_${memstr4}.sh

        (( imem += 1 ))
      done


      #ig=1
      #while [ ${ig} -le $(( ${sub_mem} - 1 )) ]; do
      #  chmod u+x ${SBATCHSELLDIR}/fv3_${thiscycle}_m${ig}.sh
      #  ${SBATCHSELLDIR}/fv3_${thiscycle}_m${ig}.sh >& ${SBATCHSELLDIR}/fv3_${thiscycle}_m${ig}.log
      #  (( ig = ig + 1 ))
      #done

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

    if [ $conv_only -eq 1 ] ; then
      conv_radar_flag=1
    fi

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
      TASKNUM_enkf=240
      QUEUE_enkf=${QUEUE1}
      RESNAME_enkf=${SBATCH_OPT}
      OMPTHREADS_enkf=14

    fi


    if [ ${if_skip_fgmean} == 'no' ]; then
      echo "Calculate mean of first-guess ensemble for cycle ${thiscycle} at ---  $(date +%Y-%m-%d_%H:%M)"
      cat << EOF > ${SBATCHSELLDIR}/fg_mean${thiscycle}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J fg_mean${thiscycle}
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
       gsiprdname=gsiprd_radar_d01
    else
       gsiprdname=gsiprd_d01
    fi

    if [ ${if_skip_gsimean} == 'no' ]; then

      nodenum=5
      corenum=96

      echo 'Generate Hx for ensmean for cycle '${thiscycle}' at --- ' `date +%Y-%m-%d_%H:%M`
      cat << EOF > ${SBATCHSELLDIR}/gsi_mean${thiscycle}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J gsi_mean${thiscycle}
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
      echo 'Generate Hx for each member for cycle '${thiscycle}' at --- ' `date +%Y-%m-%d_%H:%M`

      nodenum=5
      corenum=96

      imem=1
      isub=0
      sub_mem=1
      ens_size=${ENSSIZE_REAL}

      rm -f ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_m*sh

      while [ ${imem} -le ${ens_size}  ]; do

        memstr4=$(printf "%04d" ${imem})

        echo 'Member-'${imem}

        cat << EOF > ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J gsi_mem${memstr4}_${thiscycle}
#SBATCH -o ./jobgsi_mem${thiscycle}_${memstr4}_%j.out
#SBATCH -e ./jobgsi_mem${thiscycle}_${memstr4}_%j.err
#SBATCH -n ${corenum}
#SBATCH --partition=${QUEUE}
#SBATCH -t 01:30:00

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
        #chmod u+x ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_${imem}.sh
        sbatch ${SBATCHSELLDIR}/gsi_mem${thiscycle}_${memstr4}.sh

        #(( isub += 1 ))
        ##echo ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_${imem}.sh " >& "${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_${imem}.log" &" \
        ##           >> ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_m${sub_mem}.sh
        #sleep 1
        #if [ ${isub} -ge 9 ] || [ ${imem} -eq ${ens_size} ] ; then
        #  isub=0
        #  #echo "wait" >> ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_m${sub_mem}.sh
        #  sub_mem=`expr ${sub_mem} + 1`
        #fi

        (( imem += 1 ))
      done

      successcnt=$(ls ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_* | wc -l)
      echo "waiting for ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_* ..."
      while [[ $successcnt -lt ${ens_size} ]]; do
          echo "${successcnt} members run gsi.x successfully."
          sleep 10
          successcnt=$(ls ${DATABASE_DIR}/cycle/${thiscycle}/${gsiprdname}/SUCCESS_* | wc -l)
      done

      #ig=1
      #while [ ${ig} -le $(( ${sub_mem} - 1 )) ]; do
      #  chmod u+x ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_m${ig}.sh
      #  ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_m${ig}.sh >& ${SBATCHSELLDIR}/gsi_${thiscycle}_${conv_radar_flag}_m${ig}.log
      #  (( ig = ig + 1 ))
      #done

    fi

    if [ ${if_skip_enkf} == 'no' ]; then

      echo 'Run EnKF for cycle '${thiscycle}' at --- ' `date +%Y-%m-%d_%H:%M`
      cat << EOF > ${SBATCHSELLDIR}/EnKF${thiscycle}_${conv_radar_flag}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J EnKF${thiscycle}_${conv_radar_flag}
#SBATCH -o ./jobEnKF${thiscycle}_${conv_radar_flag}_%j.out
#SBATCH -e ./jobEnKF${thiscycle}_${conv_radar_flag}_%j.err
#SBATCH -n ${TASKNUM_enkf}
#SBATCH --partition=${QUEUE}
#SBATCH -t 04:30:00

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

    echo "Waiting for ${DATABASE_DIR}/cycle/${thiscycle}/enkfSUCCESS ...."
    while [ ! -e "${DATABASE_DIR}/cycle/${thiscycle}/enkfSUCCESS" ] ; do
      sleep 20
    done


    if [ ${if_skip_recenter} == 'no'  ]; then
      echo 'Recenter procedure for cycle '${thiscycle}' at --- ' `date +%Y-%m-%d_%H:%M`

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
      echo 'Generate updated BC files for each member at --- ' `date +%Y-%m-%d_%H:%M`

      imem=0
      isub=0
      sub_mem=1
      ens_size=${ENSSIZE_REAL}
      while [ ${imem} -le ${ens_size}  ]; do
        memstr4=$(printf "%03d" $imem)

        cat << EOF > ${SBATCHSELLDIR}/moveda${thiscycle}_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J moveda${thiscycle}_${memstr4}
#SBATCH -o ./moveda${thiscycle}_${memstr4}_%j.out
#SBATCH -e ./lmoveda${thiscycle}_${memstr4}_%j.err
#SBATCH -n 1
#SBATCH --partition=${QUEUE}
#SBATCH -t 02:30:00

  export START_TIME=${thiscycle}
  export GSI_ROOT=${GSI_ROOT}
  export HOME_ROOT=${DATABASE_DIR}/cycle
  export WORK_ROOT=\${HOME_ROOT}/\${START_TIME}/movedaprd/movedaprd_${imem}
  export MEM_INDEX=${imem}
  export PROC=1
  #export BEGPROC=$(( ${isub} * 1 ))
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
        #chmod u+x ${SBATCHSELLDIR}/moveda${thiscycle}_${imem}.sh

        #(( isub += 1 ))
        #echo ${SBATCHSELLDIR}/moveda${thiscycle}_${imem}.sh" >& "${SBATCHSELLDIR}/moveda${thiscycle}_${imem}."log &" \
        #      >> ${SBATCHSELLDIR}/moveda${thiscycle}_m${sub_mem}.sh
        #sleep 1
        #if [ ${isub} -ge 37 ] || [ ${imem} -eq ${ens_size} ] ; then
        #  echo "wait" >> ${SBATCHSELLDIR}/moveda${thiscycle}_m${sub_mem}.sh
        #  sleep 3
        #  isub=0
        #  sub_mem=`expr ${sub_mem} + 1`
        #fi
        sbatch ${SBATCHSELLDIR}/moveda${thiscycle}_${memstr4}.sh

        (( imem += 1 ))
      done

      #ig=1
      #while [ ${ig} -le $(( ${sub_mem} - 1 )) ]; do
      #  chmod u+x ${SBATCHSELLDIR}/moveda${thiscycle}_m${ig}.sh
      #  ${SBATCHSELLDIR}/moveda${thiscycle}_m${ig}.sh > ${SBATCHSELLDIR}/moveda${thiscycle}_m${ig}.log
      #  (( ig = ig + 1 ))
      #done

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

# --- Free forecast
# ---

ifcst=6
ens_size_fcst=4
FCST_DATE=${END_DATE}
FCST_LENG=$(( ifcst*3600 ))

if [ ${if_skip_fcst6h} == 'no' ]; then
  echo "Start longer forecast at --- $(date +%Y-%m-%d_%H:%M)"

  # --- run wrf.exe for each member
  imem=1
  corenum=240

  rm -f ${LOG_DIR}/fv3fcst_*sh
  cd ${LOG_DIR}

  while [ ${imem} -le ${ens_size_fcst}  ]; do

    memstr4=$(printf "%04d" $imem)

    cat << EOF > ${LOG_DIR}/fv3fcst_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J fv3fcst_${memstr4}
#SBATCH -o ./jobfv3fcst_${memstr4}_%j.out
#SBATCH -e ./jobfv3fcst_${memstr4}_%j.err
#SBATCH -n ${corenum}
#SBATCH --partition=${QUEUE}
#SBATCH -t 04:30:00

  export INIT_TIME=${INIT_DATE}
  export START_TIME=${FCST_DATE}
  export FCST_LENGTH=${FCST_LENG}
  export FV3LAM_ROOT=${FV3LAM_ROOT}
  export FV3LAM_STATIC=${STATIC_DIR_FV3LAM}
  export DATAHOME=${DATABASE_DIR}
  export INIHOME=${DATAROOT_INI}
  export ENS_MEM_START=${imem}
  export ENS_MEMNUM_THIS=1
  export PROC=${corenum}

  memstr4=${memstr4}

  ${SCRIPTS}/FV3LAM/fv3lam_fcst.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem${memstr4}/FAILED
  else
    echo "" > ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem${memstr4}/SUCCESS
  fi

EOF
    #chmod u+x ${LOG_DIR}/fv3fcst_${imem}.sh
    sbatch ${LOG_DIR}/fv3fcst_${memstr4}.sh

    (( imem += 1 ))

  done
  #${LOG_DIR}/fv3fcst_0.sh >& ${LOG_DIR}/fv3fcst_0.log &
  #${LOG_DIR}/fv3fcst_1.sh >& ${LOG_DIR}/fv3fcst_1.log &
  #${LOG_DIR}/fv3fcst_2.sh >& ${LOG_DIR}/fv3fcst_2.log &
  #${LOG_DIR}/fv3fcst_3.sh >& ${LOG_DIR}/fv3fcst_3.log &
  #${LOG_DIR}/fv3fcst_4.sh >& ${LOG_DIR}/fv3fcst_4.log &
  #wait

  success_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/SUCCESS 2>/dev/null | wc -l`
  echo "Waiting for ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/SUCCESS ...."
  while [ ${success_size} -lt ${ens_size_fcst} ]; do
      echo "${success_size} memebers run fv3fcst successfully."
      sleep 10
      fail_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/FAILED 2>/dev/null | wc -l`
      while [ ${fail_size} -gt 0 ]; do
        echo "${fail_size} members run fv3fcst failed."
        sleep 60
        fail_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/FAILED 2>/dev/null | wc -l`
      done
      success_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/SUCCESS 2>/dev/null | wc -l`
  done
fi

exit 0
# --- Postprocessing
# ---
if [ ${if_skip_upp} == 'no' ]; then
  echo 'Post-processing at --- ' `date +%Y-%m-%d_%H:%M`

  freefcst_hour=$(( FCST_LENG/3600 ))
  inihr=`echo ${FCST_DATE} | cut -c9-10`
  RESULTSHOME=${DATABASE_DIR}/${FCST_DATE}

  ihr=0
  while [ ${ihr} -le ${freefcst_hour} ]; do

    hour_str2=`printf %02i ${ihr}`
    hour_str3=`printf %03i ${ihr}`
    flg_fcst=logf${hour_str3}
    flg_postbeg=postbeg.${hour_str2}
    flg_postdone=postdone.${hour_str2}
    ensemble_size=10

    count_submit=0
    while [ ${count_submit} -lt ${ensemble_size} ]; do
      imem=0
      while [ ${imem} -lt ${ensemble_size} ];do
        memstr4=`printf %04i ${imem}`
        memrundir=${RESULTSHOME}/fv3prd_mem${memstr4}

        while [ ! -e ${memrundir}/${flg_fcst} ]; do
          sleep 3
        done

        if [ -e ${memrundir}/${flg_fcst} ] && \
           [ ! -e ${memrundir}/${flg_postbeg} ] && \
           [ ! -e ${memrundir}/${flg_postdone} ]; then
          cat > ${memrundir}/upp_${imem}_${ihr}.sh << EOF
#!/bin/bash

  export START_TIME=${FCST_DATE}
  export FCST_TIME=${ihr}
  export EXE_ROOT=${EXEC}/UPP
  export DATAHOME=${DATABASE_DIR}/${FCST_DATE}
  export DOMAIN=1
  export MEMBER=${imem}
  export STATIC_DIR=${STATIC_DIR}/UPP
  export SCRIPT_UPP=${SCRIPTS}/UPP
  export PROC=14
  export OMP_NUM_THREADS=4
  export BEGPROC=$(( 5040 + ${imem} * 56 ))
  export NODEPATH=${LOG_DIR}

  ${SCRIPTS}/UPP/unipost_ens.ksh

EOF
          chmod u+x ${memrundir}/upp_${imem}_${ihr}.sh
          echo "Start to run UPP for member: "${imem}" at "${ihr} > ${memrundir}/${flg_postbeg}

          ${memrundir}/upp_${imem}_${ihr}.sh >& ${LOG_DIR}/upp_${ihr}_${imem}.log &

          (( count_submit = count_submit + 1 ))
          (( imem = imem + 1 ))

        else
          #sleep 3
          if [ -e ${memrundir}/${flg_fcst} ] && \
             [ -e ${memrundir}/${flg_postbeg} ] && \
             [ -e ${memrundir}/${flg_postdone} ]; then
             (( imem = imem + 1 ))
             (( count_submit = count_submit + 1 ))
          fi
        fi
      done
    done

    count_num=`ls -l ${RESULTSHOME}/fv3prd_mem*/${flg_postdone} 2>/dev/null | wc -l`
    while [ ${count_num} -lt ${ensemble_size} ]; do
      sleep 5
      count_num=`ls -l ${RESULTSHOME}/fv3prd_mem*/${flg_postdone} 2>/dev/null | wc -l`
    done
    (( ihr = ihr + 1 ))
  done
fi

exit
#--- Clean

. $HOMEBASE_DIR/system_env.dat_rt

ymd=${INIT_DATE:0:8}
hhr=${INIT_DATE:8:2}
min=${INIT_DATE:10:2}


save_wrf_cycle=201804300000
icycle=1
while [ ${icycle} -le 99 ]; do

  thiscycle=`date +%Y%m%d%H%M -d "${ymd} ${hhr}:${min} ${DA_INTV} minutes"`
  ymdthis=`echo ${thiscycle} | cut -c1-8`
  hhrthis=`echo ${thiscycle} | cut -c9-10`
  minthis=`echo ${thiscycle} | cut -c11-12`
  lastcycle=`date +%Y%m%d%H%M -d "${ymdthis} ${hhrthis}:${minthis} ${DA_INTV} minutes ago"`
  nextcycle=`date +%Y%m%d%H%M -d "${ymdthis} ${hhrthis}:${minthis} ${DA_INTV} minutes"`
  if [ ${nextcycle} -eq ${radar_cycle_date} ]; then
    save_wrf_cycle=${thiscycle}
  fi

  if [ ${thiscycle} -gt ${END_DATE} ]; then
    echo "DA finished !"
    break
  fi

  keepwrf=0
  if [ ${thiscycle} -eq ${END_DATE} ] || [ ${thiscycle} -eq ${save_wrf_cycle}  ] ; then
    keepwrf=1
  fi
  cat > ${LOG_DIR}/clean_${thiscycle}.sh << EOF
#! /bin/sh
#SBATCH -J clean_${thiscycle}
#SBATCH -o ${LOG_DIR}/clean_${thiscycle}.log
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=${QUEUE1}
#SBATCH -t 3:00:00
#SBATCH -A ${ACCOUNT}
#${SBATCH_OPT}

export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}
export KEEPWRF=${keepwrf}
export NEXTDATE=${nextcycle}
export THSIDATE=${thiscycle}

${SCRIPTS}/UPP/clean.ksh

EOF

  sbatch ${LOG_DIR}/clean_${thiscycle}.sh

  (( icycle = icycle + 1  ))

  if [ ${thiscycle} -ge ${radar_cycle_date} ] && [ ${thiscycle} -le ${END_DATE} ]; then
    DA_INTV=${radar_cycle_intv}
  fi
  ymd=`echo ${thiscycle} | cut -c1-8`
  hhr=`echo ${thiscycle} | cut -c9-10`
  min=`echo ${thiscycle} | cut -c11-12`
done

#

#cd ${DATABASE_DIR}
#tar -cvf Pre_data.tar ensemble_BG prepbufr  radar

# ----------------------------- EoF --------------------------
