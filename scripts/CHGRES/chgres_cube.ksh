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
cd ${SOURCE_PATH}/1200/postprd_mem${ensmemid}
#grib_files=`${LS} -1 ${FORMAT}${ensmemid}.t??z.pgrb?f?? | sort`
grib_files=`${LS} -1 ${FORMAT}${ensmemid}_????.grib2 | sort`
cd ${workdir}
${ECHO} "grib_files = ${grib_files}"
ngribfiles=0
for file in ${grib_files}; do
   #fhour=`${ECHO} ${file} | ${CUT} -c18-19`
   fhour=`${ECHO} ${file} | ${CUT} -c16-17`
   if (( fhour >= DIFF_HR )) then
     if (( (fhour-DIFF_HR <= FCST_LENGTH_HR) )) ; then
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

${MKDIR} -p ICS
icfile="wrfnat_hrrre_newse_mem${ensmemid_ic}_01.grib2"
gribfiles[0]=${icfile}
${LN} -sf ${SOURCE_PATH}/1400/postprd_mem${ensmemid_ic}/${gribfiles[0]}  ICS/${gribfiles[0]}

THISTIME=`${DATE} +%Y%m%d%H%M -d "${START_TIME}"`
echo "Processing IC file: ${gribfiles[0]} at ${THISTIME} ...."

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
    fix_dir_target_grid = '${CHGRES_STATIC}/Fix_sar'
    geogrid_file_input_grid = '${CHGRES_STATIC}/geo_em.d01.nc_HRRRX'
    grib2_file_input_grid = '${gribfiles[0]}'
    halo_bndy = 4
    input_type = 'grib2'
    mosaic_file_input_grid = ''
    mosaic_file_target_grid = '${CHGRES_STATIC}/Fix_sar/C3337_mosaic.halo4.nc'
    nsoill_out = 4
    halo_blend = 10
    halo_bndy = 4
    orog_dir_input_grid = ''
    orog_dir_target_grid = '${CHGRES_STATIC}/Fix_sar'
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

# Run metgrid
itry=1
while [ ${itry} -le 1 ] ; do
  echo "Running ${exec_fp} in $(pwd) for IC at itry=${itry} ..."
  #${MPIRUN} -n $PROC -o $BEGPROC ${exec_fp} > CHGRES_IC.log
  ${MPIRUN} -n $PROC ${exec_fp} > CHGRES_IC.log

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

  ${MKDIR} -p PETLOG
  ${MV} -f PET*LogFile PETLOG/

  ${MV} out.atm.tile${TILE_RGNL}.nc \
        gfs_data.tile${TILE_RGNL}.halo${NH0}.nc
  ${MV} out.sfc.tile${TILE_RGNL}.nc \
        sfc_data.tile${TILE_RGNL}.halo${NH0}.nc
  ${MV} gfs.bndy.nc gfs_bndy.tile${TILE_RGNL}.000.nc

fi

# --- LBCs generation

#${ngribfiles}

${MKDIR} -p LBCS

ifile=1
while [ ${ifile} -lt ${ngribfiles} ]
do
  #if [ $GFS_INDEX -le 20 ] ; then
  #wgrib2 -match "(1000 mb|975 mb|950 mb|925 mb|900 mb|850 mb|800 mb|750 mb|700 mb|650 mb|600 mb|550 mb|500 mb|450 mb|400 mb|350 mb|300 mb|250 mb|200 mb|150 mb|100 mb|70 mb|50 mb|30 mb|20 mb|10 mb|7 mb|5 mb|3 mb|2 mb|1 mb|PRMSL|2 m a|10 m a|surface|0-0.1 m|0.1-0.4 m|0.4-1 m|1-2 m)" \
   #-match "(UGRD|VGRD|VVEL|TMP|RH|HGT|PRMSL|PRES|CLWMR|O3MR|TSOIL|SOILW|SNOD|SNOWC|SNOHF|LAND|ICETK|ICEC|WEASD)" \
   #${SOURCE_PATH}/${gribfiles[${ifile}]} -grib LBCS/${gribfiles[${ifile}]}
   #wgrib2 ${SOURCE_PATH}/${gribfiles[${ifile}]} -match "SPFH" -match "2 m above" -append -grib LBCS/${gribfiles[${ifile}]} -quit
  #else
    ${LN} -sf ${SOURCE_PATH}/1200/postprd_mem${ensmemid}/${gribfiles[${ifile}]} LBCS/${gribfiles[${ifile}]}
  #fi

  THISTIME=`${DATE} +%Y%m%d%H%M -d "${START_TIME} $(( ${ifile} * ${FCST_INTERVAL} )) minutes"`
  echo "Processing file $ifile: ${gribfiles[${ifile}]} at ${THISTIME} ...."
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
    external_model = 'HRRR'
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
  while [ ${itry} -le 1 ] ; do
    echo "Running ${exec_fp} in $(pwd) for LBC at itry=${itry} ...."
    #${MPIRUN} -n $PROC -o $BEGPROC ${exec_fp} > CHGRES_LBC_${ifile}.log
    ${MPIRUN} -n $PROC ${exec_fp} > CHGRES_LBC_${ifile}.log

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

    fcst_min=$(( ifile * FCST_INTERVAL ))
    fcst_hhh=$(( fcst_min/60 ))
    fcst_min=$(( fcst_min-fcst_hhh*60 ))
    bndy1=$( printf "%02d:%02d" $fcst_hhh $fcst_min)
    #$( printf "%03d" "$(( ${ifile} * ${FCST_INTERVAL} ))" )
    ${MV} gfs.bndy.nc gfs_bndy.tile${TILE_RGNL}.${bndy1}.nc

  fi


  (( ifile = ifile + 1  ))
done


######### EOF ###########
