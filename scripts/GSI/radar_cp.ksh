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

vcoords=("00.50" "00.75" "01.00" "01.25" "01.50" "01.75" "02.00" "02.25" "02.50" "02.75" \
         "03.00" "03.50" "04.00" "04.50" "05.00" "05.50" "06.00" "06.50" "07.00" "07.50" \
         "08.00" "08.50" "09.00" "10.00" "11.00" "12.00" "13.00" "14.00" "15.00" "16.00" \
         "17.00" "18.00" "19.00")

startsec=$(${DATE} +"%s" -d "${START_TIME}")
endsec=$(${DATE} +"%s" -d "${START_TIME} 10 minutes ago")
n=0
for vlev in ${vcoords[@]}; do
    for ((i=startsec;i>=endsec;i-=60));do
        mrmstimestr=$(${DATE} +"%Y%m%d-%H%M%S" -d @$i)
        mrmsfile="${NSSLMOSAICNC}/Reflectivity3D/$vlev/${mrmstimestr}.netcdf"
        echo "Checking $mrmsfile ..."
        if [[ -r $mrmsfile ]]; then
            echo "Found $mrmsfile."
            let n+=1
            if [[ $n -eq 1 ]]; then
                gridtimestr=$(${DATE} +"%Y%m%d%H%M" -d @$i)
                out3dnc="${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc"
                outlist="${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.txt"
                echo "$vlev" > $outlist
            fi
            echo "$mrmsfile" >> $outlist
            break
        fi
    done
done

echo "Found $n MRMS file at $gridtimestr"
echo "$out3dnc"
echo "$outlist"

if [[ $n -ne 33 ]]; then
    exit 1
fi

export exec_fp=${GSIEXEC}/merge3d.x
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/netcdf/4.7.4/intel/18.0.5/lib

echo "Running '${exec_fp} $outlist $out3dnc' in $(pwd) ...."
#${MPIRUN} -n ${PROC} -o ${BEGPROC} ${exec_fp} ${BNDY_IND}
${MPIRUN} -n 1 ${exec_fp} ${outlist} ${out3dnc}

if [[ -e ${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc  ]]; then
  echo "Coying ${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc to $(pwd)/Gridded_ref.nc ...."
  ${LN} -sf ${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc Gridded_ref.nc
fi

#${CP} ${NSSLMOSAICNC}/Gridded_ref_${YYYY}${MM}${DD}${HH}${mm}.nc dbz.nc
#${GSIEXEC}/process_remove.exe
tagtime=$(${DATE} +"%Y%m%d%H%M" -d "${START_TIME}")
echo "${NSSLMOSAICNC}/Reflectivity3D/Gridded_ref_${gridtimestr}.nc" > ${tagtime}



exit 0
