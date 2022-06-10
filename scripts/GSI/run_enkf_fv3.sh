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

if [ ! "${CONV_RADAR_FLAG}" ]; then
   echo "ERROT: \$CONV_RADAR_FLAG is not defined"
   exit 1
fi
echo "CONV_RADAR_FLAG = ${CONV_RADAR_FLAG}"

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
#if [ ${CONV_ONLY} -eq 1  ]; then
    ENKF_ROOT=${WORK_ROOT}/enkfprd_d0${DOMAIN}
    diag_ROOT=${WORK_ROOT}/gsiprd_d0${DOMAIN}
    #ENKF_NAMELIST=${GSI_ROOT}/enkf_wrf_namelist.sh
#elif [ ${RADAR_ONLY} -eq 1 ]; then
#    ENKF_ROOT=${WORK_ROOT}/enkfprd_radar_d0${DOMAIN}
#    diag_ROOT=${WORK_ROOT}/gsiprd_radar_d0${DOMAIN}
#    ENKF_NAMELIST=${GSI_ROOT}/enkf_fv3_namelist_wof.sh
#fi

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
#  Merge dynvar and tracer to dynvartracer, why? not used anywhere - WYH
###################################################
# rm -f *_dynvartracer
#
# imem=1
# while [[ $imem -le $NMEM_ENKF ]]; do
#     member=$(printf "%03d" $imem)
#     echo "Merging fv3sar_tile1_mem${member}_dynvar and fv3sar_tile1_mem${member}_tracer to fv3sar_tile1_mem${member}_dynvartracer"
#     ${CP} fv3sar_tile1_mem${member}_dynvar fv3sar_tile1_mem${member}_dynvartracer
#     srun -n 1 -N 1 -c 1 ncks -A fv3sar_tile1_mem${member}_tracer fv3sar_tile1_mem${member}_dynvartracer &
#     (( imem = $imem + 1 ))
# done
# echo "Merge fv3sar_tile1_ensmean_dynvar and fv3sar_tile1_ensmean_tracer to fv3sar_tile1_ensmean_dynvartracer"
# ${CP} fv3sar_tile1_ensmean_dynvar fv3sar_tile1_ensmean_dynvartracer
# ncks -A fv3sar_tile1_ensmean_tracer fv3sar_tile1_ensmean_dynvartracer
#
# for ((imem=1;imem<=$NMEM_ENKF;imem++)); do
#     member=$(printf "%03d" $imem)
#     filename="fv3sar_tile1_mem${member}_dynvartracer"
#     filesize=$(stat -c %s $filename)
# #    while [[ $filesize -lt 727000000 ]];do
#     while [[ $filesize -lt  400000000 ]]; do
#         echo "waiting for $filename to be ready ...."
#         sleep 10
#         filesize=$(stat -c %s $filename)
#     done
# done

#filename="fv3sar_tile1_ensmean_dynvartracer"
#fizesize=$(stat -c%s "$filename")
#while [[ $filesize -lt 7270000000 ]];do
#    echo "waiting for $filename to be ready ...."
#    sleep 10
#    fizesize=$(stat -c%s "$filename")
#done

#sleep 10

# Build the GSI namelist on-the-fly
#if [ ${CONV_ONLY} -eq 1  ]; then
#    COVINFLATENH=0.0
#    COVINFLATESH=0.0
#    COVINFLATETR=0.0
#    CORRLENGTHNH=300
#    CORRLENGTHSH=300
#    CORRLENGTHTR=300
#    CORRLENGTHV=0.55
#    cp -f ${ENKF_STATIC}/anavinfo_fv3_enkf_con ./anavinfo
#fi

#if [ ${RADAR_ONLY} -eq 1 ]; then
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
#fi

IF_RH=0

if [ ${IF_RH} -eq 1 ]; then
  pseudo_rh='.true.'
else
  pseudo_rh='.false.'
fi

