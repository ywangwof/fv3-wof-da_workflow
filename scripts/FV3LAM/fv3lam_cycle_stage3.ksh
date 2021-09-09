#! /bin/ksh

# Set up paths to shell commands
LS=/bin/ls
LN=/bin/ln
RM=/bin/rm
MKDIR=/bin/mkdir
CP=/bin/cp
MV=/bin/mv
ECHO=/bin/echo
CAT=/bin/cat
GREP=/bin/grep
CUT=`which cut`
AWK="/bin/gawk --posix"
SED=/bin/sed
DATE=/bin/date

# Set up some constants
exec_prep_DA=${FV3LAM_ROOT}/prep_for_regional_DA.x

if [ ${INIT_TIME} -eq ${START_TIME} ]; then
  COLD_START=1
elif [ ${INIT_TIME} -lt ${START_TIME} ]; then
  COLD_START=0  # warm start
else
  echo "Check the correctness of INIT_TIME=" ${INIT_TIME}
  exit 1
fi



# Convert INIT_TIME from 'YYYYMMDDHH' format to Unix date format, e.g. "Fri May  6 19:50:23 GMT 2005"
if [ `${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{12}$/'` ]; then
  START_TIME=`${ECHO} "${START_TIME}" | ${SED} 's/\([[:digit:]]\{4\}\)$/ \1/' | ${SED} 's/\([[:digit:]]\{2\}\)$/:\1/'`
elif [ ! "`${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{8}[[:blank:]]{1}[[:digit:]]{2}[[:punct:]]{1}[[:digit:]]{2}$/'`" ]; then
  ${ECHO} "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhhmn' or 'yyyymmdd hh:mn' format"
  exit 1
fi

if [ `${ECHO} "${INIT_TIME}" | ${AWK} '/^[[:digit:]]{12}$/'` ]; then
  INIT_TIME=`${ECHO} "${INIT_TIME}" | ${SED} 's/\([[:digit:]]\{4\}\)$/ \1/' | ${SED} 's/\([[:digit:]]\{2\}\)$/:\1/'`
elif [ ! "`${ECHO} "${INIT_TIME}" | ${AWK} '/^[[:digit:]]{8}[[:blank:]]{1}[[:digit:]]{2}[[:punct:]]{1}[[:digit:]]{2}$/'`" ]; then
  ${ECHO} "ERROR: start time, '${INIT_TIME}', is not in 'yyyymmddhhmn' or 'yyyymmdd hh:mn' format"
  exit 1
fi
INIT_TIME=`${DATE} -d "${INIT_TIME}"`
INIT_YYYYMMDDHH=`${DATE} +"%Y%m%d%H" -d "${INIT_TIME}"`
INIT_YYYYMMDDHHMM=`${DATE} +"%Y%m%d%H%M" -d "${INIT_TIME}"`
INIT_SEC=`${DATE} +"%s" -d "${INIT_TIME}"`

START_TIME=`${DATE} -d "${START_TIME}"`
START_YYYYMMDDHH=`${DATE} +"%Y%m%d%H" -d "${START_TIME}"`
START_YYYYMMDDHHMM=`${DATE} +"%Y%m%d%H%M" -d "${START_TIME}"`
START_SEC=`${DATE} +"%s" -d "${START_TIME}"`

# Get the end time strings
END_TIME=`${DATE} -d "${START_TIME} ${FCST_LENGTH} hours"`
END_YYYYMMDDHH=`${DATE} +"%Y%m%d%H" -d "${END_TIME}"`
END_YYYYMMDDHHMM=`${DATE} +"%Y%m%d%H%M" -d "${END_TIME}"`
END_SEC=`${DATE} +"%s" -d "${END_TIME}"`

BNDY_TMP=$(( $START_SEC - $INIT_SEC ))
BNDY_BEG=$(( ${BNDY_TMP} / 3600 ))

BNDY_TMP=$(( $END_SEC - $INIT_SEC ))
BNDY_END=$(( ${BNDY_TMP} / 3600 ))


# Get the start and end time components
start_year=`${DATE} +%Y -d "${START_TIME}"`
start_month=`${DATE} +%m -d "${START_TIME}"`
start_day=`${DATE} +%d -d "${START_TIME}"`
start_hour=`${DATE} +%H -d "${START_TIME}"`
start_minute=`${DATE} +%M -d "${START_TIME}"`
start_second=`${DATE} +%S -d "${START_TIME}"`
end_year=`${DATE} +%Y -d "${END_TIME}"`
end_month=`${DATE} +%m -d "${END_TIME}"`
end_day=`${DATE} +%d -d "${END_TIME}"`
end_hour=`${DATE} +%H -d "${END_TIME}"`
end_minute=`${DATE} +%M -d "${END_TIME}"`
end_second=`${DATE} +%S -d "${END_TIME}"`

