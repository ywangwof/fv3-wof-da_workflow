#!/bin/ksh --login

# Set paths to unix commands
ECHO=/bin/echo
MKDIR=/bin/mkdir
RM=/bin/rm
LN=/bin/ln
CP=/bin/cp
DATE=/bin/date
AWK="/bin/awk --posix"
SED=/bin/sed

# Make sure DATAHOME is defined
if [ ! "${DATAHOME}" ]; then
  ${ECHO} "ERROR: \$DATAHOME is not defined!"
  exit 1
fi

# Make sure START_TIME is defined and in the correct format
if [ ! "${START_TIME}" ]; then
  ${ECHO} "ERROR: \$START_TIME is not defined!"
  exit 1
else
  if [ `${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{12}$/'` ]; then
    START_TIME=`${ECHO} "${START_TIME}" | ${SED} 's/\([[:digit:]]\{4\}\)$/ \1/' | ${SED} 's/\([[:digit:]]\{2\}\)$/:\1/'`
  elif [ ! "`${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{8}[[:blank:]]{1}[[:digit:]]{2}[[:punct:]]{1}[[:digit:]]{2}$/'`" ]; then
    ${ECHO} "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhhmn' or 'yyyymmdd hh:mn' format"
    exit 1
  fi
  START_TIME=`${DATE} -d "${START_TIME}"`
fi

# Make sure PREPBUFR is defined and that the directory exists
if [ ! "${PREPBUFR}" ]; then
  ${ECHO} "ERROR: \$PREPBUFR is not defined"
  exit 1
fi
if [ ! -d "${PREPBUFR}" ]; then
  ${ECHO} "ERROR: directory '${PREPBUFR}' does not exist!"
  exit 1
fi
#if [ ! "${PREPBUFR_SAT}" ]; then
#  ${ECHO} "ERROR: \$PREPBUFR_SAT is not defined"
#  exit 1
#fi
#if [ ! -d "${PREPBUFR_SAT}" ]; then
#  ${ECHO} "ERROR: directory '${PREPBUFR_SAT}' does not exist!"
#  exit 1
#fi
if [ ! "${EARLY}" ]; then
  ${ECHO} "ERROR: \$EARLY is not defined"
  exit 1
fi

# Make sure the ssrc executable exists
#if [ ! -x "${SSRC}" ]; then
#  ${ECHO} "ERROR: ${SSRC} does not exist!"
#  exit 1
#fi

# Create the obsprd directory if necessary and cd into it
if [ ! -d "${DATAHOME}" ]; then
  ${MKDIR} -p ${DATAHOME}
fi
cd ${DATAHOME}

# Compute date & time components for prepbufr filename
YYYYJJJHH00=`${DATE} +"%Y%j%H00" -d "${START_TIME}"`
YYYYMMDD=`${DATE} +"%Y%m%d" -d "${START_TIME}"`
HH=`${DATE} +"%H" -d "${START_TIME}"`
YYJJJHH=`${DATE} +"%y%j%H" -d "${START_TIME}"`

# Copy the prepbufr to obs directory so we never do I/O to /public directly
if [ ${EARLY} -eq 0 ]; then
  rm -f newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
  #if [ -e ${PREPBUFR}/prep${YYYYMMDD}${HH}_1 ]; then
  #  ${LN} -s ${PREPBUFR}/prep${YYYYMMDD}${HH}_1 newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
  #else
  #  ${CP} ${PREPBUFR}/${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD} .
  #  ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
  #fi

  if [ -e ${PREPBUFR}/rtma.${YYYYMMDD}${HH}00.prepbufr.tm00 ]; then
      # RTMA data
      echo "Linking ${PREPBUFR}/rtma.${YYYYMMDD}${HH}00.prepbufr.tm00 to $(pwd) ..."
      ${LN} -s ${PREPBUFR}/rtma.${YYYYMMDD}${HH}00.prepbufr.tm00 newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
  elif [ -e ${PREPBUFR}/rap.${YYYYMMDD}${HH}.prepbufr.tm00 ]; then
      # RAP data
      echo "Linking ${PREPBUFR}/rap.${YYYYMMDD}${HH}.prepbufr.tm00 to $(pwd) ..."
      ${LN} -s ${PREPBUFR}/rap.${YYYYMMDD}${HH}.prepbufr.tm00 newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
  fi
