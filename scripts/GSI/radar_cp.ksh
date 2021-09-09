#!/bin/ksh --login

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

# Create the obsprd directory if necessary and cd into it
if [ ! -d "${DATAHOME}" ]; then
  ${MKDIR} -p ${DATAHOME}
fi
cd ${DATAHOME}

# Compute date & time components for the analysis time
#YYYYJJJHH00=`${DATE} +"%Y%j%H00" -d "${START_TIME}"`
#YYYYMMDDHH=`${DATE} +"%Y%m%d%H" -d "${START_TIME}"`
#YYYY=`${DATE} +"%Y" -d "${START_TIME}"`
#MM=`${DATE} +"%m" -d "${START_TIME}"`
#DD=`${DATE} +"%d" -d "${START_TIME}"`
#HH=`${DATE} +"%H" -d "${START_TIME}"`
#mm=`${DATE} +"%M" -d "${START_TIME}"`

startsec=$(${DATE} +"%s" -d "${START_TIME}")
endsec=$(${DATE} +"%s" -d "${START_TIME} 10 minutes ago")
for ((i=startsec;i>=endsec;i-=60));do
    mrmstimestr=$(${DATE} +"%Y%m%d-%H%M%S" -d @$i)
    mrmsfile="${NSSLMOSAICNC}/Reflectivity3D/00.50/${mrmstimestr}.netcdf"
    if [[ -r $mrmsfile ]]; then
        echo "Found $mrmsfile."
        gridtimestr=$(${DATE} +"%Y%m%d%H%M" -d @$i)
        break
    fi
done

export exec_fp=${GSIEXEC}/merge3d.x
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/netcdf/4.7.4/intel/18.0.5/lib

echo "Running '${exec_fp} $mrmsfile' in $(pwd) ...."
#${MPIRUN} -n ${PROC} -o ${BEGPROC} ${exec_fp} ${BNDY_IND}
${MPIRUN} -n 1 ${exec_fp} ${mrmsfile}

if [[ -e ${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc  ]]; then
  echo "Coying ${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc to $(pwd)/Gridded_ref.nc ...."
  ${LN} -sf ${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc Gridded_ref.nc
fi

#${CP} ${NSSLMOSAICNC}/Gridded_ref_${YYYY}${MM}${DD}${HH}${mm}.nc dbz.nc
#${GSIEXEC}/process_remove.exe
tagtime=$(${DATE} +"%Y%m%d%H%M" -d "${START_TIME}")
echo "${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc" > ${tagtime}



exit 0
