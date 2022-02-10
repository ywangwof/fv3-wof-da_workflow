#!/bin/bash

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
module load nco/4.9.3
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/szip/2.1/lib
# End of Jet environment

export OMP_STACKSIZE=256M

RM=/bin/rm
CP=/bin/cp
MV=/bin/mv
LN=/bin/ln
MKDIR=/bin/mkdir
CAT=/bin/cat
ECHO=/bin/echo
LS=/bin/ls
CUT=/bin/cut
WC=/usr/bin/wc
DATE=/bin/date
AWK="/bin/awk --posix"
SED=/bin/sed
TAIL=/usr/bin/tail
MPIRUN=srun

# set -x

#########################################################################################
# expected parameters passed as environment variables:
#   GSI_ROOT = directory containing GSI executable
#   ANALYSIS_TIME = analysis time (YYYYMMDDHH)
#   WORK_ROOT = working directory, containing wrfprd*, gsiprd, and enkfprd subdirectories
#   DOMAIN = WRF domain index
#   ENSEMBLE_SIZE = number of ensemble members
#   NLONS, NLATS, NLEVS = ensemble grid dimensions
#########################################################################################

# Check to make sure the required environmental variables were specified
if [ ! "${GSI_ROOT}" ]; then
  echo "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi
echo "GSI_ROOT = ${GSI_ROOT}"

#GSIPROC=`cat $PBS_NODEFILE | wc -l`
#if [ ! "${GSIPROC}" ]; then
#  echo "ERROR: The variable $GSIPROC must be set to contain the number of processors to run GSI"
#  exit 1
#fi
#echo "GSIPROC = ${GSIPROC}"

if [ ! "${ANALYSIS_TIME}" ]; then
  echo "ERROR: The variable $ANALYSIS_TIME must be set to the analysis time (YYYYMMDDHH)"
  exit 1
fi
echo "ANALYSIS_TIME = ${ANALYSIS_TIME}"

if [ ! "${WORK_ROOT}" ]; then
  echo "ERROR: \$WORK_ROOT is not defined!"
  exit 1
fi
echo "WORK_ROOT = ${WORK_ROOT}"

DOMAIN=1

if [ ! "${ENSEMBLE_SIZE}" ]; then
  echo "ERROR: \$ENSEMBLE_SIZE is not defined!"
  exit 1
fi
echo "ENSEMBLE_SIZE = ${ENSEMBLE_SIZE}"

if [ ! "${NLONS}" ]; then
  echo "ERROR: \$NLONS is not defined!"
  exit 1
fi
echo "NLONS = ${NLONS}"

if [ ! "${NLATS}" ]; then
  echo "ERROR: \$NLATS is not defined!"
  exit 1
fi
echo "NLATS = ${NLATS}"

if [ ! "${NLEVS}" ]; then
  echo "ERROR: \$NLEVS is not defined!"
  exit 1
fi
echo "NLEVS = ${NLEVS}"

#####################################################
# case set up (users should change this part)
#####################################################
#  ARCH='LINUX_PBS'   # IBM_LSF, LINUX, LINUX_LSF, LINUX_PBS, or DARWIN_PGI

# FIX_ROOT = path of fix files
# GSI_EXE  = path and name of the gsi executable

WOF_FIXROOT="${ENKF_STATIC}/WoFS/enkf"

ENKF_EXE=${GSI_ROOT}/enkf_fv3reg.x
CRTM_ROOT=CRTM_REL-2.1.3

# ensemble parameters
#
  NMEM_ENKF=${ENSEMBLE_SIZE}
  IF_ARW=.false.
  IF_NMM=.false.
  list="conv"
#

#####################################################
# Set up workdir
#####################################################
if [ ${CONV_ONLY} -eq 1  ]; then
    ENKF_ROOT=${WORK_ROOT}/enkfprd_d0${DOMAIN}
    diag_ROOT=${WORK_ROOT}/gsiprd_d0${DOMAIN}
    ENKF_NAMELIST=${GSI_ROOT}/enkf_wrf_namelist.sh
elif [ ${RADAR_ONLY} -eq 1 ]; then
    ENKF_ROOT=${WORK_ROOT}/enkfprd_radar_d0${DOMAIN}
    diag_ROOT=${WORK_ROOT}/gsiprd_radar_d0${DOMAIN}
    ENKF_NAMELIST=${GSI_ROOT}/enkf_fv3_namelist_wof.sh
fi

if [ ! -d ${ENKF_ROOT} ]; then
    #mkdir -p $ENKF_ROOT
    echo "EnKF dir: ${ENKF_ROOT} not exit"
    exit 1
fi
cd $ENKF_ROOT

cp -f ${WORK_ROOT}/fv3prd_mem0001/GUESS/fv_core.res.nc fv3sar_tile1_akbk.nc
cp -f ${WORK_ROOT}/fv3prd_mem0001/GUESS/grid_spec_new.nc fv3sar_tile1_grid_spec.nc