fi

echo "" > ${YYYYMMDD}${HH}00_CONV

exit 0
if [ ${EARLY} -eq 0 ]; then
  if [ -r "${PREPBUFR}_test/${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test" ]; then
    ${CP} ${PREPBUFR}_test/${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test .
    ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
  else
    if [ -r "${PREPBUFR}_test/${YYYYJJJHH00}.ruc2a.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test" ]; then
      ${CP} ${PREPBUFR}_test/${YYYYJJJHH00}.ruc2a.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test .
      ${LN} -s ${YYYYJJJHH00}.ruc2a.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
    else
      if [ -r "${PREPBUFR}/${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD}" ]; then
        ${ECHO} "Warning: ${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test does not exist!"
        ${CP} ${PREPBUFR}/${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD} .
        ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
      else
        if [ -r "${PREPBUFR}/${YYYYJJJHH00}.ruc2a.t${HH}z.prepbufr.tm00.${YYYYMMDD}" ]; then
          ${ECHO} "Warning: ${YYYYJJJHH00}.ruc2a.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test does not exist!"
          ${CP} ${PREPBUFR}/${YYYYJJJHH00}.ruc2a.t${HH}z.prepbufr.tm00.${YYYYMMDD} .
          ${LN} -s ${YYYYJJJHH00}.ruc2a.t${HH}z.prepbufr.tm00.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
        else
          ${ECHO} "Warning: ${YYYYJJJHH00}.rap.t${HH}z.prepbufr.tm00.${YYYYMMDD} does not exist!"
          ${ECHO} "ERROR: No prepbufr files exist!"
          exit 1
        fi
      fi
    fi
  fi
else
  if [ ${EARLY} -eq 1 ]; then
    if [ -r "${PREPBUFR}_test/${YYYYJJJHH00}.rap_e.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test" ]; then
      ${CP} ${PREPBUFR}_test/${YYYYJJJHH00}.rap_e.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test .
      ${LN} -s ${YYYYJJJHH00}.rap_e.t${HH}z.prepbufr.tm00.${YYYYMMDD}.test newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
    else
      if [ -r "${PREPBUFR}/${YYYYJJJHH00}.rap_e.t${HH}z.prepbufr.tm00.${YYYYMMDD}" ]; then
        ${CP} ${PREPBUFR}/${YYYYJJJHH00}.rap_e.t${HH}z.prepbufr.tm00.${YYYYMMDD} .
        ${LN} -s ${YYYYJJJHH00}.rap_e.t${HH}z.prepbufr.tm00.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
      else
        ${ECHO} "Warning: ${YYYYJJJHH00}.rap_e.t${HH}z.prepbufr.tm00.${YYYYMMDD} does not exist!"
        ${ECHO} "ERROR: No prepbufr files exist!"
        exit 1
      fi
    fi
  else
    ${ECHO} "ERROR: EARLY ${EARLY} is not defined or invalid"
    exit 1
  fi
fi

#${CP} newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr prepbufr_wfip

# Set links to radiance data if available
#if [ -r "${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bamua.tm00.bufr_d.${YYYYMMDD}" ]; then
#  ${CP} ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bamua.tm00.bufr_d.${YYYYMMDD} .
#  ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.1bamua.tm00.bufr_d.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.1bamua
#else
#  ${ECHO} "Warning: ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bamua.tm00.bufr_d.${YYYYMMDD} dones not exist!"
#fi

#if [ -r "${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bamub.tm00.bufr_d.${YYYYMMDD}" ]; then
#  ${CP} ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bamub.tm00.bufr_d.${YYYYMMDD} .
#  ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.1bamub.tm00.bufr_d.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.1bamub
#else
#  ${ECHO} "Warning: ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bamub.tm00.bufr_d.${YYYYMMDD} dones not exist!"
#fi

#if [ -r "${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bhrs3.tm00.bufr_d.${YYYYMMDD}" ]; then
#  ${CP} ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bhrs3.tm00.bufr_d.${YYYYMMDD} .
#  ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.1bhrs3.tm00.bufr_d.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.1bhrs3
#else
#  ${ECHO} "Warning: ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bhrs3.tm00.bufr_d.${YYYYMMDD} dones not exist!"
#fi

#if [ -r "${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bhrs4.tm00.bufr_d.${YYYYMMDD}" ]; then
#  ${CP} ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bhrs4.tm00.bufr_d.${YYYYMMDD} .
#  ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.1bhrs4.tm00.bufr_d.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.1bhrs4
#else
#  ${ECHO} "Warning: ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bhrs4.tm00.bufr_d.${YYYYMMDD} dones not exist!"
#fi

#if [ -r "${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bmhs.tm00.bufr_d.${YYYYMMDD}" ]; then
#  ${CP} ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bmhs.tm00.bufr_d.${YYYYMMDD} .
#  ${LN} -s ${YYYYJJJHH00}.rap.t${HH}z.1bmhs.tm00.bufr_d.${YYYYMMDD} newgblav.${YYYYMMDD}.rap.t${HH}z.1bmhs
#else
#  ${ECHO} "Warning: ${PREPBUFR_SAT}/${YYYYJJJHH00}.rap.t${HH}z.1bmhs.tm00.bufr_d.${YYYYMMDD} dones not exist!"
#fi

# Add nacelle, tower and sodar observations if available
#if [ -r "${NACELLE_RSD}/${YYJJJHH}000010o" ]; then
#  ${LN} -s ${NACELLE_RSD}/${YYJJJHH}000010o ./nacelle_restriced.nc
#  ${CP} ${GSI_ROOT}/process_nacelledata_rt.exe .
#  ./process_nacelledata_rt.exe > stdout_nacelledata
#  ${RM} -f nacelle_restriced.nc
#else
#  ${ECHO} "Warning: ${NACELLE_RSD}/${YYJJJHH}000010o does not exist!"
#fi

#if [ -r "${TOWER_RSD}/${YYJJJHH}000010o" ]; then
#  ${LN} -s ${TOWER_RSD}/${YYJJJHH}000010o ./tower_restricted.nc
#  ${LN} -s ${TOWER_RSD}/${YYJJJHH}000010o ./tower_data.nc
#  ${CP} ${GSI_ROOT}/process_towerdata_rt.exe .
#  ./process_towerdata_rt.exe > stdout_tower_re
#  ${RM} -f tower_restricted.nc
#  ${RM} -f tower_data.nc
#else
#  ${ECHO} "Warning: ${TOWER_RSD}/${YYJJJHH}000010o does not exist!"
#fi

#if [ -r "${TOWER_NRSD}/${YYJJJHH}000100o" ]; then
#  ${LN} -s ${TOWER_NRSD}/${YYJJJHH}000100o ./tower_public.nc
#  ${LN} -s ${TOWER_NRSD}/${YYJJJHH}000100o ./tower_data.nc
#  ${CP} ${GSI_ROOT}/process_towerdata_rt.exe .
#  ./process_towerdata_rt.exe > stdout_tower_nr
#  ${RM} -f tower_public.nc
#  ${RM} -f tower_data.nc
#else
#  ${ECHO} "Warning: ${TOWER_NRSD}/${YYJJJHH}000100o does not exist!"
#fi

#if [ -r "${SODAR_NRSD}/${YYJJJHH}000015o" ]; then
#  ${LN} -s ${SODAR_NRSD}/${YYJJJHH}000015o ./sodar_data.nc
#  ${CP} ${GSI_ROOT}/process_sodardata_rt.exe .
#  ./process_sodardata_rt.exe > stdout_sodar_nr
#  ${RM} -f sodar_data.nc
#else
#  ${ECHO} "Warning: ${SODAR_NRSD}/${YYJJJHH}000015o does not exist!"
#fi

exit 0
