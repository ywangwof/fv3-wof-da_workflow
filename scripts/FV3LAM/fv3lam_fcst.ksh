#! /bin/ksh

source /etc/profile.d/modules.sh
source /lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap/ufs-srweather-app/env/build_jet_intel.env
module use -a /lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap/ufs-srweather-app/env
module load build_jet.env
module load pnetcdf/1.11.2

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
MPIRUN=srun

# Set up some constants
exec_fp=${FV3LAM_ROOT}/ufs_weather_model.${CCPP_SUITE}
exec_create_restart=${FV3LAM_ROOT}/create_expanded_restart_files_for_DA.x
exec_prep_DA=${FV3LAM_ROOT}/prep_for_regional_DA.x
NAMELIST_MC=${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/model_configure_fcst
NAMELIST_IN=${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/input.nml_fcst
FIXam=${FV3LAM_STATIC}/fix_am

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
END_TIME=`${DATE} -d "${INIT_TIME} ${FCST_LENGTH} seconds"`
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

FCST_LENGTH_HR=$(bc -l <<< "${FCST_LENGTH}/3600" )   # to keep float number
# Print run parameters
${ECHO}
${ECHO} "fv3_arw_run.ksh started at `${DATE}`"
${ECHO}
${ECHO} "FV3_ROOT        = ${FV3LAM_ROOT}"
${ECHO} "STATIC_DIR_FV3LAM  = ${STATIC_DIR_FV3LAM}"
${ECHO} "DATAHOME        = ${DATAHOME}"
${ECHO} "ENS_MEM_START   = ${ENS_MEM_START}"
${ECHO} "ENS_MEMNUM_THIS = ${ENS_MEMNUM_THIS}"
${ECHO} "FCST_LENGTH_HR  = ${FCST_LENGTH_HR}"
${ECHO} "START TIME      = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${START_TIME}"`
${ECHO} "END TIME        = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${END_TIME}"`
${ECHO}

# loop over ensemble members
ensmem=${ENS_MEM_START}
(( end_member = ${ENS_MEM_START} + ${ENS_MEMNUM_THIS} ))

while [[ $ensmem -lt $end_member ]];do

 print "\$ensmem is $ensmem"
 ensmemid=`printf %4.4i $ensmem`
 member="mem"`printf %03i $ensmem`

 workdir=${DATAHOME}/${START_YYYYMMDDHHMM}/fv3prd_mem${ensmemid}
 cycledir=${DATAHOME}/cycle/${START_YYYYMMDDHHMM}/fv3prd_mem${ensmemid}
 if [ ! -d ${workdir} ]; then
    ${MKDIR} -p ${workdir}
 fi
 ${MKDIR} -p ${workdir}/INPUT
 ${MKDIR} -p ${workdir}/RESTART
 cd ${workdir}/INPUT
 #${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_DA/chgresprd/gfs_bndy.tile7*.nc .
 ${CP} -s  ${FV3LAM_STATIC}/Fix_sar.${eventdate}/C3337_mosaic.halo3.nc grid_spec.nc
 ${CP} -s  ${FV3LAM_STATIC}/Fix_sar.${eventdate}/C3337_grid.tile7.halo3.nc C3337_grid.tile7.halo3.nc
 ${CP} -s  ${FV3LAM_STATIC}/Fix_sar.${eventdate}/C3337_grid.tile7.halo4.nc grid.tile7.halo4.nc
 ${CP} -s  ${FV3LAM_STATIC}/Fix_sar.${eventdate}/C3337_oro_data.tile7.halo0.nc oro_data.nc
 ${CP} -s  ${FV3LAM_STATIC}/Fix_sar.${eventdate}/C3337_oro_data.tile7.halo4.nc oro_data.tile7.halo4.nc
 ${LN} -sf ${FV3LAM_STATIC}/Fix_sar.${eventdate}/C3337_oro_data_ss.tile7.halo0.nc oro_data_ss.nc
 ${LN} -sf ${FV3LAM_STATIC}/Fix_sar.${eventdate}/C3337_oro_data_ls.tile7.halo0.nc oro_data_ls.nc

 if [ ${COLD_START} -eq 1 ]; then
   ${LN} -s ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_data.tile7.halo0.nc .
   ${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_data.tile7.halo0.nc ./gfs_data.nc
   ${LN} -s ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/sfc_data.tile7.halo0.nc .
   ${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/sfc_data.tile7.halo0.nc ./sfc_data.nc
   ${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_ctrl.nc .
   rm -f gfs_bndy.tile7.000.nc
   #${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_DA/chgresprd/gfs_bndy.tile7.000.nc .
   #${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_DA/chgresprd/gfs_bndy.tile7.001.nc .
   ${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_${ensmem}/chgresprd/gfs_bndy.tile7.000.nc .
   ${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_${ensmem}/chgresprd/gfs_bndy.tile7.001.nc .
 else
   #cd ${workdir}/INPUT
   #${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_bndy.tile7.*.nc ./INPUT/
   ${LN} -sf ${cycledir}/ANA/coupler.res coupler.res
   ${LN} -sf ${cycledir}/ANA/fv_core.res.nc fv_core.res.nc
   ${LN} -sf ${cycledir}/ANA/fv_core.res.tile1.nc fv_core.res.tile1.nc
   ${LN} -sf ${cycledir}/ANA/fv_srf_wnd.res.tile1.nc fv_srf_wnd.res.tile1.nc
   ${LN} -sf ${cycledir}/ANA/fv_tracer.res.tile1.nc fv_tracer.res.tile1.nc
   ${LN} -sf ${cycledir}/ANA/phy_data.nc phy_data.nc
   ${LN} -sf ${cycledir}/ANA/sfc_data.nc sfc_data.nc
   ${LN} -sf ${cycledir}/ANA/fv_core.res.tile1_new.nc .
   ${LN} -sf ${cycledir}/ANA/fv_tracer.res.tile1_new.nc .
   ${CP} -f  ${cycledir}/ANA/gfs_bndy.tile7.*nc .

   echo "Rename ${cycledir}/ANA/gfs_bndy.tile7.001.nc to INPUT/gfs_bndy.tile7.000.nc ..."
   mv -f gfs_bndy.tile7.001.nc     gfs_bndy.tile7.000.nc
   mv -f gfs_bndy.tile7.001_gsi.nc gfs_bndy.tile7.000_gsi.nc

   #if [ ${BNDY_BEG} -eq 3 ]; then
   #   tot_fhr=39
   #else
   #   tot_fhr=36
   #fi
   tot_fhr=$(( FCST_LENGTH/3600 ))

   ifhr=0
   for (( ifhr=1;ifhr<=tot_fhr;ifhr++)); do
   #while [ ${ifhr} -le ${tot_fhr} ]; do
     #bndy1=$(printf "%03d" $(( 10#${BNDY_BEG} + 10#${ifhr} )) )
     #bndy2=$(printf "%03d" $(( 10#${ifhr} + 1 )) )
     bndy1=$(printf "%02d:00" $(( BNDY_BEG+ifhr)) )
     bndy2=$(printf "%03d" $ifhr)
     echo "Copy ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_bndy.tile7.${bndy1}.nc to gfs_bndy.tile7.${bndy2}.nc ..."
     ${CP} -f ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_bndy.tile7.${bndy1}.nc ./gfs_bndy.tile7.${bndy2}.nc
   done

   ${LN} -sf ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_data.tile7.halo0.nc gfs_data.nc
   ${LN} -sf ${INIHOME}/${INIT_YYYYMMDDHHMM}_$ensmem/chgresprd/gfs_ctrl.nc             .
 fi

 ${ECHO} "start run ${workdir}"
 cd ${workdir}

 # --- Static files

 ${LN} -sf ${FIXam}/global_climaeropac_global.txt .
 iy=2010
 while [ ${iy} -le 2021 ]; do
   ${LN} -sf ${FIXam}/fix_co2_proj/global_co2historicaldata_${iy}.txt co2historicaldata_${iy}.txt
   (( iy = iy + 1  ))
 done
 ${LN} -sf ${FIXam}/global_climaeropac_global.txt aerosol.dat
 ${LN} -sf ${FIXam}/global_co2historicaldata_glob.txt co2historicaldata_glob.txt
 ${LN} -sf ${FIXam}/co2monthlycyc.txt co2monthlycyc.txt
 ${LN} -sf ${FIXam}/global_h2o_pltc.f77 global_h2oprdlos.f77
 ${LN} -sf ${FIXam}/global_zorclim.1x1.grb global_zorclim.1x1.grb
 ${LN} -sf ${FIXam}/global_sfc_emissivity_idx.txt sfc_emissivity_idx.txt
 ${LN} -sf ${FIXam}/global_solarconstant_noaa_an.txt solarconstant_noaa_an.txt
 ${LN} -sf ${FIXam}/global_o3prdlos.f77 global_o3prdlos.f77
 ${LN} -sf ${FIXam}/CCN_ACTIVATE.BIN .

 # --- CCPP suite
 if [[ ${CCPP_SUITE} =~ "HRRR" ]]; then
     ${LN} -sf ${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/suite_FV3_HRRR.xml .
 else
     ${LN} -sf ${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/suite_FV3_RRFS_v1nssl_lsmnoah.xml .
 fi

 # --- Others
 ${CP} -f ${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/data_table .
 ${CP} -f ${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/diag_table .
 ${CP} -f ${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/field_table .
 ${CP} -f ${FV3LAM_STATIC}/freezeH2O.dat .
 ${CP} -f ${FV3LAM_STATIC}/qr_acr_qg.dat .
 ${CP} -f ${FV3LAM_STATIC}/qr_acr_qs.dat .
 ${CP} -f ${FV3LAM_STATIC}/qr_acr_qgV2.dat .
 ${CP} -f ${FV3LAM_STATIC}/qr_acr_qsV2.dat .
 ${CP} -f ${FV3LAM_STATIC}/FV3_${CCPP_SUITE}/nems.configure .

 if [ ${COLD_START} -eq 1 ]; then
   make_nh='.true.'
   na_init=1
   external_ic='.true.'
   nggps_ic='.true.'
   mountain='.false.'
   warm_start='.false.'
   writebcs='.true.'
   bcsgsi='.false.'
   lsoil=4
   nstf2=1
 else
   make_nh='.false.'
   na_init=0
   external_ic='.false.'
   nggps_ic='.false.'
   mountain='.true.'
   warm_start='.true.'
   writebcs='.false.'
   bcsgsi='.true.'
   if [[ ${CCPP_SUITE} =~ "HRRR" ]]; then
       lsoil=9
   else
       lsoil=4
   fi

   nstf2=0
 fi

 # --- model_configure
 sed 's/_YEAR_/'${start_year}'/g' ${NAMELIST_MC} | \
 sed 's/_MON_/'${start_month}'/g'  | \
 sed 's/_DAY_/'${start_day}'/g'    | \
 sed 's/_HOUR_/'${start_hour}'/g'  | \
 sed 's/_MIN_/'${start_minute}'/g' | \
 sed 's/_RESTART_INTV_/0/g'        | \
 sed 's/_FCSTLEN_/'${FCST_LENGTH_HR}'/g' > ./model_configure

 # --- input.nml
 sed 's/_EXTERNAL_IC_/'${external_ic}'/g'  ${NAMELIST_IN} | \
 sed 's/_MAKE_NH_/'${make_nh}'/g'     | \
 sed 's/_BC_INTV_/1/g'                | \
 sed 's/_MOUNTAIN_/'${mountain}'/g'   | \
 sed 's/_NA_INIT_/'${na_init}'/g'     | \
 sed 's/_NGGPS_IC_/'${nggps_ic}'/g'   | \
 sed 's/_LSOIL_/'${lsoil}'/g'         | \
 sed 's/_NSTF2_/'${nstf2}'/g'         | \
 sed 's/_WARM_START_/'${warm_start}'/g' | \
 sed 's/_WRITE_BCS_/'${writebcs}'/g'    | \
 sed 's/_BCS_GSI_/'${bcsgsi}'/g'  > ./input.nml

 source ${FV3LAM_STATIC}/Fix_sar.${eventdate}/model_grid.${eventdate}
 sed -i "/target_lat/s/=.*/= $cen_lat/;/target_lon/s/=.*/= $cen_lon/" ./input.nml
 sed -i "/cen_lat/s/:.*/: $cen_lat/;/cen_lon/s/:.*/: $cen_lon/;/^lat1/s/:.*/: $lat1/;/^lon1/s/:.*/: $lon1/" ./model_configure

 itry=1
 while [ ${itry} -le 3 ] ; do
   #${MPIRUN} -np 550 ${exec_fp} > FV3LAM.log
   echo "Running ${exec_fp} in $(pwd) at itry=${itry} ...."
   #${MPIRUN} -n ${PROC} -o $BEGPROC ${exec_fp} > FV3LAM.log
   ${MPIRUN} -n ${PROC} ${exec_fp} > FV3LAM.log

   error=$?
   if [ ${error} -eq 0 ]; then
      break
   fi
   (( itry = itry + 1  ))
 done
 sleep 5

 if [ ${error} -ne 0 ]; then
   ${ECHO} "ERROR: FV3LAM exited with status: ${error}"
   exit ${error}
 fi

# next member
   (( ensmem += 1 ))
done

exit 0

######### EOF ###########
