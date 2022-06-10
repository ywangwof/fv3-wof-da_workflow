#!/bin/bash

rootdir="/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap"
evtdate="20210527"
runtimes=(1700 1800 1900 2000 2100 2200 2300 0000 0100 0200 0300)
suite="NSSL"

subcom="${1-run}"

function subdir {
    local subcom=$1
    local timestr=$2
    local memid=$3

    case $subcom in
    run)
        memstr=$(printf "%04d" $memid)
        if [[ ${timestr#0} -lt 1000 ]]; then
            nextday="1 day"
        else
            nextday=""
        fi
        runtime=$(date -d "$evtdate $timestr $nextday" +%Y%m%d%H%M)
        runsubdir="$runtime/fv3prd_mem$memstr"
        ;;
    cvt)
        memstr=$(printf "%02d" $memid)
        runsubdir="$timestr/ENS_MEM_$memstr"
        ;;
    post)
        runsubdir="$timestr"
        ;;
    plot)
    ;;
    *)
        echo "Subcomponent to be checked. One of (run, cvt, post, plot)."
        exit 0
    ;;
    esac
    echo $runsubdir
}

case $subcom in
run)
    wrkdir="$rootdir/rundir/$suite/$evtdate"
    filenote="dynf"
    nens=18
    ;;
cvt)
    wrkdir="$rootdir/rundir/$suite/FV3_WOFS/FCST/$evtdate"
    filenote="woffv3_d01"
    nens=18
    ;;
post)
    wrkdir="$rootdir/rundir/$suite/summary_files/$evtdate"
    filenote="POST"
    fileheads=("wofs_ENV" "wofs_ENS" "wofs_SVR" "wofs_SWT" "wofs_SND" "wofs_30M" "wofs_60M")
    nens=${#fileheads[@]}
    ;;
plot)
    wrkdir="$rootdir/rundir/$suite/images/$evtdate"
    filenote="PLOT"
    fileheads=("member" "wofs_ENS" "wofs_SVR" "wofs_SWT" "wofs_SND" "wofs_30M" "wofs_60M")
    nens=${#fileheads[@]}
    ;;
*)
    echo "Subcomponent to be checked. One of (run, cvt, post, plot)."
    exit 0
;;
esac

for ctime in ${runtimes[@]}; do
    echo -n "$filenote: $ctime - "
    for cmem in $(seq 1 $nens); do
        if [[ -v fileheads ]]; then
            indx=$(( cmem-1 ))
            filehead=${fileheads[$indx]}
            cmem2=$filehead
        else
            cmem2=$(printf "mem%02d" $cmem)
            filehead=$filenote
        fi
        memdir=$(subdir $subcom $ctime $cmem)
        rundir="$wrkdir/$memdir"

        if [[ ! -e $rundir ]]; then
            #echo -n "; $cmem2 not exist"
            count=0
        else
            count=$(ls ${rundir}/${filehead}* 2>/dev/null | wc -l)
            #echo -n "; $cmem2 found $count"
        fi
        echo -n ";    $cmem2 # $count"
        if [[ $cmem -eq 9 ]]; then
            echo " "
            echo -n "$(printf '%*s' ${#filehead})         "
        fi
    done
    echo ""
    echo ""
done

exit 0
