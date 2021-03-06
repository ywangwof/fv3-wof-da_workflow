#! /bin/ksh --login

module list

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
MPIRUN="srun"
numtry=1
keeptmp=false

# Set up some constants
export exec_fp=${CHGRES_ROOT}/chgres_cube.exe

#if [ ${GFS_INDEX} -gt 20 ] ; then
#   START_TIME_BG=${START_TIME_OTHER}
#fi

FCST_LENGTH_HR=$(bc -l <<< "${FCST_LENGTH}/3600" )

# Print run parameters
${ECHO}
${ECHO} "chgres_cube.ksh started at `${DATE}`"
${ECHO}
${ECHO} "CHGRES_ROOT    = ${CHGRES_ROOT}"
${ECHO} "DATAHOME       = ${DATAHOME}"
${ECHO} "SOURCE_PATH    = ${SOURCE_PATH}"
${ECHO} "GFS_INDEX/ENSID= ${GFS_INDEX}"
${ECHO} "FCST_TIME      = ${FCST_TIME}"
${ECHO} "START_TIME     = ${START_TIME}"
${ECHO} "FCST_LENGTH    = ${FCST_LENGTH}"
${ECHO} "FCST_LENGTH_HR = ${FCST_LENGTH_HR}"
if [ "${GFS_INDEX}" ]; then
  ${ECHO} "GFS_INDEX      = ${GFS_INDEX}"
else
  GFS_INDEX=0
fi
${ECHO}

TILE_RGNL=7
NH0=0

# Make sure the START_TIME is in the correct format
if [ `${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{12}$/'` ]; then
  START_TIME=`${ECHO} "${START_TIME}" | ${SED} 's/\([[:digit:]]\{4\}\)$/ \1/' | ${SED} 's/\([[:digit:]]\{2\}\)$/:\1/'`
elif [ ! "`${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{8}[[:blank:]]{1}[[:digit:]]{2}[[:punct:]]{1}[[:digit:]]{2}$/'`" ]; then
  ${ECHO} "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhhmn' or 'yyyymmdd hh:mn' format"
  exit 1
fi

if [ `${ECHO} "${START_TIME_BG}" | ${AWK} '/^[[:digit:]]{12}$/'` ]; then
  START_TIME_BG=`${ECHO} "${START_TIME_BG}" | ${SED} 's/\([[:digit:]]\{4\}\)$/ \1/' | ${SED} 's/\([[:digit:]]\{2\}\)$/:\1/'`
elif [ ! "`${ECHO} "${START_TIME_BG}" | ${AWK} '/^[[:digit:]]{8}[[:blank:]]{1}[[:digit:]]{2}[[:punct:]]{1}[[:digit:]]{2}$/'`" ]; then
  ${ECHO} "ERROR: start time bg, '${START_TIME_BG}', is not in 'yyyymmddhhmn' or 'yyyymmdd hh:mn' format"
  exit 1
fi

echo `${DATE} -d "${START_TIME}"`

BGTIMESEC=`${DATE} +%s -d "${START_TIME_BG}"`
CATIMESEC=`${DATE} +%s -d "${START_TIME}"`

if [ ${CATIMESEC} -lt ${BGTIMESEC} ]; then
   ${ECHO} "ERROR: Check "${START_TIME_BG}", which should not be later than "${START_TIME}
   exit 1
fi

DIFF_HR=$(( ( ${CATIMESEC} - ${BGTIMESEC} ) / 3600  ))
${ECHO} "DIFF_HR " ${DIFF_HR}

#if [ $GFS_INDEX -le 20 ] && [ $GFS_INDEX -ge 0 ]; then
   #FORMAT="gep"
   FORMAT="wrfnat_mem"
#elif [ $GFS_INDEX -ge 21 ]; then
#   FORMAT="sre"
#fi
#FCST_INTERVAL=1

if [[ $GFS_INDEX -eq 0 ]]; then
    ensmemid_ic=$(printf "%04d" $GFS_INDEX)
    GFS_INDEX=4
else
    ensmemid_ic=$(printf "%04d" $GFS_INDEX)
fi

imem=$(( GFS_INDEX % 9 ))    # boundary HRRRE files only have 9 members
if [[ $imem -eq 0 ]]; then
    imem=9
fi

