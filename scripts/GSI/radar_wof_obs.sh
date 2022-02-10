#!/bin/bash --login

# Vars used for testing.  Should be commented out for production mode

# Set up paths to unix commands
RM=/bin/rm
CP=/bin/cp
MV=/bin/mv
LN=/bin/ln
MKDIR=/bin/mkdir
CAT=/bin/cat
ECHO=/bin/echo
CUT=/bin/cut
WC=/usr/bin/wc
DATE=/bin/date
AWK="/bin/awk --posix"
SED=/bin/sed
MPIRUN=mpiexec

# Make sure DATAHOME is defined and exists
if [ ! "${DATAHOME}" ]; then
  ${ECHO} "ERROR: \$DATAHOME is not defined!"
  exit 1
fi
if [ ! -d "${DATAHOME}" ]; then
  ${ECHO} "NOTE: DATAHOME directory '${DATAHOME}' does not exist! make one!"
fi

# Make sure sub-hourly time is defined and exists
if [ ! "${SUBH_TIME}" ]; then
  ${ECHO} "ERROR: \$SUBH_TIME is not defined!"
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

  START_TIME=`${DATE} -d "${START_TIME} ${SUBH_TIME} minutes"`
fi

#
# Create the obsprd directory if necessary and cd to it
#
if [ ! -d "${DATAHOME}" ]; then
  ${MKDIR} -p ${DATAHOME}
fi
cd ${DATAHOME}

ANALYSIS_TIME=$(${DATE} -d "${START_TIME}" +%Y%m%d%H%M)
#
# copy Radar RF & VR sequency files
#
mrmstimestr=$(${DATE} +"%Y%m%d_%H%M" -d "${START_TIME}")
for dtype in RF VR; do
    obsfile="${OBSDIR}/Radar_${dtype}/obs_seq_${dtype}_${mrmstimestr}.nc"
    if [[ -r $obsfile ]]; then
        ln -sf $obsfile ./obs_seq_${dtype}_${ANALYSIS_TIME}.nc
    else
        echo "File: $obsfile not exist."
        exit 1
    fi
    echo "${obsfile}" >> ${ANALYSIS_TIME}
done

#
# Copy Mesonet files
#
obsfile="${OBSDIR}/Mesonet/mesonet.realtime.${ANALYSIS_TIME}.mdf"
echo "Checking $obsfile ..."
if [[ -r $obsfile ]]; then
    echo "Found $obsfile."
    ln -sf $obsfile ./
else
    echo "File: $obsfile not exist."
    exit 2
fi

echo "${obsfile}" >> ${ANALYSIS_TIME}

exit 0
