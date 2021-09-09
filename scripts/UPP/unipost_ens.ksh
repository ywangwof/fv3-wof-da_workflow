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

#export NETCDF=/opt/apps/intel19/netcdf/4.6.2/x86_64
#export LD_LIBRARY_PATH=${NETCDF}/lib:$LD_LIBRARY_PATH
# Set the queueing options 

np=`expr ${PROC} - 1`
echo ${np}

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
MPIRUN=/usr/local/bin/ibrun

# Print run parameters
${ECHO}
${ECHO} "unipost_ens.ksh started at `${DATE}`"
${ECHO}
${ECHO} "DATAHOME = ${DATAHOME}"
${ECHO} "     EXE_ROOT = ${EXE_ROOT}"

# Set up some constants
memberid=${MEMBER}
CORE='FV3R'
upp_static=${STATIC_DIR}
POST=${EXE_ROOT}/ncep_post
WGRIB=${EXE_ROOT}/wgrib2
source ${STATIC_DIR}/upp_env

  # Formatted fhr for filenames
  fhr=`printf "%02i" ${FCST_TIME}`
  fhr3=`printf "%03i" ${FCST_TIME}`
  

  outname=map2-hybrid`printf %02i $(( ${memberid} + 1 ))`
  outname1=map-hybrid`printf %02i $(( ${memberid} + 1 ))`

YMD=${START_TIME:0:8}
HH=${START_TIME:8:2}
namedate=${START_TIME:0:10}


# Print out times
${ECHO} "   START TIME = "`${DATE} +%Y%m%d%H -d "${YMD} ${HH}"`
${ECHO} "    FCST_TIME = ${FCST_TIME}"

${ECHO} "       DOMAIN = $DOMAIN"
${ECHO} "       MEMBER = $MEMBER"
ensmemid=`printf %4.4i $MEMBER`

# Set up the work directory and cd into it
workdir=${DATAHOME}/postprd_mem${ensmemid}/${FCST_TIME}
${RM} -rf ${workdir}
${MKDIR} -p ${workdir}
cd ${workdir}


timestr=`${DATE} +%Y-%m-%d_%H_%M_%S -d "${YMD} ${HH}  ${FCST_TIME} hours"`
timestr2=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${YMD} ${HH}  ${FCST_TIME} hours"`
start_hour=`${DATE} +%H -d "${YMD} ${HH}"`
START_YYYYMMDD=`${DATE} +"%Y%m%d" -d "${YMD} ${HH}"`

dyn_file="${DATAHOME}/fv3prd_mem${ensmemid}/dynf${fhr3}.nc"
phy_file="${DATAHOME}/fv3prd_mem${ensmemid}/phyf${fhr3}.nc"


${CAT} > itag <<EOF
${dyn_file}
netcdf
grib2
${timestr2}
${CORE}
${phy_file}
EOF

${RM} -f fort.*

  ln -sf ${upp_static}/parm/hrrr_budget_fields.txt .
  ln -sf ${upp_static}/parm/hrrr_neighbor_fields.txt .
  ln -sf ${upp_static}/parm/hrrr_vector_fields.txt .

