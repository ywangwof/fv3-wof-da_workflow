#!/bin/ksh --login
##########################################################################
#
#Script Name: post.ksh
# 
#     Author: Christopher Harrop
#             Forecast Systems Laboratory
#             325 Broadway R/FST
#             Boulder, CO. 80305
#
#   Released: 10/30/2003
#    Version: 1.0
#    Changes: None
#
# Purpose: This script post processes wrf output.  It is based on scripts
#          whose authors are unknown.
#
#               EXE_ROOT = The full path of the post executables
#          DATAHOME = Top level directory of wrf output and
#                          configuration data.
#             START_TIME = The cycle time to use for the initial time. 
#                          If not set, the system clock is used.
#              FCST_TIME = The two-digit forecast that is to be posted
# 
# A short and simple "control" script could be written to call this script
# or to submit this  script to a batch queueing  system.  Such a "control" 
# script  could  also  be  used to  set the above environment variables as 
# appropriate  for  a  particular experiment.  Batch  queueing options can
# be  specified on the command  line or  as directives at  the top of this
# script.  A set of default batch queueing directives is provided.
#
##########################################################################

# Set the queueing options 
#PBS -l procs=36
#PBS -l walltime=0:25:00
#PBS -A nrtrr
#PBS -q debug
#PBS -N HRRR_post
#PBS -l partition=tjet
#PBS -j oe

np=`cat $PBS_NODEFILE | wc -l`

# Load modules
module load newdefaults
module load intel
module load impi
module load netcdf
module load cnvgrib
module load ncep

# Make sure we are using GMT time zone for time computations
export TZ="GMT"

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
CUT=/bin/cut
AWK="/bin/gawk --posix"
SED=/bin/sed
DATE=/bin/date
BC=/usr/bin/bc
MPIRUN=mpirun
CNVGRIB=${EXE_ROOT}/cnvgrib.exe
CNVOPTS='-g12 -p32'

export CRTM="/pan2/projects/nrtrr/alexander/code/contrib/nceplibs/nwprod/lib/sorc/crtm_v2.0.7/fix"

export START_TIME=2011042715
#export START_TIME=2016020417
export FCST_TIME=01
export STATICWRF_DIR=/home/rtrr/HRRR/static/WRF
export WRF_ROOT=/home/rtrr/HRRR/exec/WRF
export EXE_ROOT=/home/rtrr/HRRR/exec/UPP
export DATAROOT=/mnt/lfs3/projects/rtwbl/terra/WoF_grb_test
export DATAHOME=/mnt/lfs3/projects/rtwbl/terra/WoF_grb_test/postprd
export DATAWRFHOME=/mnt/lfs3/projects/rtwbl/terra/WoF_grb_test
export MODEL="RAP"
export STATIC_DIR=/home/rtrr/HRRR/static/UPP


# Print run parameters
${ECHO}
${ECHO} "unipost.ksh started at `${DATE}`"
${ECHO}
${ECHO} "DATAHOME = ${DATAHOME}"
${ECHO} "     EXE_ROOT = ${EXE_ROOT}"

# Set up some constants
if [ "${MODEL}" == "RAP" ]; then
  export POST=${EXE_ROOT}/ncep_post.exe
  export CORE=RAPR
elif [ "${MODEL}" == "WRF-RR NMM" ]; then
  export POST=${EXE_ROOT}/ncep_post.exe
  export CORE=NMM
fi

# Check to make sure the EXE_ROOT var was specified
if [ ! -d ${EXE_ROOT} ]; then
  ${ECHO} "ERROR: EXE_ROOT, '${EXE_ROOT}', does not exist"
  exit 1
fi

# Check to make sure the post executable exists
if [ ! -x ${POST} ]; then
  ${ECHO} "ERROR: ${POST} does not exist, or is not executable"
  exit 1
fi

# Check to make sure that the DATAHOME exists
if [ ! ${DATAHOME} ]; then
  ${ECHO} "ERROR: DATAHOME, \$DATAHOME, is not defined"
  exit 1
fi

