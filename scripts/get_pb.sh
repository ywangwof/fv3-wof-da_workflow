#!/bin/bash

datadir="/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap/data"
#set -x
module load hpss

sd=${1-20200513}
nd=$(date -d "$sd 1 day" +%Y%m%d)

wrkdir="$datadir/$sd/prepbufr"
if [[ ! -d $wrkdir ]]; then
    mkdir -p $wrkdir
fi
cd $wrkdir

while [[ $sd -le $nd ]]; do
  yyyy=`echo $sd | cut -c1-4`
  mm=`echo $sd | cut -c5-6`
  dd=`echo $sd | cut -c7-8`

  for hh in 00 06 12 18 ; do

    echo "Retrieving /BMC/fdr/Permanent/${yyyy}/${mm}/${dd}/data/grids/rap/obs/${sd}${hh}00.zip ..."
    hsi get /BMC/fdr/Permanent/${yyyy}/${mm}/${dd}/data/grids/rap/obs/${sd}${hh}00.zip

    #unzip ${sd}${hh}00.zip "*.rtma_ru.t*00z.prepbufr.tm00" "*.rap.t*z.prepbufr.tm00"
    unzip ${sd}${hh}00.zip "*.rap.t*z.prepbufr.tm00"

  done

  sd=$(date -d "${sd} 1 day" "+%Y%m%d")

done

for fn in *.rap.t??z.prepbufr.tm00; do
    IFS='.' read -r -a array <<< "$fn"
    newfn="${array[1]}.${array[0]}.${array[3]}.${array[4]}"
    #echo "newfn = $newfn"
    mv $fn $newfn
done

rm -f *.zip

exit 0
