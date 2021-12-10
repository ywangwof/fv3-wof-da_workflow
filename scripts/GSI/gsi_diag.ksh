#!/bin/ksh --login
##########################################################################
#
#Script Name: wrf_arw_cycle.ksh
#
##########################################################################

# Jet environment specific
source /etc/profile.d/modules.sh
module purge
module load cmake/3.16.1
module load intel/18.0.5.274
module load impi/2018.4.274
module load netcdf/4.7.0 #don't load netcdf/4.7.4 from hpc-stack, GSI does not compile with it.

module use /lfs4/HFIP/hfv3gfs/nwprod/hpc-stack/libs/modulefiles/stack
module load hpc/1.1.0
module load hpc-intel/18.0.5.274
module load hpc-impi/2018.4.274
module load bufr/11.4.0
module load bacio/2.4.1
module load crtm/2.3.0
module load ip/3.3.3
module load nemsio/2.5.2
module load sp/2.3.3
module load w3emc/2.7.3
module load w3nco/2.4.1
module load sfcio/1.4.1
module load sigio/2.3.2
module load wrf_io/1.2.0
module load szip
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/szip/2.1/lib
# End of Jet environment

np=${PROC}

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
BC=/usr/bin/bc
MPIRUN=srun

#set -x

# Check to make sure the required environmental variables for GSI were specified
if [ ! "${GSI_ROOT}" ]; then
  echo "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi
echo "GSI_ROOT = ${GSI_ROOT}"

if [ ! "${STATIC_DIR_GSI}" ]; then
  echo "ERROR: \$STATIC_DIR_GSI is not defined!"
  exit 1
fi
echo "STATIC_DIR_GSI = ${STATIC_DIR_GSI}"

if [ ! "${ANALYSIS_TIME}" ]; then
  echo "ERROR: The variable $ANALYSIS_TIME must be set to the analysis time (YYYYMMDDHH)"
  exit 1
fi
echo "ANALYSIS_TIME = ${ANALYSIS_TIME}"

if [ ! "${WORK_ROOT}" ]; then
  echo "ERROR: \$WORK_ROOT is not defined!"
  exit 1
fi

if [ ${RADAR_ONLY} -eq 1 ]; then
  cd ${WORK_ROOT}
  ${LN} -sf ${DATAHOME}/${ANALYSIS_TIME}/obsprd .
fi

echo "WORK_ROOT = ${WORK_ROOT}"

NUM_DOMAINS=1

if [ ! "${CONV_ONLY}" ]; then
   echo "ERROT: \$CONV_ONLY is not defined"
   exit 1
fi
echo "CONV_ONLY = ${CONV_ONLY}"

if [ ! "${RADAR_ONLY}" ]; then
   echo "ERROT: \$RADAR_ONLY is not defined"
   exit 1
fi
echo "RADAR_ONLY = ${RADAR_ONLY}"

gdate=$ANALYSIS_TIME
YYYYMMDD=`echo $gdate | cut -c1-8`
HH=`echo $gdate | cut -c9-10`

# Set up some constants
FIX_ROOT=${STATIC_DIR_GSI}
GSI_EXE=${GSI_ROOT}/gsi.exe
ensnum=${ENSEMBLE_SIZE}