# If START_TIME is not defined, use the current time
if [ ! "${START_TIME}" ]; then
  START_TIME=`${DATE} +"%Y%m%d %H"`
else
  if [ `${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{10}$/'` ]; then
    START_TIME=`${ECHO} "${START_TIME}" | ${SED} 's/\([[:digit:]]\{2\}\)$/ \1/'`
  elif [ ! "`${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{8}[[:blank:]]{1}[[:digit:]]{2}$/'`" ]; then
    ${ECHO} "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
    exit 1
  fi
  START_TIME=`${DATE} -d "${START_TIME}"`
fi

# Print out times
${ECHO} "   START TIME = "`${DATE} +%Y%m%d%H -d "${START_TIME}"`
${ECHO} "    FCST_TIME = ${FCST_TIME}"

# Set up the work directory and cd into it
workdir=${DATAHOME}/${FCST_TIME}
${RM} -rf ${workdir}
${MKDIR} -p ${workdir}
cd ${workdir}

# Set up some constants
export XLFRTEOPTS="unit_vars=yes"
export MP_SHARED_MEMORY=yes
export SPLNUM=47
export SPL=2.,5.,7.,10.,20.,30.\
,50.,70.,75.,100.,125.,150.,175.,200.,225.\
,250.,275.,300.,325.,350.,375.,400.,425.,450.\
,475.,500.,525.,550.,575.,600.,625.,650.\
,675.,700.,725.,750.,775.,800.,825.,850.\
,875.,900.,925.,950.,975.,1000.,1013.2


timestr=`${DATE} +%Y-%m-%d_%H_%M_%S -d "${START_TIME}  ${FCST_TIME} hours"`
timestr2=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${START_TIME}  ${FCST_TIME} hours"`

# Save files for land surface cycling  and after long outages in full cycle
#if [[ ${FCST_TIME} -lt '18' ]]; then
#  timeHH=`${DATE} +%H -d "${START_TIME} ${FCST_TIME} hours"`
#  cp ${DATAWRFHOME}/wrfout_d01_${timestr} ${DATAROOT}/surface/wrfout_sfc_${timeHH}
#fi
#
#SAVE_BKGD=/mnt/pan2/projects/nrtrr/hrrr_bkgd
#SAVE_BDY=/mnt/pan2/projects/nrtrr/hrrr_bdy
#if [[ ${FCST_TIME} -eq '00' ]]; then
#  echo 'Save for background' ${DATAWRFHOME}/wrfinput_d01
#  if [ -r ${DATAWRFHOME}/wrfinput_d01 ]; then
#    cp ${DATAWRFHOME}/wrfinput_d01 ${SAVE_BKGD}/wrfinput_d01_${timestr}
#  fi
#fi
#if [[ ${FCST_TIME} -eq '01' ]]; then
#  echo 'Save boundary conditions' ${DATAWRFHOME}/wrfbdy_d01
#  if [ -r ${DATAWRFHOME}/wrfbdy_d01 ]; then
#    cp ${DATAWRFHOME}/wrfbdy_d01 ${SAVE_BDY}/wrfbdy_d01_${timestr}
#  fi
#fi

${CAT} > itag <<EOF
${DATAWRFHOME}/wrfout_d01_${timestr}
netcdf
grib2
${timestr2}
${CORE}
${SPLNUM}
${SPL}
${VALIDTIMEUNITS}
EOF

${RM} -f fort.*
ln -s ${STATIC_DIR}/hrrr_post_avblflds.xml post_avblflds.xml
ln -s ${STATIC_DIR}/hrrr_params_grib2_tbl_new params_grib2_tbl_new
ln -s ${STATIC_DIR}/hrrr_postcntrl.xml postcntrl.xml
ln -s ${STATIC_DIR}/hrrr_postxconfig-NT.txt postxconfig-NT.txt
if [ "${MODEL}" == "RAP" ]; then
  ln -s ${STATICWRF_DIR}/run/ETAMPNEW_DATA eta_micro_lookup.dat
elif [ "${MODEL}" == "WRF-RR NMM" ]; then
  ln -s ${STATICWRF_DIR}/run/ETAMPNEW_DATA eta_micro_lookup.dat
