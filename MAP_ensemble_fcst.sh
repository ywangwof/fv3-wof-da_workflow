#! /bin/sh
#SBATCH -J HWT_rtA
#SBATCH -o ./HWT_rtA.log
#SBATCH -n 3360
#SBATCH --partition=sjet,vjet,xjet,kjet
#SBATCH -t 05:30:00
#SBATCH -A hpc-wof1

# ---- April 3 2021, initially created by Y. Wang & X. Wang (OU MAP Lab)
#                    yongming.wang@ou.edu  xuguang.wang@ou.edu
##########################################################################

. system_env.dat_rt

SH=/bin/sh

if_skip_all=no

if [ ${if_skip_all} == 'yes' ]; then
  if_skip_fcst6h=yes
  if_skip_upp=yes
else
  if_skip_fcst6h=yes
  if_skip_upp=no
fi

mkdir -p ${LOG_DIR}

# --- Free forecast
# ---

ifcst=3
ens_size_fcst=18
fcst_beg_s=$(date +%s -d "${FCST_BEG}")
fcst_end_s=$(date +%s -d "${FCST_END}")
icycle=${1-0}
for ((i=fcst_beg_s+icycle*3600;i<=fcst_end_s;i+=3600)); do

    FCST_DATE=$(date -d @$i +%Y%m%d%H%M)
    FCST_TIME=$(date -d @$i +%H%M)
    FCST_LENG=$(( ifcst*3600 ))

    if [ ${if_skip_fcst6h} == 'no' ]; then
      echo "Start longer forecast for ${FCST_DATE} at $(date +%Y-%m-%d_%H:%M)"

      for ((imem=1;imem<=ens_size_fcst;imem++)); do
        fv3memfile=${DATABASE_DIR}/cycle/${FCST_DATE}/movedaprd/movedaprd_${imem}/SUCCESS
        while true; do
          if [[ -e $fv3memfile ]]; then
            #echo "$fv3memfile exist"
            break
          else
            echo "Waiting for $fv3memfile"
          fi
          sleep 10
        done
      done

      # --- run FV3 for each member
      imem=1
      corenum=240

      rm -f ${LOG_DIR}/fv3fcst_${FCST_TIME}_*.sh
      cd ${LOG_DIR}

      while [ ${imem} -le ${ens_size_fcst}  ]; do

        memstr4=$(printf "%04d" $imem)

        cat << EOF > ${LOG_DIR}/fv3fcst_${FCST_TIME}_${memstr4}.sh
#!/bin/bash
#SBATCH -A ${ACCOUNT}
#SBATCH -J fv3fcst_${FCST_TIME}_${imem}
#SBATCH -o ./fv3fcst_${FCST_TIME}_${memstr4}_%j.out
#SBATCH -e ./fv3fcst_${FCST_TIME}_${memstr4}_%j.err
#SBATCH -n ${corenum}
#SBATCH --partition=${QUEUE}
#SBATCH --tasks-per-node=6
#SBATCH -t 02:30:00

  export INIT_TIME=${INIT_DATE}
  export START_TIME=${FCST_DATE}
  export FCST_LENGTH=${FCST_LENG}
  export FV3LAM_ROOT=${FV3LAM_ROOT}
  export FV3LAM_STATIC=${STATIC_DIR_FV3LAM}
  export DATAHOME=${DATABASE_DIR}
  export INIHOME=${DATAROOT_INI}
  export ENS_MEM_START=${imem}
  export ENS_MEMNUM_THIS=1
  export PROC=${corenum}

  memstr4=${memstr4}

  ${SCRIPTS}/FV3LAM/fv3lam_fcst.ksh

  error=\$?
  if [ \${error} -ne 0 ]; then
    echo "" > ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem${memstr4}/FAILED
  else
    echo "" > ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem${memstr4}/SUCCESS
  fi

EOF
        #chmod u+x ${LOG_DIR}/fv3fcst_${imem}.sh
        sbatch ${LOG_DIR}/fv3fcst_${FCST_TIME}_${memstr4}.sh

        (( imem += 1 ))

      done
      #${LOG_DIR}/fv3fcst_0.sh >& ${LOG_DIR}/fv3fcst_0.log &
      #${LOG_DIR}/fv3fcst_1.sh >& ${LOG_DIR}/fv3fcst_1.log &
      #${LOG_DIR}/fv3fcst_2.sh >& ${LOG_DIR}/fv3fcst_2.log &
      #${LOG_DIR}/fv3fcst_3.sh >& ${LOG_DIR}/fv3fcst_3.log &
      #${LOG_DIR}/fv3fcst_4.sh >& ${LOG_DIR}/fv3fcst_4.log &
      #wait

      success_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/SUCCESS 2>/dev/null | wc -l`
      echo "Waiting for ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/SUCCESS ...."
      while [ ${success_size} -lt ${ens_size_fcst} ]; do
          #echo "${success_size} memebers run fv3fcst successfully."
          fail_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/FAILED 2>/dev/null | wc -l`
          while [ ${fail_size} -gt 0 ]; do
            echo "${fail_size} members at ${FCST_DATE} run fv3fcst failed."
            break 3
            #fail_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/FAILED 2>/dev/null | wc -l`
          done
          success_size=`ls -1 ${DATABASE_DIR}/${FCST_DATE}/fv3prd_mem*/SUCCESS 2>/dev/null | wc -l`
          sleep 10
      done
    fi
done

exit 0