##############################################################
# run GSI to produce diag files
##############################################################

 echo "run GSI to produce diag files"

 YYYYMMDD=`echo $ANALYSIS_TIME | cut -c1-8`
 echo "YYYYMMDD = ${YYYYMMDD}"
 HH=`echo $ANALYSIS_TIME | cut -c9-10`
 echo "HH = ${HH}"

 OBS_ROOT=${WORK_ROOT}/obsprd
 RADAR_REF=${OBS_ROOT}/Gridded_ref.nc
 RADAR_VR=${OBS_ROOT}/vr_vol

 if [ ${CONV_ONLY} -eq 1 ]; then
   PREPBUFR=${OBS_ROOT}/newgblav.${YYYYMMDD}.rap.t${HH}z.prepbufr
   if [ ! -r "${PREPBUFR}" ]; then
     echo "ERROR: ${PREPBUFR} does not exist!"
     exit 1
   fi
 fi

 if [ ${RADAR_ONLY} -eq 1 ]; then
   if [ ! -r "${RADAR_REF}" ]; then
     echo "ERROR: ${RADAR_REF} does not exist!"
     exit 1
   fi
 fi

 if [ ! "${FIX_ROOT}" ]; then
   echo "ERROR: \$FIX_ROOT is not defined!"
   exit 1
 fi
 if [ ! -d "${FIX_ROOT}" ]; then
   echo "ERROR: fix directory '${FIX_ROOT}' does not exist!"
   exit 1
 fi

 if [ ! -x "${GSI_EXE}" ]; then
   echo "ERROR: ${GSI_EXE} does not exist!"
   exit 1
 fi

 GSI_NAMELIST=${GSI_ROOT}/comgsi_namelist_all.sh
 if_clean=clean
 if_observer=Yes
 RUN_COMMAND="${MPIRUN} "

 DOMAIN=1
 while [[ $DOMAIN -le $NUM_DOMAINS ]];do

     echo "DOMAIN = ${DOMAIN}"

     if [ ${CONV_ONLY} -eq 1 ]; then
       BK_ROOT=${WORK_ROOT}/enkfprd_d0${DOMAIN}
       workdir=${WORK_ROOT}/gsiprd_d0${DOMAIN}
     elif [ ${RADAR_ONLY} -eq 1 ]; then
       BK_ROOT=${WORK_ROOT}/enkfprd_radar_d0${DOMAIN}
       workdir=${WORK_ROOT}/gsiprd_radar_d0${DOMAIN}
     fi

     BK_DYNVAR_FILE=${BK_ROOT}/fv3sar_tile1_ensmean_dynvar
     if [ ! -r "${BK_DYNVAR_FILE}" ]; then
       echo "ERROR: ${BK_DYNVAR_FILE} does not exist!"
       exit 1
     fi

     if [ -d "${workdir}" ]; then
       echo "Remove existing work directory"
       rm -rf ${workdir}
     fi
     echo "Create working directory: ${workdir}"
     mkdir -p ${workdir}
     cd ${workdir}

     ln -sf ${GSI_EXE} gsi.exe
     if [ ${RADAR_ONLY} -eq 1 ]; then
       cp -f ${RADAR_REF} ./dbzobs.nc
       #${LN} -sf ${RADAR_VR} .
     fi
     if [ ${CONV_ONLY} -eq 1 ]; then
       ln -s ${PREPBUFR} ./prepbufr
     fi

     # Bring over background field
     BK_DIR_ct=${WORK_ROOT}/fv3prd_mem0001/GUESS
     cp ${BK_DIR_ct}/coupler.res coupler.res
     cp ${BK_DIR_ct}/fv_core.res.nc fv3_akbk
     cp ${BK_DIR_ct}/grid_spec_new.nc fv3_grid_spec
     cp ${BK_DIR_ct}/sfc_data_new.nc fv3_sfcdata
     ln -sf ${BK_ROOT}/fv3sar_tile1_ensmean_phyvar fv3_phyvars
     ln -sf ${BK_ROOT}/fv3sar_tile1_ensmean_dynvar fv3_dynvars
     ln -sf ${BK_ROOT}/fv3sar_tile1_ensmean_tracer fv3_tracer


     echo "Link fixed and CRTM coefficient files to working directory"
     BERROR=${FIX_ROOT}/rap_berror_stats_global_RAP_tune
     OBERROR=${FIX_ROOT}/HRRRENS_errtable.r3dv
     CONVINFO=${FIX_ROOT}/HRRRENS_regional_convinfo.txt
     if [ ${CONV_ONLY} -eq 1 ]; then
       ANAVINFO=${FIX_ROOT}/anavinfo_fv3_enkf_con
       OBERROR=${FIX_ROOT}/HRRRENS_errtable.r3dv_conv
       CONVINFO=${FIX_ROOT}/HRRRENS_regional_convinfo.3km.txt_conv
     fi
     if [ ${RADAR_ONLY} -eq 1 ]; then
       ANAVINFO=${FIX_ROOT}/anavinfo_fv3_notlog_dbz_state_w_qc_exist_model_dbz
     fi
     SATANGL=${FIX_ROOT}/global_satangbias.txt
     SATINFO=${FIX_ROOT}/nam_regional_satinfo.txt
     OZINFO=${FIX_ROOT}/global_ozinfo.txt
     PCPINFO=${FIX_ROOT}/global_pcpinfo.txt
     SCANINFO=${FIX_ROOT}/global_scaninfo.txt
     ln -sf $ANAVINFO anavinfo
     ln -sf $BERROR   berror_stats
     ln -sf $SATANGL  satbias_angle
     ln -sf $SATINFO  satinfo
     ln -sf $CONVINFO convinfo
     ln -sf $OZINFO   ozinfo
     ln -sf $PCPINFO  pcpinfo
     ln -sf $SCANINFO scaninfo
     ln -sf $OBERROR  errtable

     # Only need this file for single obs test
     bufrtable=${FIX_ROOT}/prepobs_prep.bufrtable
     ln -sf $bufrtable ./prepobs_prep.bufrtable

     # for satellite bias correction
     ln -sf ${FIX_ROOT}/sample.satbias ./satbias_in

     echo "Build the namelist"
     vs_op='1.0,'
     hzscl_op='0.373,0.746,1.50,'
     bk_core_arw='.false.'
     bk_core_nmm='.false.'
     bk_core_nmmb='.false.'
     bk_core_fv3='.true.'
     bk_if_netcdf='.true.'
     if [ ${if_observer} = Yes ] ; then
       nummiter=0
       if_read_obs_save='.true.'
       if_read_obs_skip='.false.'
     else
       nummiter=2
       if_read_obs_save='.false.'
       if_read_obs_skip='.false.'
     fi

     # Build the GSI namelist on-the-fly
     . $GSI_NAMELIST

     if [ ${CONV_ONLY} -eq 1 ]; then
        comgsi_namelist1=$comgsi_namelist
     fi
     if [ ${RADAR_ONLY} -eq 1 ]; then
        comgsi_namelist1=$comgsi_namelist_radar
     fi