ensmemid=$(printf "%04d" $imem)
#cd ${SOURCE_PATH}/1200/postprd_mem${ensmemid}
##grib_files=`${LS} -1 ${FORMAT}${ensmemid}.t??z.pgrb?f?? | sort`
#grib_files=`${LS} -1 ${FORMAT}${ensmemid}_????.grib2 | sort`
#cd ${workdir}
#${ECHO} "grib_files = ${grib_files}"
#ngribfiles=0
#for file in ${grib_files}; do
#   #fhour=`${ECHO} ${file} | ${CUT} -c18-19`
#   fhour=`${ECHO} ${file} | ${CUT} -c16-17`
#   if (( fhour >= DIFF_HR )) then
#     if (( (fhour-DIFF_HR <= FCST_LENGTH_HR) )) ; then
#        gribfiles[${ngribfiles}]=${file}
#        (( ngribfiles=ngribfiles + 1 ))
#     fi
#   fi
#done
hrrredir="${SOURCE_PATH}/1200/postprd_mem${ensmemid}"
gribfile="${FORMAT}${ensmemid}_${FCST_TIME}.grib2"

${ECHO} "FORMAT    = ${FORMAT}"
${ECHO} "HRRREDIR  = ${hrrredir}"
${ECHO} "gribfile  = ${gribfile}"
format_found=1

# Set up the work directory and cd into it
workdir=${DATAHOME}/chgresprd
#${RM} -rf ${workdir}
${MKDIR} -p ${workdir}
cd ${workdir}

if [[ $THISYEAR =~ "2020" ]]; then
    geofile="geo_em.d02.nc_HRRRX"
else
    geofile="geo_em.d01.nc_HRRRX"
fi


#-----------------------------------------------------------------------
# Processing LBCs file at one time
#-----------------------------------------------------------------------

${MKDIR} -p LBCS

${LN} -sf ${hrrredir}/${gribfile} LBCS/${gribfile}

fcst_hr=${FCST_TIME:0:2}
fcst_min=${FCST_TIME:2:2}
fcst_mins=$(( fcst_hr*60+fcst_min ))

THISTIME_sec=$(${DATE} +%s -d "${START_TIME_BG} ${fcst_mins} minutes")
THISTIME=$(${DATE} +%Y%m%d%H%M -d "${START_TIME_BG} ${fcst_mins} minutes")
echo "Processing LBC file ${gribfile} valid at ${THISTIME} ...."

mkdir -p tmp_LBCS_${FCST_TIME}
cd tmp_LBCS_${FCST_TIME}

rm -f ./fort.41

cat << EOF > ./fort.41
&config
    convert_atm = .true.
    convert_nst = .false.
    convert_sfc = .false.
    cycle_mon = ${THISTIME:4:2}
    cycle_day = ${THISTIME:6:2}
    cycle_hour = ${THISTIME:8:2}
    data_dir_input_grid = '${workdir}/LBCS'
    external_model = 'HRRR'
    fix_dir_target_grid = '${CHGRES_STATIC}/Fix_sar.${eventdate}'
    geogrid_file_input_grid = '${CHGRES_STATIC}/${geofile}'
    grib2_file_input_grid = '${gribfile}'
    halo_blend = 10
    halo_bndy = 4
    input_type = 'grib2'
    mosaic_file_input_grid = ''
    mosaic_file_target_grid = '${CHGRES_STATIC}/Fix_sar.${eventdate}/C3337_mosaic.halo4.nc'
    orog_dir_input_grid = ''
    orog_dir_target_grid = '${CHGRES_STATIC}/Fix_sar.${eventdate}'
    orog_files_target_grid = 'C3337_oro_data.tile7.halo4.nc'
    varmap_file='${CHGRES_STATIC}/GSDphys_var_map.txt'
    regional = 2
    tg3_from_soil = .false.
    tracers = ''
    tracers_input = ''
    vcoord_file_target_grid = '${CHGRES_STATIC}/global_hyblev.l65.txt'
/
EOF

# Run chgres_cube
itry=1
while [[ ${itry} -le ${numtry} ]] ; do
  echo "Running ${exec_fp} in $(pwd) for itry=${itry} ...."
  ${MPIRUN} -n $PROC ${exec_fp} > CHGRES_LBC_${FCST_TIME}.log

  error=$?
  if [ ${error} -eq 0 ]; then
     break
  fi
  (( itry = itry + 1  ))
done

sleep 5
if [ ${error} -ne 0 ]; then
  ${ECHO} "ERROR: CHGRES exited with status: ${error}"
  exit ${error}
else
  #${RM} -f PET*LogFile

  fcst_secs=$(( THISTIME_sec-CATIMESEC ))   # relative seconds to START_TIME
  fcst_hhh=$(( fcst_secs/3600 ))
  fcst_min=$(( (fcst_secs%3600)/60 ))
  bndy1=$( printf "%02d:%02d" $fcst_hhh $fcst_min)
  ${MV} gfs.bndy.nc ${workdir}/gfs_bndy.tile${TILE_RGNL}.${bndy1}.nc
fi

cd ${workdir}
if ! $keeptmp; then
    rm -rf tmp_LBCS_${FCST_TIME}
fi