ln -sf ${upp_static}/parm/nam_micro_lookup.dat ./eta_micro_lookup.dat
#ln -sf ${upp_static}/parm/postxconfig-NT-fv3lam.txt ./postxconfig-NT.txt
ln -sf ${upp_static}/parm/postxconfig-NT-fv3sar_onlyPRS.txt ./postxconfig-NT.txt
ln -sf ${upp_static}/parm/params_grib2_tbl_new ./params_grib2_tbl_new
ln -sf ${upp_static}/testbed.txt ./testbed.txt

  if [ ${MEMBER} -eq 0 ] ; then
    if [ ! -e ${NODEPATH}/nodefile_${START_TIME} ]; then
      inode=1
      for node_name in `scontrol show hostnames ${SLURM_JOB_NODELIST}`
      do
        icore=0
        while [ ${icore} -lt 56 ]
        do
          echo ${node_name} >> ${NODEPATH}/nodefile_${START_TIME}
          icore=`expr ${icore} + 1`
        done
        inode=`expr ${inode} + 1`
      done
    fi
  fi

   if [ ${BEGPROC} -le 10000 ]; then
     totalcorenum=6720
   else
     totalcorenum=10640
   fi

    while [ ! -e ${NODEPATH}/nodefile_${START_TIME} ]; do
      sleep 30
    done
    if [ -e ${NODEPATH}/nodefile_${START_TIME} ]; then
         corenum=`cat ${NODEPATH}/nodefile_${START_TIME} | wc -l`
         while [ ${corenum} -lt ${totalcorenum} ]; do
           sleep 30
           corenum=`cat ${NODEPATH}/nodefile_${START_TIME} | wc -l`
         done
    fi

  rm -f ./usenode
  inode=1
  while [ ${inode} -le 56 ]; do
    linenp=$(( ${BEGPROC} + ${inode} ))
    sed -n ${linenp}p ${NODEPATH}/nodefile_${START_TIME} >> ./usenode
    inode=`expr ${inode} + 4`
  done

# Run unipost
   np=`cat ./usenode | wc -l`
   itry=1
   while [ ${itry} -le 3 ]; do
       mpirun -np ${np} -machinefile ./usenode ${POST} < itag

     error=$?
     if [ ${error} -eq 0 ]; then
       break
     fi
     (( itry = itry + 1  ))
   done
   sleep 5

if [ ${error} -ne 0 ]; then
  ${ECHO} "${POST} crashed!  Exit status=${error}"
  exit ${error}
fi


mv -f PRSLEV.GrbF${fhr} ${outname}_${namedate}00f0${fhr}.grib2
touch ${outname}_${namedate}00f0${fhr}.grib2_ready1

#${WGRIB} ${outname}_${namedate}00f0${fhr}.grib2 | \
#         grep -F -f testbed.txt | \
#         ${WGRIB} -i -grib ${outname1}_${namedate}00f0${fhr}.grib2 ${outname}_${namedate}00f0${fhr}.grib2

if [ ! -d ${DATAHOME}/LAMprod_${namedate}00 ]; then
   mkdir -p ${DATAHOME}/LAMprod_${namedate}00
fi
  
memberstr=member`printf %03i $(( ${memberid} + 1 ))`

if [ ! -d ${DATAHOME}/LAMprod_${namedate}00/${memberstr} ]; then
   mkdir -p ${DATAHOME}/LAMprod_${namedate}00/${memberstr}
fi
  mv -f ${outname}_${namedate}00f0${fhr}.grib2 ${outname}_${namedate}00f0${fhr}.grib2_ready1 \
        ${DATAHOME}/LAMprod_${namedate}00/${memberstr}/

SCHOONER=/work/HWT_2021/HWT_MAP_ensemble1

${SCRIPT_UPP}/upload_schooner.sh ${SCHOONER}/GSI_${namedate}0000/${memberstr} \
                                 ${DATAHOME}/LAMprod_${namedate}00/${memberstr}/${outname}_${namedate}00f0${fhr}.grib2 \
                                 ${DATAHOME}/LAMprod_${namedate}00/${memberstr}/${outname}_${namedate}00f0${fhr}.grib2_ready1

error=$?
while [ ${error} -ne 0 ]; do
${SCRIPT_UPP}/upload_schooner.sh ${SCHOONER}/GSI_${namedate}0000/${memberstr} \
                                 ${DATAHOME}/LAMprod_${namedate}00/${memberstr}/${outname}_${namedate}00f0${fhr}.grib2 \
                                 ${DATAHOME}/LAMprod_${namedate}00/${memberstr}/${outname}_${namedate}00f0${fhr}.grib2_ready1
  error=$?
done

if [ ${memberid} -eq 9 ] && [ ${fhr} -eq 36 ]; then
  ${SCRIPT_UPP}/upload_schooner_flag.sh ${SCHOONER}/GSI_${namedate}0000/
fi

${ECHO} "unipost.ksh completed at `${DATE}`"
${ECHO} "" > ${DATAHOME}/fv3prd_mem${ensmemid}/postdone.${fhr}

exit 0
