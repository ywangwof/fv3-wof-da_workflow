#!/bin/ksh --login

# *** THIS SCRIPT IS FOR CLEANING OUT SUBDIRECTORIES IN ${CYCLE_DIR} ***


# Load modules
module load intel
#module load impi
module load mvapich2
module load netcdf

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
MPIRUN=mpiexec


#CYCLE_DIR=/mnt/pan2/projects/wrfruc/dowell/hrrrens/cycle
#CYCLE_DIR=/mnt/pan2/projects/wrfruc/hrrre/cycle
#START_TIME=2016062121


# Check to make sure that CYCLE_DIR is defined
if [ ! ${CYCLE_DIR} ]; then
  ${ECHO} "ERROR: \$CYCLE_DIR, is not defined"
  exit 1
fi

# Make sure the START_TIME is in the correct format
if [ `${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{10}$/'` ]; then
  START_TIME=`${ECHO} "${START_TIME}" | ${SED} 's/\([[:digit:]]\{2\}\)$/ \1/'`
elif [ ! "`${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{8}[[:blank:]]{1}[[:digit:]]{2}$/'`" ]; then
  ${ECHO} "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi

START_TIME=`${DATE} -d "${START_TIME}"`


# Print run parameters
${ECHO}
${ECHO} "scrub.ksh started at `${DATE}`"
${ECHO}
${ECHO} " CYCLE_DIR = ${CYCLE_DIR}"
${ECHO} "START_TIME = ${START_TIME}"

f=0
f_max=21

while [[ $f -le $f_max ]];do

  CURRENT_TIME=`${DATE} -d "${START_TIME}  ${f} hours"`
  YYYYMMDDHH=`${DATE} +"%Y%m%d%H" -d "${CURRENT_TIME}"`

  # Enter directory where files are to be deleted
  cd ${CYCLE_DIR}/${YYYYMMDDHH}

  ${ECHO} "removing files in ${CYCLE_DIR}/${YYYYMMDDHH}"

  ${RM} enkfprd_d0?/analysis.ensmean
  ${RM} enkfprd_d0?/firstguess.*

  ${RM} gsiprd_d0?/obs*
  ${RM} gsiprd_d0?/pe*
  ${RM} gsiprd_d0?/sigf03
  ${RM} gsiprd_d0?/wrf_inout_ensmean

  ${RM} wrfprd*/wrfbdy*
  ${RM} wrfprd*/wrfinput*
  ${RM} wrfprd*/wrfout*
  ${RM} wrfprd*/wrfvar*

  ${RM} wrfprd*/rsl*/rsl.*.0001
  ${RM} wrfprd*/rsl*/rsl.*.0002
  ${RM} wrfprd*/rsl*/rsl.*.0003
  ${RM} wrfprd*/rsl*/rsl.*.0004
  ${RM} wrfprd*/rsl*/rsl.*.0005
  ${RM} wrfprd*/rsl*/rsl.*.0006
  ${RM} wrfprd*/rsl*/rsl.*.0007
  ${RM} wrfprd*/rsl*/rsl.*.0008
  ${RM} wrfprd*/rsl*/rsl.*.0009
  ${RM} wrfprd*/rsl*/rsl.*.001*
  ${RM} wrfprd*/rsl*/rsl.*.002*
  ${RM} wrfprd*/rsl*/rsl.*.003*
  ${RM} wrfprd*/rsl*/rsl.*.004*
  ${RM} wrfprd*/rsl*/rsl.*.005*
  ${RM} wrfprd*/rsl*/rsl.*.006*
  ${RM} wrfprd*/rsl*/rsl.*.007*

  (( f += 1 ))

done

${ECHO} "scrub.ksh completed at `${DATE}`"

exit 0
