#!/bin/bash
##########################################################################
#
#Script Name: wrf_arw_cycle.ksh
#
##########################################################################

source /lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap/ufs-srweather-app/env/build_jet_intel.env
module use -a /lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap/ufs-srweather-app/env
module load build_jet.env
module load pnetcdf/1.11.2

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

if [ ! "${GSI_ROOT}" ]; then
  echo "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi
echo "GSI_ROOT = ${GSI_ROOT}"

gdate=$ANALYSIS_TIME
YYYYMMDD=`echo $gdate | cut -c1-8`
HH=`echo $gdate | cut -c9-10`

# Set up some constants
ENSMEANOTH_EXE=${GSI_ROOT}/gen_be_ensmean.x
ENSMEANREF_EXE=${GSI_ROOT}/gen_be_ensmean_ref.x
ensnum=${ENSEMBLE_SIZE}

##############################################################
# calculate ensemble mean
##############################################################

echo "calculate ensemble mean using gen_be_ensmean.exe"

DOMAIN=1

if [ ${IF_CONV} -eq 0 ] ; then
  ENKF_ROOT=${WORK_ROOT}/enkfprd_radar_d0${DOMAIN}
else
  ENKF_ROOT=${WORK_ROOT}/enkfprd_d0${DOMAIN}
fi
${MKDIR} -p ${ENKF_ROOT}
cd ${ENKF_ROOT}

rm -f ${ENKF_ROOT}/ensmean_finished

if [ ! -e ${WORK_ROOT}/fv3prd_mem0001/ANA/fv_core.res.tile1_new.nc ]; then
   FGdir=GUESS
else
   FGdir=ANA
fi

imem=1
while [ ${imem} -le ${ensnum} ]; do
  memstr4=`printf %04i ${imem}`
  memstr3=`printf %03i ${imem}`
  FG_MEM=${WORK_ROOT}/fv3prd_mem${memstr4}/${FGdir}/fv_core.res.tile1_new.nc
  ${LN} -sf ${FG_MEM} fv3sar_tile1_mem${memstr3}_dynvar
  FG_MEM=${WORK_ROOT}/fv3prd_mem${memstr4}/${FGdir}/fv_tracer.res.tile1_new.nc
  ${LN} -sf ${FG_MEM} fv3sar_tile1_mem${memstr3}_tracer
  FG_MEM=${WORK_ROOT}/fv3prd_mem${memstr4}/${FGdir}/phy_data.nc
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
pwd
for varname in `echo u v T delp sphum`
do
  if [ ${varname} == 'sphum' ]; then
    ftail='tracer'
    ENSMEAN_EXE=${ENSMEANOTH_EXE}
  else
    ftail='dynvar'
    ENSMEAN_EXE=${ENSMEANOTH_EXE}
  fi
  echo "Running ${ENSMEAN_EXE} for ${varname} ..."
  ${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}
  error=$?
  if [ ${error} -ne 0 ]; then
   sleep 5
   itry=1
   while [ ${itry} -le 1 ]; do
     sleep 5
     echo "Running ${ENSMEAN_EXE} for ${varname}, itry = $itry ..."
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

tracers_HRRR=(W liq_wat rainwat ice_wat snowwat graupel ref_f3d)
tracers_NSSL=(W liq_wat rainwat ice_wat snowwat graupel hailwat ref_f3d)
eval tracers=\( \${tracers_${CCPP_SUITE}[@]} \)

if [ ${NVAR} -gt 7 ]; then
for varname in ${tracers[@]}
do
  if [ ${varname} == 'W' ]; then
    ftail='dynvar'
    ENSMEAN_EXE=${ENSMEANOTH_EXE}
  elif [ ${varname} == 'ref_f3d' ]; then
    ftail='phyvar'
    ENSMEAN_EXE=${ENSMEANREF_EXE}
  else
    ftail='tracer'
    ENSMEAN_EXE=${ENSMEANOTH_EXE}
  fi
  echo "Running ${ENSMEAN_EXE} for ${varname} ..."

  ${MPIRUN} -n ${PROC} ${ENSMEAN_EXE} ./ fv3sar_tile1 ${ensnum} ${varname} ${ftail} > ./ensmean.output_${varname}
  error=$?
  if [ ${error} -ne 0 ]; then
   sleep 5
   itry=1
   while [ ${itry} -le 1 ]; do
     sleep 5
     echo "Running ${ENSMEAN_EXE} for ${varname}, itry = $itry ..."
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
echo "Checking ${varnum} within firstguess_ensmean.ksh, get ${ensmeandone_num} ..."
while [ ${ensmeandone_num} -lt ${varnum} ]; do
  sleep 3
  ensmeandone_num=`grep ensmean_done ./ensmean.output_* 2>/dev/null | wc -l`
done

mv fv3sar_tile1_dynvar fv3sar_tile1_ensmean_dynvar
mv fv3sar_tile1_tracer fv3sar_tile1_ensmean_tracer
mv fv3sar_tile1_phyvar fv3sar_tile1_ensmean_phyvar

echo "ENKF DONE" > ${ENKF_ROOT}/ensmean_finished

exit 0
