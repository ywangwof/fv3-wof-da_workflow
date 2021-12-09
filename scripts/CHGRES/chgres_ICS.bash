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

#DIFF_HR=$(( ( ${CATIMESEC} - ${BGTIMESEC} ) / 3600  ))
#${ECHO} "DIFF_HR " ${DIFF_HR}
#
##if [ $GFS_INDEX -le 20 ] && [ $GFS_INDEX -ge 0 ]; then
#   #FORMAT="gep"
#   FORMAT="wrfnat_mem"
##elif [ $GFS_INDEX -ge 21 ]; then
##   FORMAT="sre"
##fi
##FCST_INTERVAL=1
#
ensmemid_ic=$(printf "%04d" $GFS_INDEX)
#if [[ $GFS_INDEX -eq 0 ]]; then
#    ensmemid_ic=$(printf "%04d" $GFS_INDEX)
#    GFS_INDEX=4
#else
#    ensmemid_ic=$(printf "%04d" $GFS_INDEX)
#fi
#
#imem=$(( GFS_INDEX % 9 ))    # boundary HRRRE files only have 9 members
#if [[ $imem -eq 0 ]]; then
#    imem=9
#fi
#
#ensmemid=$(printf "%04d" $imem)
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
#${ECHO} "FORMAT = ${FORMAT}"
#${ECHO} "ngribfiles = ${ngribfiles}"
#${ECHO} "gribfiles = ${gribfiles[*]}"
#format_found=1

icfile="wrfnat_hrrre_newse_mem${ensmemid_ic}_01.grib2"
#gribfiles[0]=${icfile}

# Set up the work directory and cd into it
workdir=${DATAHOME}/chgresprd
#${RM} -rf ${workdir}
${MKDIR} -p ${workdir}
cd ${workdir}

${RM} -rf ICS tmp_ICS

${MKDIR} -p ICS

${LN} -sf ${SOURCE_PATH}/1400/postprd_mem${ensmemid_ic}/${icfile}  ICS/${icfile}

THISTIME=`${DATE} +%Y%m%d%H%M -d "${START_TIME}"`
THISYEAR=$(${DATE} +%Y -d "${START_TIME}")
echo "Processing IC file: ${icfile} at ${THISTIME} ...."

if [[ $THISYEAR =~ "2020" ]]; then
    geofile="geo_em.d02.nc_HRRRX"
else
    geofile="geo_em.d01.nc_HRRRX"
fi

#-----------------------------------------------------------------------
# Processing ICS
#-----------------------------------------------------------------------

mkdir -p tmp_ICS
cd tmp_ICS

rm -f ./fort.41

cat << EOF > ./fort.41
&config
    convert_atm = .true.
    convert_nst = .false.
    convert_sfc = .true.
    cycle_day = ${THISTIME:6:2}
    cycle_hour = ${THISTIME:8:2}
    cycle_mon = ${THISTIME:4:2}
    data_dir_input_grid = '${workdir}/ICS'
    external_model = 'HRRR'
    fix_dir_target_grid = '${CHGRES_STATIC}/Fix_sar.${eventdate}'
    geogrid_file_input_grid = '${CHGRES_STATIC}/${geofile}'
    grib2_file_input_grid = '${icfile}'
    halo_bndy = 4
    input_type = 'grib2'
    mosaic_file_input_grid = ''
    mosaic_file_target_grid = '${CHGRES_STATIC}/Fix_sar.${eventdate}/C3337_mosaic.halo4.nc'
    nsoill_out = 4
    halo_blend = 10
    halo_bndy = 4
    orog_dir_input_grid = ''
    orog_dir_target_grid = '${CHGRES_STATIC}/Fix_sar.${eventdate}'
    orog_files_target_grid = 'C3337_oro_data.tile7.halo4.nc'
    varmap_file='${CHGRES_STATIC}/GSDphys_var_map.txt'
    regional = 1
    vgtyp_from_climo = .true.
    sotyp_from_climo = .true.
    vgfrc_from_climo = .true.
    minmax_vgfrc_from_climo = .true.
    lai_from_climo = .true.
    tg3_from_soil  = .false.
    tracers = ''
    tracers_input = ''
    vcoord_file_target_grid = '${CHGRES_STATIC}/global_hyblev.l63.txt'
/
EOF

# Run chgres for ICS
itry=1
while [ ${itry} -le $numtry ] ; do
  echo "Running ${exec_fp} in $(pwd) for IC at itry=${itry} ..."
  #${MPIRUN} -n $PROC -o $BEGPROC ${exec_fp} > CHGRES_IC.log
  ${MPIRUN} -n $PROC ${exec_fp} > CHGRES_IC.log

  error=$?
  if [ ${error} -eq 0 ]; then
     break
  fi
  (( itry = itry + 1  ))
done

sleep 10
if [ ${error} -ne 0 ]; then
  ${ECHO} "ERROR: CHGRES exited with status: ${error}"
  exit ${error}
else

  #${MKDIR} -p PETLOG
  #${MV} -f PET*LogFile PETLOG/

  ${MV} out.atm.tile${TILE_RGNL}.nc ${workdir}/gfs_data.tile${TILE_RGNL}.halo${NH0}.nc
  ${MV} out.sfc.tile${TILE_RGNL}.nc ${workdir}/sfc_data.tile${TILE_RGNL}.halo${NH0}.nc
  ${MV} gfs.bndy.nc                 ${workdir}/gfs_bndy.tile${TILE_RGNL}.000.nc
  ${MV} gfs_ctrl.nc                 ${workdir}/gfs_ctrl.nc

fi

cd ${workdir}

if ! $keeptmp; then
    rm -rf tmp_ICS
fi