fi

# ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_g15.SpcCoeff.bin imgr_g11.SpcCoeff.bin
# ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_g13.SpcCoeff.bin imgr_g12.SpcCoeff.bin
# ln -s ${CRTM}/SpcCoeff/Big_Endian/amsre_aqua.SpcCoeff.bin amsre_aqua.SpcCoeff.bin
# ln -s ${CRTM}/SpcCoeff/Big_Endian/tmi_trmm.SpcCoeff.bin tmi_trmm.SpcCoeff.bin
# ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmi_f15.SpcCoeff.bin ssmi_f15.SpcCoeff.bin
# ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmis_f20.SpcCoeff.bin ssmis_f20.SpcCoeff.bin
# ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmis_f17.SpcCoeff.bin ssmis_f17.SpcCoeff.bin
# ln -s ${CRTM}/TauCoeff/ODPS/Big_Endian/imgr_g15.TauCoeff.bin imgr_g11.TauCoeff.bin
# ln -s ${CRTM}/TauCoeff/ODPS/Big_Endian/imgr_g13.TauCoeff.bin imgr_g12.TauCoeff.bin
# ln -s ${CRTM}/TauCoeff/ODPS/Big_Endian/amsre_aqua.TauCoeff.bin amsre_aqua.TauCoeff.bin
# ln -s ${CRTM}/TauCoeff/ODPS/Big_Endian/tmi_trmm.TauCoeff.bin tmi_trmm.TauCoeff.bin
# ln -s ${CRTM}/TauCoeff/ODPS/Big_Endian/ssmi_f15.TauCoeff.bin ssmi_f15.TauCoeff.bin
# ln -s ${CRTM}/TauCoeff/ODPS/Big_Endian/ssmis_f20.TauCoeff.bin ssmis_f20.TauCoeff.bin
# ln -s ${CRTM}/TauCoeff/ODPS/Big_Endian/ssmis_f17.TauCoeff.bin ssmis_f17.TauCoeff.bin
# ln -s ${CRTM}/CloudCoeff/Big_Endian/CloudCoeff.bin CloudCoeff.bin
# ln -s ${CRTM}/AerosolCoeff/Big_Endian/AerosolCoeff.bin AerosolCoeff.bin
# ln -s ${CRTM}/EmisCoeff/Big_Endian/Nalli.EK-PDF.W_W-RefInd.EmisCoeff.bin EmisCoeff.bin

ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_g11.SpcCoeff.bin imgr_g11.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_g12.SpcCoeff.bin imgr_g12.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_g13.SpcCoeff.bin imgr_g13.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_g15.SpcCoeff.bin imgr_g15.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_mt1r.SpcCoeff.bin imgr_mt1r.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_mt2.SpcCoeff.bin imgr_mt2.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/amsre_aqua.SpcCoeff.bin amsre_aqua.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/tmi_trmm.SpcCoeff.bin tmi_trmm.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmi_f13.SpcCoeff.bin ssmi_f13.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmi_f14.SpcCoeff.bin ssmi_f14.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmi_f15.SpcCoeff.bin ssmi_f15.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmis_f16.SpcCoeff.bin ssmis_f16.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmis_f17.SpcCoeff.bin ssmis_f17.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmis_f18.SpcCoeff.bin ssmis_f18.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmis_f19.SpcCoeff.bin ssmis_f19.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/ssmis_f20.SpcCoeff.bin ssmis_f20.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/seviri_m10.SpcCoeff.bin seviri_m10.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/v.seviri_m10.SpcCoeff.bin v.seviri_m10.SpcCoeff.bin
ln -s ${CRTM}/SpcCoeff/Big_Endian/imgr_insat3d.SpcCoeff.bin imgr_insat3d.SpcCoeff.bin

