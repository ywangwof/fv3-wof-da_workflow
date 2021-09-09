#!/bin/ksh --login
##########################################################################
#
#Script Name: wrf_arw_cycle.ksh
#
##########################################################################

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
MPIRUN="srun"

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

if [ ! "${GSIPROC}" ]; then
  echo "ERROR: The variable $GSIPROC must be set to contain the number of processors to run GSI"
  exit 1
fi
echo "GSIPROC = ${GSIPROC}"

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

if [ ! "${NUM_DOMAINS}" ]; then
  echo "ERROR: \$NUM_DOMAINS is not defined!"
  exit 1
fi
echo "NUM_DOMAINS = ${NUM_DOMAINS}"

if [ ! "${CONV_RADAR}" ]; then
   echo "ERROT: \$CONV_RADAR is not defined"
   exit 1
fi
echo "CONV_RADAR = ${CONV_RADAR}"

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

 GSI_NAMELIST=${GSI_ROOT}/comgsi_namelist.sh
 if_clean=clean
 if_observer=Yes

# loop over ensemble members
ensmem=${ENS_MEM_START}
(( end_member = ${ENS_MEM_START} + ${ENS_MEMNUM_THIS} ))

while [[ $ensmem -lt $end_member ]];do

 print "\$ensmem is $ensmem"
 ensmemid=`printf %4.4i $ensmem`
 member="mem"`printf %03i $ensmem`

 DOMAIN=1
 while [[ $DOMAIN -le $NUM_DOMAINS ]];do

   echo "DOMAIN = ${DOMAIN}"

     # Run GSI for ensemble member > 1
     print "\$ensmem is $ensmem"
     loop="01"

     echo "member mean has run"

     if [ ${RADAR_ONLY} -eq 1 ]; then
       workdir=${WORK_ROOT}/gsiprd_radar_d0${DOMAIN}/mem${ensmemid}
     elif [ ${CONV_ONLY} -eq 1 ]; then
       workdir=${WORK_ROOT}/gsiprd_d0${DOMAIN}/mem${ensmemid}
     fi
     if [ -d "${workdir}" ]; then
       echo "Remove existing member directory"
       rm -rf ${workdir}
     fi
     echo "Create member directory: ${workdir}"
     mkdir -p ${workdir}
     cd ${workdir}

     if [ ! -e ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/fv_core.res.tile1_new.nc ]; then
        BK_DIR=${WORK_ROOT}/fv3prd_mem${ensmemid}/GUESS
        BK_DIR1=${WORK_ROOT}/fv3prd_mem${ensmemid}/GUESS
     else
        BK_DIR=${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA
        BK_DIR1=${WORK_ROOT}/fv3prd_mem${ensmemid}/GUESS
     fi
     ln -sf ${BK_DIR1}/coupler.res coupler.res
     ln -sf ${BK_DIR1}/fv_core.res.nc fv3_akbk
     ln -sf ${BK_DIR1}/grid_spec_new.nc fv3_grid_spec
     ln -sf ${BK_DIR1}/sfc_data_new.nc fv3_sfcdata
     ln -sf ${BK_DIR}/fv_core.res.tile1_new.nc fv3_dynvars
     ln -sf ${BK_DIR}/fv_tracer.res.tile1_new.nc fv3_tracer
     ln -sf ${BK_DIR}/phy_data.nc fv3_phyvars


     if [ ${CONV_ONLY} -eq 1 ]; then
       ANA_ROOT_DIR=${WORK_ROOT}/enkfprd_d01
     elif [ ${RADAR_ONLY} -eq 1 ]; then
       ANA_ROOT_DIR=${WORK_ROOT}/enkfprd_radar_d01
     fi
     rm -f ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_dynvar
     rm -f ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_tracer
     rm -f ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_phyvar
     #${MPIRUN} -n 1 -o ${BEGPROC} cp -f ${BK_DIR}/fv_core.res.tile1_new.nc ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_dynvar
     #${MPIRUN} -n 1 -o ${BEGPROC} cp -f ${BK_DIR}/fv_tracer.res.tile1_new.nc ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_tracer
     #${MPIRUN} -n 1 -o ${BEGPROC} cp -f ${BK_DIR}/phy_data.nc ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_phyvar
     cp -f ${BK_DIR}/fv_core.res.tile1_new.nc ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_dynvar
     cp -f ${BK_DIR}/fv_tracer.res.tile1_new.nc ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_tracer
     cp -f ${BK_DIR}/phy_data.nc ${ANA_ROOT_DIR}/fv3sar_tile1_${member}_phyvar

     if [ ${RADAR_ONLY} -eq 1 ]; then
       ln -s ../dbzobs.nc .
     fi
     if [ ${CONV_ONLY} -eq 1 ]; then
       ln -s ../prepbufr .
     fi
     ln -s ../gsi.exe .
     ln -s ../anavinfo .
     ln -s ../berror_stats .
     ln -s ../satbias_angle .
     ln -s ../satinfo .
     ln -s ../convinfo .
     ln -s ../ozinfo .
     ln -s ../pcpinfo .
     ln -s ../scaninfo .
     ln -s ../errtable .
     ln -s ../prepobs_prep.bufrtable .
     ln -s ../satbias_in .
     ln -s ../gsiparm.anl .
     ln -s ../obs_input.* .

     echo ' Run GSI for member ', ${ensmemid}
     itry=1
     while [ ${itry} -le 3 ]; do
       #${MPIRUN} -n ${PROC} -o ${BEGPROC} ./gsi.exe > stdout 2>&1
       echo "Runing gsi.exe in $(pwd) for ${ensmemid} at itry = $itry ...."
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

     ls -l * > ../list_run_directory_mem${ensmemid}

     mv stdout ../stdout_mem${ensmemid}

     case $loop in
         01) string=ges;;
         03) string=anl;;
          *) string=$loop;;
     esac

     listall=`ls pe* | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-3)}' | sort | uniq `

     for type in $listall; do
       count=`ls pe*${type}_${loop}* | wc -l`
       if [[ $count -gt 0 ]]; then
         cat pe*${type}_${loop}* > ../diag_${type}_${string}.mem${ensmemid}
       fi
     done

     # remove member directory
     cd ..
     rm -rf ${workdir}


   (( DOMAIN += 1 ))
 done

# next member
   (( ensmem += 1 ))
done

exit 0
