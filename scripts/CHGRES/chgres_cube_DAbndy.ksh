#! /bin/ksh --login

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
WGRIB2=/lfs4/HFIP/hfv3gfs/nwprod/hpc-stack/libs/intel-18.0.5.274/impi-2018.4.274/wgrib2/2.0.8/bin/wgrib2

# Set up some constants
export exec_fp=${CHGRES_ROOT}/chgres_cube.exe

if [ ${GFS_INDEX} -gt 20 ] ; then
   START_TIME_BG=${START_TIME_BG_OTHER}
fi

# 1 hour longer than DA period to produce ensemble forecast over the end of DA for VTS usage
FCST_LENGTH_HR=$(bc -l <<< "${FCST_LENGTH}/3600+1" )

# Print run parameters
${ECHO}
${ECHO} "chgres_cube.ksh started at `${DATE}`"
${ECHO}
${ECHO} "CHGRES_ROOT    = ${CHGRES_ROOT}"
${ECHO} "DATAHOME       = ${DATAHOME}"
${ECHO} "SOURCE_PATH    = ${SOURCE_PATH}"
${ECHO} "GFS_INDEX/ENSID= ${GFS_INDEX}"
${ECHO} "START_TIME     = ${START_TIME}"
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
  ${ECHO} "ERROR: start time, '${START_TIME_BG}', is not in 'yyyymmddhhmn' or 'yyyymmdd hh:mn' format"
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
#   FORMAT="gfs"
#elif [ $GFS_INDEX -ge 21 ]; then
#   FORMAT="sre"
#fi
FORMAT="wrfnat_mem"
FCST_INTERVAL=1

if [[ $GFS_INDEX -eq 0 ]]; then
    if [[ ${DIFF_HR} -eq 3 ]]; then   # at 1500Z
       ensmemid_ic=$(printf "%04d" $GFS_INDEX)
    else
        ensmemid_ic="0004"
    fi
    GFS_INDEX=4
else
    ensmemid_ic=$(printf "%04d" $GFS_INDEX)
fi

cd ${SOURCE_PATH}/1200/postprd_mem${ensmemid}
ensmemid=$(printf "%04d" $GFS_INDEX)
#grib_files=`${LS} -1 ${FORMAT}.t??z.pgrb?f?? | sort`
grib_files=`${LS} -1 ${FORMAT}${ensmemid}_??.grib2 | sort`
cd ${workdir}
${ECHO} "grib_files = ${grib_files}"
ngribfiles=0
for file in ${grib_files}; do
   #fhour=`${ECHO} ${file} | ${CUT} -c18-19`
   fhour=`${ECHO} ${file} | ${CUT} -c16-17`
   if (( fhour >= DIFF_HR )) then
     if (( (fhour-DIFF_HR <= FCST_LENGTH_HR) && (fhour % FCST_INTERVAL==0) )) ; then
        gribfiles[${ngribfiles}]=${file}
        (( ngribfiles=ngribfiles + 1 ))
     fi
   fi
done
${ECHO} "FORMAT = ${FORMAT}"
${ECHO} "ngribfiles = ${ngribfiles}"
${ECHO} "gribfiles = ${gribfiles[*]}"
format_found=1

# Set up the work directory and cd into it
workdir=${DATAHOME}/chgresprd
${RM} -rf ${workdir}
${MKDIR} -p ${workdir}
cd ${workdir}

# --- LBCs generation

#${ngribfiles}

${MKDIR} -p LBCS

ifile=0
while [ ${ifile} -lt ${ngribfiles} ]
do
  ${LN} -sf ${SOURCE_PATH}/${gribfiles[${ifile}]} LBCS/${gribfiles[${ifile}]}
  THISTIME=`${DATE} +%Y%m%d%H%M -d "${START_TIME} $(( ${ifile} * ${FCST_INTERVAL} )) hours"`
  rm -f ./fort.41

cat << EOF > ./fort.41
&config
    convert_atm = .true.
    convert_nst = .false.
    convert_sfc = .false.
    cycle_day = ${THISTIME:6:2}
    cycle_hour = ${THISTIME:8:2}
    cycle_mon = ${THISTIME:4:2}
    data_dir_input_grid = '${workdir}/LBCS'
    external_model = 'GFS'
    fix_dir_target_grid = '${CHGRES_STATIC}/Fix_sar'
    geogrid_file_input_grid = '${CHGRES_STATIC}/geo_em.d01.nc_HRRRX'
    grib2_file_input_grid = '${gribfiles[${ifile}]}'
    halo_blend = 10
    halo_bndy = 4
    input_type = 'grib2'
    mosaic_file_input_grid = ''
    mosaic_file_target_grid = '${CHGRES_STATIC}/Fix_sar/C3337_mosaic.halo4.nc'
    orog_dir_input_grid = ''
    orog_dir_target_grid = '${CHGRES_STATIC}/Fix_sar'
    orog_files_target_grid = 'C3337_oro_data.tile7.halo4.nc'
    varmap_file='${CHGRES_STATIC}/GSDphys_var_map.txt'
    regional = 2
    tg3_from_soil = .false.
    tracers = ''
    tracers_input = ''
    vcoord_file_target_grid = '${CHGRES_STATIC}/global_hyblev.l63.txt'
/
EOF
  # Run metgrid
  itry=1
  while [ ${itry} -le 3 ] ; do
    #${MPIRUN} -n $PROC -o $BEGPROC ${exec_fp} > CHGRES_LBC_DA.log
    ${MPIRUN} -n $PROC ${exec_fp} > CHGRES_LBC_DA.log

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

    ${RM} -f PET*LogFile

    fcst_hhh=$( printf "%03d" "$(( ${ifile} * ${FCST_INTERVAL} ))" )
    ${MV} gfs.bndy.nc gfs_bndy.tile${TILE_RGNL}.${fcst_hhh}.nc

  fi


  (( ifile = ifile + 1  ))
done


######### EOF ###########
