#! /bin/ksh

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
export exec_fp=${GSI_ROOT}/move_DA_update_data.x

${ECHO}

TILE_RGNL=7
NH0=0

# Set up the work directory and cd into it
workdir=${WORK_ROOT}
${RM} -rf ${workdir}
${MKDIR} -p ${workdir}
cd ${workdir}

FV3DIR=${HOME_ROOT}/${START_TIME}/fv3prd_mem`printf %04i ${MEM_INDEX#0}`

ANLdir=${FV3DIR}/ANA
GUESSdir=${FV3DIR}/GUESS

ln -sf ${ANLdir}/fv_core.res.tile1_new.nc .
ln -sf ${ANLdir}/fv_tracer.res.tile1_new.nc .

#${MPIRUN} -n ${PROC} -o ${BEGPROC} cp -f $GUESSdir/fv_core.res.tile1.nc fv_core.res.tile1.nc
#${MPIRUN} -n ${PROC} -o ${BEGPROC} cp -f $GUESSdir/fv_tracer.res.tile1.nc fv_tracer.res.tile1.nc
cp -f $GUESSdir/fv_core.res.tile1.nc fv_core.res.tile1.nc
cp -f $GUESSdir/fv_tracer.res.tile1.nc fv_tracer.res.tile1.nc

BNDY_IND=`basename $ANLdir/gfs_bndy.tile7.???.nc | cut -c16-18`
cp $ANLdir/gfs_bndy.tile7.${BNDY_IND}.nc .

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/apps/netcdf/4.7.4/intel/18.0.5/lib
echo "Running '${exec_fp} ${BNDY_IND}' in $(pwd) ...."
#${MPIRUN} -n ${PROC} -o ${BEGPROC} ${exec_fp} ${BNDY_IND}
${MPIRUN} -n ${PROC} ${exec_fp} ${BNDY_IND}

error=$?
if [ ${error} -ne 0 ]; then
  echo "Move DA update wrong"
  exit 1
fi

#Put new 000-h BC file and modified original restart files into ANLdir
cp gfs_bndy.tile7.${BNDY_IND}_gsi.nc $ANLdir/
mv -f fv_core.res.tile1.nc $ANLdir/fv_core.res.tile1.nc
mv -f fv_tracer.res.tile1.nc $ANLdir/fv_tracer.res.tile1.nc
echo "Copying fv_core.res.nc from $GUESSdir to $ANLdir ..."
cp -f $GUESSdir/fv_core.res.nc $ANLdir/fv_core.res.nc
cp -f $GUESSdir/coupler.res $ANLdir/coupler.res
     #mv -f fv3_grid_spec $ANLdir/grid_spec_new.nc

exit 0

######### EOF ###########