cat << EOF > gsiparm.anl

 $comgsi_namelist1

EOF

     ###################################################
     #  run  GSI
     ###################################################
     echo " Run GSI in $(pwd) ..."
     itry=1
     while [ ${itry} -le 1 ]; do
       #${MPIRUN} -n ${PROC} -o ${BEGPROC} ./gsi.exe > stdout 2>&1
       ${MPIRUN} -n ${PROC} ./gsi.exe > stdout 2>&1

       error=$?
       if [ ${error} -eq 0 ]; then
         break
       fi
      (( itry = itry + 1  ))
     done

     if [ ${error} -ne 0 ]; then
       echo "ERROR: ${GSI} crashed  Exit status=${error}"
       exit ${error}
     fi

     # Copy the output to more understandable names
#     ln -s stdout      stdout.anl.${ANALYSIS_TIME}
     mv stdout stdout_ensmean
     ln -s fort.201    fit_p1.${ANALYSIS_TIME}
     ln -s fort.202    fit_w1.${ANALYSIS_TIME}
     ln -s fort.203    fit_t1.${ANALYSIS_TIME}
     ln -s fort.204    fit_q1.${ANALYSIS_TIME}
     ln -s fort.207    fit_rad1.${ANALYSIS_TIME}

     # Loop over first and last outer loops to generate innovation
     # diagnostic files for indicated observation types (groups)
     #
     # NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
     #        loop 03 will contain innovations with respect to
     #        the analysis.  Creation of o-a innovation files
     #        is triggered by write_diag(3)=.true.  The setting
     #        write_diag(1)=.true. turns on creation of o-g
     #        innovation files.
     loops="01 03"
     for loop in $loops; do

       case $loop in
         01) string=ges;;
         03) string=anl;;
          *) string=$loop;;
       esac

       listall=`ls pe* | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-3)}' | sort | uniq `

       for type in $listall; do
         count=`ls pe*${type}_${loop}* | wc -l`
         if [[ $count -gt 0 ]]; then
           cat pe*${type}_${loop}* > diag_${type}_${string}.${ANALYSIS_TIME}
         fi
       done

     done

     ls -l * > list_run_directory

     # Prepare the GSI namelist for other ensemble members
     nummiter=0
     if_read_obs_save='.false.'
     if_read_obs_skip='.true.'
     . $GSI_NAMELIST

     if [ ${CONV_ONLY} -eq 1 ]; then
        comgsi_namelist1=$comgsi_namelist
     fi
     if [ ${RADAR_ONLY} -eq 1 ]; then
        comgsi_namelist1=$comgsi_namelist_radar
     fi

     cat << EOF > gsiparm.anl

 $comgsi_namelist1

EOF

     # Rename diag files
     string=ges
     for type in $listall; do
       count=0
       if [[ -f diag_${type}_${string}.${ANALYSIS_TIME} ]]; then
          mv diag_${type}_${string}.${ANALYSIS_TIME} diag_${type}_${string}.ensmean
       fi
     done

     if test -e ${WORK_ROOT}/shdir/FG_mean_ready ; then
        rm -f ${WORK_ROOT}/shdir/FG_mean_ready
     fi

   (( DOMAIN += 1 ))
 done

exit 0