#. $ENKF_NAMELIST
echo "Generating enkf.nml ..."
cat << EOF > enkf.nml
 &nam_enkf
  datestring          = ${gdate},
  datapath            = './',
  analpertwtnh        = 0.0, !1.05,
  analpertwtsh        = 0.0, !1.05,
  analpertwttr        = 0.9, !1.05,
  lupd_satbiasc       = .false.,
  zhuberleft          = 1.e10,
  zhuberright         = 1.e10,
  huber               = .false.,
  varqc               = .false.,
  covinflatemax       = 1.e2,
  covinflatemin       = 1.0,

  covinflatenh=${COVINFLATENH},
  covinflatesh=${COVINFLATESH},
  covinflatetr=${COVINFLATETR},
  lnsigcovinfcutoff=6,

  pseudo_rh           = ${pseudo_rh},
  corrlengthnh        = ${CORRLENGTHNH},
  corrlengthsh        = ${CORRLENGTHSH},
  corrlengthtr        = ${CORRLENGTHTR},
  obtimelnh           = 1.e30,
  obtimelsh           = 1.e30,
  obtimeltr           = 1.e30,
  iassim_order        = 0,
  lnsigcutoffnh       = ${CORRLENGTHV},
  lnsigcutoffsh       = ${CORRLENGTHV},
  lnsigcutofftr       = ${CORRLENGTHV},
  lnsigcutoffsatnh    = ${CORRLENGTHS},
  lnsigcutoffsatsh    = ${CORRLENGTHS},
  lnsigcutoffsattr    = ${CORRLENGTHS},
  lnsigcutoffpsnh     = ${CORRLENGTHV},
  lnsigcutoffpssh     = ${CORRLENGTHV},
  lnsigcutoffpstr     = ${CORRLENGTHV},
  simple_partition    = .true.,
  nlons               = $NLONS,
  nlats               = $NLATS,
  smoothparm          = -1,
  readin_localization = .false.,
  saterrfact          = 1.0,
  numiter             = 4,
  newpc4pred          = .true.,
  adp_anglebc         = .false,
  angord              = 4,
  sprd_tol            = 3.25,
  paoverpb_thresh     = 1.0,
  reducedgrid         = .false.,
  nlevs               = $NLEVS,
  nanals              = $NMEM_ENKF,
  nbackgrounds        = 1,
  deterministic       = .true.,
  sortinc             = .true.,
  letkf_flag          = .false.,
  univaroz            = .false.,
  regional            = .false.,
  use_edges           = .false.,
  emiss_bc            = .true.,
  biasvar             = -500
  fv3_native          = .true.,
 /
 &satobs_enkf
  sattypes_rad(1)     = 'amsua_n15',     dsis(1) = 'amsua_n15',
  sattypes_rad(2)     = 'amsua_n18',     dsis(2) = 'amsua_n18',
  sattypes_rad(3)     = 'amsua_n19',     dsis(3) = 'amsua_n19',
  sattypes_rad(4)     = 'amsub_n16',     dsis(4) = 'amsub_n16',
  sattypes_rad(5)     = 'amsub_n17',     dsis(5) = 'amsub_n17',
  sattypes_rad(6)     = 'amsua_aqua',    dsis(6) = 'amsua_aqua',
  sattypes_rad(7)     = 'amsua_metop-a', dsis(7) = 'amsua_metop-a',
  sattypes_rad(8)     = 'airs_aqua',     dsis(8) = 'airs281SUBSET_aqua',
  sattypes_rad(9)     = 'hirs3_n17',     dsis(9) = 'hirs3_n17',
  sattypes_rad(10)    = 'hirs4_n19',     dsis(10)= 'hirs4_n19',
  sattypes_rad(11)    = 'hirs4_metop-a', dsis(11)= 'hirs4_metop-a',
  sattypes_rad(12)    = 'mhs_n18',       dsis(12)= 'mhs_n18',
  sattypes_rad(13)    = 'mhs_n19',       dsis(13)= 'mhs_n19',
  sattypes_rad(14)    = 'mhs_metop-a',   dsis(14)= 'mhs_metop-a',
  sattypes_rad(15)    = 'goes_img_g11',  dsis(15)= 'imgr_g11',
  sattypes_rad(16)    = 'goes_img_g12',  dsis(16)= 'imgr_g12',
  sattypes_rad(17)    = 'goes_img_g13',  dsis(17)= 'imgr_g13',
  sattypes_rad(18)    = 'goes_img_g14',  dsis(18)= 'imgr_g14',
  sattypes_rad(19)    = 'goes_img_g15',  dsis(19)= 'imgr_g15',
  sattypes_rad(20)    = 'avhrr3_n18',    dsis(20)= 'avhrr3_n18',
  sattypes_rad(21)    = 'avhrr3_metop-a',dsis(21)= 'avhrr3_metop-a',
  sattypes_rad(22)    = 'avhrr3_n19',    dsis(22)= 'avhrr3_n19',
  sattypes_rad(23)    = 'amsre_aqua',    dsis(23)= 'amsre_aqua',
  sattypes_rad(24)    = 'ssmis_f16',     dsis(24)= 'ssmis_f16',
  sattypes_rad(25)    = 'ssmis_f17',     dsis(25)= 'ssmis_f17',
  sattypes_rad(26)    = 'ssmis_f18',     dsis(26)= 'ssmis_f18',
  sattypes_rad(27)    = 'ssmis_f19',     dsis(27)= 'ssmis_f19',
  sattypes_rad(28)    = 'ssmis_f20',     dsis(28)= 'ssmis_f20',
  sattypes_rad(29)    = 'sndrd1_g11',    dsis(29)= 'sndrD1_g11',
  sattypes_rad(30)    = 'sndrd2_g11',    dsis(30)= 'sndrD2_g11',
  sattypes_rad(31)    = 'sndrd3_g11',    dsis(31)= 'sndrD3_g11',
  sattypes_rad(32)    = 'sndrd4_g11',    dsis(32)= 'sndrD4_g11',
  sattypes_rad(33)    = 'sndrd1_g12',    dsis(33)= 'sndrD1_g12',
  sattypes_rad(34)    = 'sndrd2_g12',    dsis(34)= 'sndrD2_g12',
  sattypes_rad(35)    = 'sndrd3_g12',    dsis(35)= 'sndrD3_g12',
  sattypes_rad(36)    = 'sndrd4_g12',    dsis(36)= 'sndrD4_g12',
  sattypes_rad(37)    = 'sndrd1_g13',    dsis(37)= 'sndrD1_g13',
  sattypes_rad(38)    = 'sndrd2_g13',    dsis(38)= 'sndrD2_g13',
  sattypes_rad(39)    = 'sndrd3_g13',    dsis(39)= 'sndrD3_g13',
  sattypes_rad(40)    = 'sndrd4_g13',    dsis(40)= 'sndrD4_g13',
  sattypes_rad(41)    = 'sndrd1_g14',    dsis(41)= 'sndrD1_g14',
  sattypes_rad(42)    = 'sndrd2_g14',    dsis(42)= 'sndrD2_g14',
  sattypes_rad(43)    = 'sndrd3_g14',    dsis(43)= 'sndrD3_g14',
  sattypes_rad(44)    = 'sndrd4_g14',    dsis(44)= 'sndrD4_g14',
  sattypes_rad(45)    = 'sndrd1_g15',    dsis(45)= 'sndrD1_g15',
  sattypes_rad(46)    = 'sndrd2_g15',    dsis(46)= 'sndrD2_g15',
  sattypes_rad(47)    = 'sndrd3_g15',    dsis(47)= 'sndrD3_g15',
  sattypes_rad(48)    = 'sndrd4_g15',    dsis(48)= 'sndrD4_g15',
  sattypes_rad(49)    = 'iasi_metop-a',  dsis(49)= 'iasi616_metop-a',
  sattypes_rad(50)    = 'seviri_m08',    dsis(50)= 'seviri_m08',
  sattypes_rad(51)    = 'seviri_m09',    dsis(51)= 'seviri_m09',
  sattypes_rad(52)    = 'seviri_m10',    dsis(52)= 'seviri_m10',
  sattypes_rad(53)    = 'amsua_metop-b', dsis(53)= 'amsua_metop-b',
  sattypes_rad(54)    = 'hirs4_metop-b', dsis(54)= 'hirs4_metop-b',
  sattypes_rad(55)    = 'mhs_metop-b',   dsis(55)= 'mhs_metop-b',
  sattypes_rad(56)    = 'iasi_metop-b',  dsis(56)= 'iasi616_metop-b',
  sattypes_rad(57)    = 'avhrr3_metop-b',dsis(57)= 'avhrr3_metop-b',
  sattypes_rad(58)    = 'atms_npp',      dsis(58)= 'atms_npp',
  sattypes_rad(59)    = 'cris_npp',      dsis(59)= 'cris_npp',
  sattypes_rad(60)    = 'abi_g16',       dsis(60)= 'abi_g16',
 /
 &ozobs_enkf
  sattypes_oz(1)      = 'sbuv2_n16',
  sattypes_oz(2)      = 'sbuv2_n17',
  sattypes_oz(3)      = 'sbuv2_n18',
  sattypes_oz(4)      = 'sbuv2_n19',
  sattypes_oz(5)      = 'omi_aura',
  sattypes_oz(6)      = 'gome_metop-a',
  sattypes_oz(7)      = 'gome_metop-b',
 /
 &nam_wrf
  arw                 = $IF_ARW,
  nmm                 = $IF_NMM,
 /
 &nam_fv3
  nx_res              = $NLONS,
  ny_res              = $NLATS,
  ntiles              = 1,
  fv3fixpath          = 'none',
 /

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
    ensmemid4=$(printf "%04d" $imem)
    ensmemid3=$(printf "%03d" $imem)
    if [ -e ${WORK_ROOT}/fv3prd_mem${ensmemid4}/ANA/fv_core.res.tile1_new.nc ]; then
        echo "Found ${WORK_ROOT}/fv3prd_mem${ensmemid4}/ANA/fv_core.res.tile1_new.nc. Overwrite it."
       #mv ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV
       #mkdir -p ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA
       #mv -f ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV/fv_srf_wnd.res.tile1.nc ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/
       #mv -f ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV/gfs_bndy.tile7.001.nc ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/
       #mv -f ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA_CONV/sfc_data.nc ${WORK_ROOT}/fv3prd_mem${ensmemid}/ANA/
    fi
    ANA_DIR=${WORK_ROOT}/fv3prd_mem${ensmemid4}/ANA
    if [[ ! -r ${ANA_DIR} ]]; then
        echo "ERROR: ${ANA_DIR} not exist."
    fi

    echo "Moving member ${ensmemid4} with enkf member analysis"
    ${CP} -f fv3sar_tile1_mem${ensmemid3}_dynvar ${ANA_DIR}/fv_core.res.tile1_new.nc
    ${CP} -f fv3sar_tile1_mem${ensmemid3}_tracer ${ANA_DIR}/fv_tracer.res.tile1_new.nc
    ${CP} -f fv3sar_tile1_mem${ensmemid3}_phyvar ${ANA_DIR}/phy_data.nc

    (( imem = $imem + 1 ))
done

###################################################
# Provide signal to next process                  #
###################################################

#if [ -e ${WORK_ROOT}/obsprd/${ANALYSIS_TIME} ]; then
#   if [ ${CONV_ONLY} -eq 1 ]; then
#     ${ECHO} "" > ${WORK_ROOT}/READY_RADAR_DA
#     ${ECHO} "" > ${WORK_ROOT}/EnKF_DONE_CONV
#   else
#     ${ECHO} "" > enkf_finished
#     ${ECHO} "" > ${WORK_ROOT}/EnKF_DONE_RADAR
#   fi
#else
#   ${ECHO} "" > enkf_finished
#   ${ECHO} "" > ${WORK_ROOT}/EnKF_DONE_CONV
#fi
${ECHO} "" > enkf_finished
${ECHO} "" > ${WORK_ROOT}/EnKF_DONE

${ECHO} "run_enkf_wrf.ksh terminated at `${DATE}`"

exit
