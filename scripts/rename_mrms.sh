#!/bin/bash

dirs=(00.25  01.00  01.75  02.50  03.50  05.00  06.50  08.00  10.00  13.00  16.00  19.00  \
      00.50  01.25  02.00  02.75  04.00  05.50  07.00  08.50  11.00  14.00  17.00  20.00 \
      00.75  01.50  02.25  03.00  04.50  06.00  07.50  09.00  12.00  15.00  18.00  21.00)

for dir in ${dirs[@]}; do
    for fn in $dir/*.netcdf; do
        newfn=${fn/??.netcdf/00.netcdf}
        if [[ $fn != $newfn ]]; then
            echo "$fn -> $newfn"
            mv $fn $newfn
        fi
    done
done

exit 0