#####################################################
# Wait for WRF+GSI to finish for all members
#####################################################

echo "current time is `${DATE}`"
echo "waiting for WRF and GSI to finish for each ensemble member"
imem=1
while [[ $imem -le $NMEM_ENKF ]]; do
    ensmemid=`printf %4.4i $imem`
    member="mem"`printf %03i $imem`
    while [[ ! -s ${diag_ROOT}/stdout_mem${ensmemid} ]];do
        #sleep 0.1
        echo "File: ${diag_ROOT}/stdout_mem${ensmemid} not found."
        exit 2
    done
    echo "member ${imem} complete"

    echo "linking diag file"
    for type in $list; do
        ln -sf $diag_ROOT/diag_${type}_ges.mem${ensmemid} ./diag_${type}_ges.${member}
    done
    (( imem = $imem + 1 ))
done
echo "current time is `${DATE}`"

#####################################################
# Users should NOT change script after this point
#####################################################
#

#case $ARCH in
#   'IBM_LSF')
#      ###### IBM LSF (Load Sharing Facility)
#      RUN_COMMAND="mpirun.lsf " ;;
#
#   'LINUX')
#      if [ $GSIPROC = 1 ]; then
#         #### Linux workstation - single processor
#         RUN_COMMAND=""
#      else
#         ###### Linux workstation -  mpi run
#        RUN_COMMAND="mpirun -np ${GSIPROC} -machinefile ~/mach "
#      fi ;;
#
#   'LINUX_LSF')
#      ###### LINUX LSF (Load Sharing Facility)
#      RUN_COMMAND="mpirun.lsf " ;;
#
#   'LINUX_PBS')
#      #### Linux cluster PBS (Portable Batch System)
#      RUN_COMMAND="${MPIRUN} -np ${GSIPROC} " ;;
##      RUN_COMMAND="mpiexec_mpt -n ${GSIPROC} " ;;
#
#   'DARWIN_PGI')
#      ### Mac - mpi run
#      if [ $GSIPROC = 1 ]; then
#         #### Mac workstation - single processor
#         RUN_COMMAND=""
#      else
#         ###### Mac workstation -  mpi run
#         RUN_COMMAND="mpirun -np ${GSIPROC} -machinefile ~/mach "
#      fi ;;
#
#   * )
#     print "error: $ARCH is not a supported platform configuration."
#     exit 1 ;;
#esac
#
# Given the analysis date, compute the date from which the
# first guess comes.  Extract cycle and set prefix and suffix
# for guess and observation data files
# gdate=`$ndate -06 $adate`
gdate=$ANALYSIS_TIME
YYYYMMDD=`echo $gdate | cut -c1-8`
HH=`echo $gdate | cut -c9-10`

# Fixed files
CONVINFO=${diag_ROOT}/convinfo
SATINFO=${diag_ROOT}/satinfo
SCANINFO=${diag_ROOT}/scaninfo
OZINFO=${diag_ROOT}/ozinfo


ln -sf $ENKF_EXE        ./enkf.x

cp $CONVINFO        ./convinfo
cp $SATINFO         ./satinfo
cp $SCANINFO        ./scaninfo
cp $OZINFO          ./ozinfo
# cp $LOCINFO         ./hybens_locinfo

cp $diag_ROOT/satbias_in ./satbias_in
cp $diag_ROOT/satbias_angle ./satbias_angle

#cp ${WOF_FIXROOT}/prior_inf_d01.1 ./
#cp ${WOF_FIXROOT}/prior_inf_sd_d01.1 ./
cp ${WOF_FIXROOT}/obs_locinfo ./

for type in $list; do
    ln -sf $diag_ROOT/diag_${type}_ges.ensmean .
done

#
###################################################
#  Merge dynvar and tracer to dynvartracer
###################################################
rm -f *_dynvartracer

imem=1
while [[ $imem -le $NMEM_ENKF ]]; do
    member=$(printf "%03d" $imem)
    echo "Merging fv3sar_tile1_mem${member}_dynvar and fv3sar_tile1_mem${member}_tracer to fv3sar_tile1_mem${member}_dynvartracer"
    ${CP} fv3sar_tile1_mem${member}_dynvar fv3sar_tile1_mem${member}_dynvartracer
    srun -n 1 -N 1 -c 1 ncks -A fv3sar_tile1_mem${member}_tracer fv3sar_tile1_mem${member}_dynvartracer &
    (( imem = $imem + 1 ))
done
echo "Merge fv3sar_tile1_ensmean_dynvar and fv3sar_tile1_ensmean_tracer to fv3sar_tile1_ensmean_dynvartracer"
${CP} fv3sar_tile1_ensmean_dynvar fv3sar_tile1_ensmean_dynvartracer
ncks -A fv3sar_tile1_ensmean_tracer fv3sar_tile1_ensmean_dynvartracer