ln -s ${CRTM}/TauCoeff/Big_Endian/imgr_g11.TauCoeff.bin imgr_g11.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/imgr_g12.TauCoeff.bin imgr_g12.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/imgr_g13.TauCoeff.bin imgr_g13.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/imgr_g15.TauCoeff.bin imgr_g15.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/imgr_mt1r.TauCoeff.bin imgr_mt1r.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/imgr_mt2.TauCoeff.bin imgr_mt2.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/amsre_aqua.TauCoeff.bin amsre_aqua.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/tmi_trmm.TauCoeff.bin tmi_trmm.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmi_f13.TauCoeff.bin ssmi_f13.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmi_f14.TauCoeff.bin ssmi_f14.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmi_f15.TauCoeff.bin ssmi_f15.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmis_f16.TauCoeff.bin ssmis_f16.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmis_f17.TauCoeff.bin ssmis_f17.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmis_f18.TauCoeff.bin ssmis_f18.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmis_f19.TauCoeff.bin ssmis_f19.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/ssmis_f20.TauCoeff.bin ssmis_f20.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/seviri_m10.TauCoeff.bin seviri_m10.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/ODAS/Big_Endian/v.seviri_m10.TauCoeff.bin v.seviri_m10.TauCoeff.bin
ln -s ${CRTM}/TauCoeff/Big_Endian/imgr_insat3d.TauCoeff.bin imgr_insat3d.TauCoeff.bin

ln -s ${CRTM}/CloudCoeff/Big_Endian/CloudCoeff.bin CloudCoeff.bin
ln -s ${CRTM}/AerosolCoeff/Big_Endian/AerosolCoeff.bin AerosolCoeff.bin
ln -s ${CRTM}/EmisCoeff/Big_Endian/EmisCoeff.bin EmisCoeff.bin

# Run unipost
${MPIRUN} -np $np ${POST}< itag
error=$?
if [ ${error} -ne 0 ]; then
  ${ECHO} "${POST} crashed!  Exit status=${error}"
  exit ${error}
fi

# Append entire wrftwo to wrfprs
${CAT} ${workdir}/WRFPRS.GrbF${FCST_TIME} ${workdir}/WRFTWO.GrbF${FCST_TIME} > ${workdir}/WRFPRS.GrbF${FCST_TIME}.new
${MV} ${workdir}/WRFPRS.GrbF${FCST_TIME}.new ${workdir}/wrfprs_hrconus_${FCST_TIME}.grib2

# Append entire wrftwo to wrfnat
${CAT} WRFNAT.GrbF${FCST_TIME} WRFTWO.GrbF${FCST_TIME} > ${workdir}/WRFNAT.GrbF${FCST_TIME}.new
${MV} WRFNAT.GrbF${FCST_TIME}.new ${workdir}/wrfnat_hrconus_${FCST_TIME}.grib2

${MV} ${workdir}/WRFTWO.GrbF${FCST_TIME} ${workdir}/wrftwo_hrconus_${FCST_TIME}.grib2

# Check to make sure all Post  output files were produced
if [ ! -s "${workdir}/wrfprs_hrconus_${FCST_TIME}.grib2" ]; then
  ${ECHO} "unipost crashed! wrfprs_hrconus_${FCST_TIME}.grib2 is missing"
  exit 1
fi
if [ ! -s "${workdir}/wrftwo_hrconus_${FCST_TIME}.grib2" ]; then
  ${ECHO} "unipost crashed! wrftwo_hrconus_${FCST_TIME}.grib2 is missing"
  exit 1
fi
if [ ! -s "${workdir}/wrfnat_hrconus_${FCST_TIME}.grib2" ]; then
  ${ECHO} "unipost crashed! wrfnat_hrconus_${FCST_TIME}.grib2 is missing"
  exit 1
fi

# Move the output files to postprd
${MV} ${workdir}/wrfprs_hrconus_${FCST_TIME}.grib2 ${DATAHOME}
${MV} ${workdir}/wrftwo_hrconus_${FCST_TIME}.grib2 ${DATAHOME}
${MV} ${workdir}/wrfnat_hrconus_${FCST_TIME}.grib2 ${DATAHOME}
${RM} -rf ${workdir}

${ECHO} "unipost.ksh completed at `${DATE}`"

exit 0
