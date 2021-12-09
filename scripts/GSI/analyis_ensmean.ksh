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
PDSH=/usr/local/bin/pdsh
MPIRUN=srun

#set -x

# Check to make sure the required environmental variables for GSI were specified
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

NUM_DOMAINS=1

if [ ! "${GSI_ROOT}" ]; then
  echo "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi
echo "GSI_ROOT = ${GSI_ROOT}"

gdate=$ANALYSIS_TIME
YYYYMMDD=`echo $gdate | cut -c1-8`
HH=`echo $gdate | cut -c9-10`

# Set up some constants
ENSMEAN_EXE=${GSI_ROOT}/gen_be_ensmean.x
RECENTER_EXE=${GSI_ROOT}/gen_be_ensmeanrecenter.x
ENSMEANREF_EXE=${GSI_ROOT}/gen_be_ensmean_ref.x
RECENTERREF_EXE=${GSI_ROOT}/gen_be_ensmeanrecenter_ref.x
ensnum=${ENSEMBLE_SIZE}

##############################################################
# calculate ensemble mean
##############################################################

echo "calculate ensemble mean using gen_be_ensmean.exe"

DOMAIN=1
while [[ $DOMAIN -le $NUM_DOMAINS ]];do

   if [ ${NVAR} -gt 7 ] ; then
     ENKF_ROOT=${WORK_ROOT}/enkfprd_radar_d0${DOMAIN}
   else
     ENKF_ROOT=${WORK_ROOT}/enkfprd_d0${DOMAIN}
   fi
   cd ${ENKF_ROOT}

  imem=1
  while [ ${imem} -le ${ensnum} ]; do
    memstr4=`printf %04i ${imem}`
    memstr3=`printf %03i ${imem}`
    FG_MEM=${WORK_ROOT}/fv3prd_mem${memstr4}/ANA/fv_core.res.tile1_new.nc
    ${LN} -sf ${FG_MEM} fv3sar_tile1_mem${memstr3}_dynvar
    FG_MEM=${WORK_ROOT}/fv3prd_mem${memstr4}/ANA/fv_tracer.res.tile1_new.nc
    ${LN} -sf ${FG_MEM} fv3sar_tile1_mem${memstr3}_tracer
    FG_MEM=${WORK_ROOT}/fv3prd_mem${memstr4}/ANA/phy_data.nc
    ${LN} -sf ${FG_MEM} fv3sar_tile1_mem${memstr3}_phyvar

    (( imem = imem + 1 ))
  done

  if test -e ./fv3sar_tile1_dynvar ; then
    rm -f ./fv3sar_tile1_dynvar
  fi
  if test -e ./fv3sar_tile1_tracer ; then
    rm -f ./fv3sar_tile1_tracer
  fi
  if test -e ./fv3sar_tile1_phyvar ; then
    rm -f ./fv3sar_tile1_phyvar
  fi
  cp -f ./fv3sar_tile1_mem001_dynvar fv3sar_tile1_dynvar
  cp -f ./fv3sar_tile1_mem001_tracer fv3sar_tile1_tracer
  cp -f ./fv3sar_tile1_mem001_phyvar fv3sar_tile1_phyvar
  rm -f ./.hostfile_ensmean_*
  rm -f ./ensmean.output_*

  varnum=0
  for varname in `echo u v T delp sphum`
  do
    if [ ${varname} == 'sphum' ]; then
      ftail='tracer'
    else
      ftail='dynvar'
    fi
    echo "Running ${ENSMEAN_EXE} for $varname ...."
    #${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}
    ${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}
    error=$?
    if [ ${error} -ne 0 ]; then
     sleep 5
     itry=1
     while [ ${itry} -le 3 ]; do
       echo "Running ${ENSMEAN_EXE} for $varname at itry=$itry ...."
       #${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}
       ${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}

       error=$?
       if [ ${error} -eq 0 ]; then
         break
       fi
      (( itry = itry + 1  ))
     done
    fi

    (( varnum = varnum + 1 ))
  done

  if [ ${NVAR} -gt 7 ]; then
  for varname in `echo W liq_wat rainwat ice_wat snowwat graupel ref_f3d`
  do
    if [ ${varname} == 'W' ]; then
      ftail='dynvar'
    elif [ ${varname} == 'ref_f3d' ]; then
      ftail='phyvar'
      ENSMEAN_EXE=${ENSMEANREF_EXE}
    else
      ftail='tracer'
    fi
    echo "Running ${ENSMEAN_EXE} for $varname ...."
    ${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}
    error=$?
    if [ ${error} -ne 0 ]; then
     sleep 5
     itry=1
     while [ ${itry} -le 3 ]; do
       echo "Running ${ENSMEAN_EXE} for $varname at itry=$itry ...."
       ${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}

       error=$?
       if [ ${error} -eq 0 ]; then
         break
       fi
      (( itry = itry + 1  ))
     done
    fi

    (( varnum = varnum + 1 ))
  done
  fi

  ensmeandone_num=`grep ensmean_done ./ensmean.output_* 2>/dev/null | wc -l`
  while [ ${ensmeandone_num} -lt ${varnum} ]; do
    sleep 3
    ensmeandone_num=`grep ensmean_done ./ensmean.output_* 2>/dev/null | wc -l`
  done

   (( DOMAIN += 1 ))
done

 echo "" > ${ENKF_ROOT}/recenter_finished

exit 0