for ((imem=1;imem<=$NMEM_ENKF;imem++)); do
    member=$(printf "%03d" $imem)
    filename="fv3sar_tile1_mem${member}_dynvartracer"
    filesize=$(stat -c %s $filename)
#    while [[ $filesize -lt 727000000 ]];do
    while [[ $filesize -lt  500000000 ]];do
        echo "waiting for $filename to be ready ...."
        sleep 10
        filesize=$(stat -c %s $filename)
    done
done

#filename="fv3sar_tile1_ensmean_dynvartracer"
#fizesize=$(stat -c%s "$filename")
#while [[ $filesize -lt 7270000000 ]];do
#    echo "waiting for $filename to be ready ...."
#    sleep 10
#    fizesize=$(stat -c%s "$filename")
#done

sleep 10

# Build the GSI namelist on-the-fly
if [ ${CONV_ONLY} -eq 1  ]; then
    COVINFLATENH=0.0
    COVINFLATESH=0.0
    COVINFLATETR=0.0
    CORRLENGTHNH=300
    CORRLENGTHSH=300
    CORRLENGTHTR=300
    CORRLENGTHV=0.55
    cp -f ${ENKF_STATIC}/anavinfo_fv3_enkf_con ./anavinfo
fi

if [ ${RADAR_ONLY} -eq 1 ]; then
    COVINFLATENH=0.0
    COVINFLATESH=0.0
    COVINFLATETR=0.0
    CORRLENGTHNH=460
    CORRLENGTHSH=460
    CORRLENGTHTR=460
    CORRLENGTHV=0.45
    CORRLENGTHS=1.0
    #cp -f ${ENKF_STATIC}/anavinfo_fv3_enkf_radar.${CCPP_SUITE} ./anavinfo
    cp -f ${ENKF_STATIC}/anavinfo_fv3_enkf_radar_wof.${CCPP_SUITE} ./anavinfo
fi

IF_RH=0

if [ ${IF_RH} -eq 1 ]; then
  pseudo_rh='.true.'
else
  pseudo_rh='.false.'
fi

. $ENKF_NAMELIST
cat << EOF > enkf.nml

 $enkf_namelist

EOF


#
###################################################
#  run  EnKF
###################################################
echo ' Run EnKF'

itry=1
echo "Running enkf.x in $(pwd) at itry=$itry ...."
while [ ${itry} -le 3 ]; do
    #${MPIRUN} -n ${PROC} -o ${BEGPROC} ./enkf.x < enkf.nml > stdout 2>&1
    ${MPIRUN} -n ${PROC} ./enkf.x < enkf.nml > stdout 2>&1

    error=$?
    if [ ${error} -eq 0 ]; then
       break
    fi
    (( itry = itry + 1  ))
done


##################################################################
#  run time error check
##################################################################

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${ENKF_EXE} crashed  Exit status=${error}"
  exit ${error}
fi

################################################
# Copy analysis members to WRF run directories #
################################################
imem=1
while [[ $imem -le $NMEM_ENKF ]]; do
    ensmemid=`printf %4.4i $imem`
    member="mem"`printf %03i $imem`
    if [ -e ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/fv_core.res.tile1_new.nc ]; then
       mv ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV
       mkdir -p ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA
       mv -f ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV/fv_srf_wnd.res.tile1.nc ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/
       mv -f ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV/gfs_bndy.tile7.001.nc ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/
       mv -f ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV/sfc_data.nc ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/
    fi
    BK_FILE_DIR=${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA
    echo "Moving member ${ensmemid} with enkf member analysis"
    ${MV} fv3sar_tile1_${member}_dynvar ${BK_FILE_DIR}/fv_core.res.tile1_new.nc
    ${MV} fv3sar_tile1_${member}_tracer ${BK_FILE_DIR}/fv_tracer.res.tile1_new.nc
    ${MV} fv3sar_tile1_${member}_phyvar ${BK_FILE_DIR}/phy_data.nc
    (( imem = $imem + 1 ))
done

###################################################
# Provide signal to next process                  #
###################################################

if [ -e ${WORK_ROOT}/obsprd/${ANALYSIS_TIME} ]; then
   if [ ${CONV_ONLY} -eq 1 ]; then
     ${ECHO} "" > ${WORK_ROOT}/READY_RADAR_DA
     ${ECHO} "" > ${WORK_ROOT}/EnKF_DONE_CONV
   else
     ${ECHO} "" > enkf_finished
     ${ECHO} "" > ${WORK_ROOT}/EnKF_DONE_RADAR
   fi
else
   ${ECHO} "" > enkf_finished
   ${ECHO} "" > ${WORK_ROOT}/EnKF_DONE_CONV
fi

${ECHO} "run_enkf_wrf.ksh terminated at `${DATE}`"

exit