init_year=`${DATE} +%Y -d "${INIT_TIME}"`
init_month=`${DATE} +%m -d "${INIT_TIME}"`
init_day=`${DATE} +%d -d "${INIT_TIME}"`
init_hour=`${DATE} +%H -d "${INIT_TIME}"`
init_minute=`${DATE} +%M -d "${INIT_TIME}"`
init_second=`${DATE} +%S -d "${INIT_TIME}"`

# Print run parameters
${ECHO}
${ECHO} "fv3_arw_run.ksh started at `${DATE}`"
${ECHO}
${ECHO} "FV3_ROOT        = ${FV3LAM_ROOT}"
${ECHO} "STATIC_DIR_FV3LAM  = ${FV3LAM_STATIC}"
${ECHO} "DATAHOME        = ${DATAHOME}"
${ECHO} "ENS_MEM_START   = ${ENS_MEM_START}"
${ECHO} "ENS_MEMNUM_THIS = ${ENS_MEMNUM_THIS}"
${ECHO} "FCST_LENGTH     = ${FCST_LENGTH}"
${ECHO} "START TIME      = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${START_TIME}"`
${ECHO} "END TIME        = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${END_TIME}"`
${ECHO} "COLD/WARM RUN   = "${COLD_START}
${ECHO}

# loop over ensemble members
ensmem=${ENS_MEM_START}
(( end_member = ${ENS_MEM_START} + ${ENS_MEMNUM_THIS} ))

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/netcdf/4.7.4/intel/18.0.5/lib

while [[ $ensmem -lt $end_member ]];do

  print "\$ensmem is $ensmem"
  ensmemid=`printf %4.4i $ensmem`

  workdir=${DATAHOME}/${START_YYYYMMDDHHMM}/fv3prd_mem${ensmemid}

  ${ECHO} "start run ${workdir}"
  cd ${workdir}

  workdir=${DATAHOME}/${END_YYYYMMDDHHMM}/fv3prd_mem${ensmemid}

  if [ -d ${workdir} ]; then
    echo "removing pre-existing member directory at end time"
    ${RM} -rf ${workdir}
  fi
  echo "creating member directory at end time"
  ${MKDIR} -p ${workdir}/GUESS ${workdir}/ANA
  GUESSdir=${workdir}/GUESS
  ANLdir=${workdir}/ANA

  #cp ${FV3LAM_STATIC}/grid_spec.nc .
  cp grid_spec.nc $GUESSdir/.
  cp grid_spec.nc RESTART/.
  cd RESTART
  mv coupler.res $GUESSdir/.
  mv fv_core.res.nc $GUESSdir/.
  mv fv_core.res.tile1.nc $GUESSdir/.
  mv fv_tracer.res.tile1.nc $GUESSdir/.
  cp sfc_data.nc $GUESSdir/.
  # Now move orig sized sfc_data file to ANLdir since GSI job will now only use
  # bigger one
  cp sfc_data.nc $ANLdir/sfc_data.nc
  cp ../INPUT/gfs_ctrl.nc $ANLdir/

  #Move enlarged restart files for 00-h BC's
  mv fv_tracer.res.tile1_new.nc $GUESSdir/.
  mv fv_core.res.tile1_new.nc $GUESSdir/.

  # Make enlarged sfc file
  mv sfc_data.nc sfc_data_orig.nc
  mv grid_spec.nc grid_spec_orig.nc

  ${CP} -s ${FV3LAM_STATIC}/Fix_sar/C3337_grid.tile7.halo3.nc grid.tile7.halo3.nc
  echo "running ${exec_prep_DA} for $ensmem ...."
  ${exec_prep_DA}

  mv sfc_data_new.nc $GUESSdir/sfc_data_new.nc
  mv grid_spec_new.nc $GUESSdir/grid_spec_new.nc
  mv phy_data.nc $GUESSdir/

  # These are not used in GSI but are needed to warmstart FV3
  # so they go directly into ANLdir
  #mv phy_data.nc $ANLdir/phy_data.nc
  mv fv_srf_wnd.res.tile1.nc $ANLdir/fv_srf_wnd.res.tile1.nc
  mv ../INPUT/gfs_bndy.tile7.001.nc $ANLdir/

  # next member
  (( ensmem += 1 ))
done

if [ -e ${DATAHOME}/${END_YYYYMMDDHHMM}/obsprd/${END_YYYYMMDDHHMM} ] && \
   [ ! -e ${DATAHOME}/${END_YYYYMMDDHHMM}/obsprd/${END_YYYYMMDDHHMM}_CONV ]; then
   $ECHO "" > ${DATAHOME}/${END_YYYYMMDDHHMM}/READY_RADAR_DA
fi
if [ -e ${DATAHOME}/${END_YYYYMMDDHHMM}/obsprd/${END_YYYYMMDDHHMM}_CONV ]; then
   $ECHO "" > ${DATAHOME}/${END_YYYYMMDDHHMM}/READY_CONV_DA
fi

exit 0