# --- Postprocessing
# ---
if [ ${if_skip_upp} == 'no' ]; then
  echo 'Post-processing at --- ' `date +%Y-%m-%d_%H:%M`

  freefcst_hour=$(( FCST_LENG/3600 ))
  inihr=`echo ${FCST_DATE} | cut -c9-10`
  RESULTSHOME=${DATABASE_DIR}/${FCST_DATE}

  ihr=0
  while [ ${ihr} -le ${freefcst_hour} ]; do

    hour_str2=`printf %02i ${ihr}`
    hour_str3=`printf %03i ${ihr}`
    flg_fcst=logf${hour_str3}
    flg_postbeg=postbeg.${hour_str2}
    flg_postdone=postdone.${hour_str2}
    ensemble_size=10

    count_submit=0
    while [ ${count_submit} -lt ${ensemble_size} ]; do
      imem=0
      while [ ${imem} -lt ${ensemble_size} ];do
        memstr4=`printf %04i ${imem}`
        memrundir=${RESULTSHOME}/fv3prd_mem${memstr4}

        while [ ! -e ${memrundir}/${flg_fcst} ]; do
          sleep 3
        done

        if [ -e ${memrundir}/${flg_fcst} ] && \
           [ ! -e ${memrundir}/${flg_postbeg} ] && \
           [ ! -e ${memrundir}/${flg_postdone} ]; then
          cat > ${memrundir}/upp_${imem}_${ihr}.sh << EOF
#!/bin/bash

  export START_TIME=${FCST_DATE}
  export FCST_TIME=${ihr}
  export EXE_ROOT=${EXEC}/UPP
  export DATAHOME=${DATABASE_DIR}/${FCST_DATE}
  export DOMAIN=1
  export MEMBER=${imem}
  export STATIC_DIR=${STATIC_DIR}/UPP
  export SCRIPT_UPP=${SCRIPTS}/UPP
  export PROC=14
  export OMP_NUM_THREADS=4
  export BEGPROC=$(( 5040 + ${imem} * 56 ))
  export NODEPATH=${LOG_DIR}

  ${SCRIPTS}/UPP/unipost_ens.ksh

EOF
          chmod u+x ${memrundir}/upp_${imem}_${ihr}.sh
          echo "Start to run UPP for member: "${imem}" at "${ihr} > ${memrundir}/${flg_postbeg}

          ${memrundir}/upp_${imem}_${ihr}.sh >& ${LOG_DIR}/upp_${ihr}_${imem}.log &

          (( count_submit = count_submit + 1 ))
          (( imem = imem + 1 ))

        else
          #sleep 3
          if [ -e ${memrundir}/${flg_fcst} ] && \
             [ -e ${memrundir}/${flg_postbeg} ] && \
             [ -e ${memrundir}/${flg_postdone} ]; then
             (( imem = imem + 1 ))
             (( count_submit = count_submit + 1 ))
          fi
        fi
      done
    done

    count_num=`ls -l ${RESULTSHOME}/fv3prd_mem*/${flg_postdone} 2>/dev/null | wc -l`
    while [ ${count_num} -lt ${ensemble_size} ]; do
      sleep 5
      count_num=`ls -l ${RESULTSHOME}/fv3prd_mem*/${flg_postdone} 2>/dev/null | wc -l`
    done
    (( ihr = ihr + 1 ))
  done
fi

exit
#--- Clean

. $HOMEBASE_DIR/system_env.dat_rt

ymd=${INIT_DATE:0:8}
hhr=${INIT_DATE:8:2}
min=${INIT_DATE:10:2}


save_wrf_cycle=201804300000
icycle=1
while [ ${icycle} -le 99 ]; do

  thiscycle=`date +%Y%m%d%H%M -d "${ymd} ${hhr}:${min} ${DA_INTV} minutes"`
  ymdthis=`echo ${thiscycle} | cut -c1-8`
  hhrthis=`echo ${thiscycle} | cut -c9-10`
  minthis=`echo ${thiscycle} | cut -c11-12`
  lastcycle=`date +%Y%m%d%H%M -d "${ymdthis} ${hhrthis}:${minthis} ${DA_INTV} minutes ago"`
  nextcycle=`date +%Y%m%d%H%M -d "${ymdthis} ${hhrthis}:${minthis} ${DA_INTV} minutes"`
  if [ ${nextcycle} -eq ${radar_cycle_date} ]; then
    save_wrf_cycle=${thiscycle}
  fi

  if [ ${thiscycle} -gt ${END_DATE} ]; then
    echo "DA finished !"
    break
  fi

  keepwrf=0
  if [ ${thiscycle} -eq ${END_DATE} ] || [ ${thiscycle} -eq ${save_wrf_cycle}  ] ; then
    keepwrf=1
  fi
  cat > ${LOG_DIR}/clean_${thiscycle}.sh << EOF
#! /bin/sh
#SBATCH -J clean_${thiscycle}
#SBATCH -o ${LOG_DIR}/clean_${thiscycle}.log
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=${QUEUE1}
#SBATCH -t 3:00:00
#SBATCH -A ${ACCOUNT}
#${SBATCH_OPT}

export DATAHOME=${DATABASE_DIR}/cycle/${thiscycle}
export KEEPWRF=${keepwrf}
export NEXTDATE=${nextcycle}
export THSIDATE=${thiscycle}

${SCRIPTS}/UPP/clean.ksh

EOF

  sbatch ${LOG_DIR}/clean_${thiscycle}.sh

  (( icycle = icycle + 1  ))

  if [ ${thiscycle} -ge ${radar_cycle_date} ] && [ ${thiscycle} -le ${END_DATE} ]; then
    DA_INTV=${radar_cycle_intv}
  fi
  ymd=`echo ${thiscycle} | cut -c1-8`
  hhr=`echo ${thiscycle} | cut -c9-10`
  min=`echo ${thiscycle} | cut -c11-12`
done

#

#cd ${DATABASE_DIR}
#tar -cvf Pre_data.tar ensemble_BG prepbufr  radar

# ----------------------------- EoF --------------------------
