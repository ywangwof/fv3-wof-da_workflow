#!/bin/bash

set -u

eventdt=${1-20200515}
sourceroot="/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2"    # up to GRID_YYYYMMDDHH
targetdir="/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/oumap/da-forecast-workflow"    # up to da-forecast-workflow

sourcedir="${sourceroot}/expt_dirs/GRID_${eventdt}15"
tmplfile="${sourceroot}/templates/configGrid_${eventdt}15_jet.sh"

source $tmplfile
output_grid=${WRTCMP_output_grid}
cen_lat=${ESGgrid_LAT_CTR}
cen_lon=${ESGgrid_LON_CTR}
stdlat1=${WRTCMP_stdlat1}
stdlat2=${WRTCMP_stdlat2}
nx=${WRTCMP_nx}
ny=${WRTCMP_ny}
dx=${WRTCMP_dx}
dy=${WRTCMP_dy}
lat1=${WRTCMP_lat_lwr_left}
lon1=${WRTCMP_lon_lwr_left}

#echo "output_grid=${output_grid}, cen_lat=${cen_lat}, cen_lon=${cen_lon}, stdlat1=${stdlat1}, stdlat2=${stdlat2}"
#echo "nx=${nx}, ny=${ny}, dx=${dx}, dy=${dy}, lat1=${lat1}, lon1=${lon1}"
#exit 0
#grid_name="$1"
res="3337"

fixdir="${targetdir}/static/CHGRES/Fix_sar.$eventdt"
if [[ ! -r $fixdir ]]; then
    mkdir -p $fixdir
else
    #echo "$fixdir exists. Exiting ..."
    #exit 0
    rm -rf $fixdir/*
fi
cd $fixdir
pwd

cres="C$res"
tile_rgnl="7"
nh0="0"
nh4="4"



fns=( "grid.tile7" "mosaic" )
fns=( "${fns[@]/#/${cres}_}" )

num_file_categories=${#fns[@]}
for (( i=0; i<${num_file_categories}; i++ )); do
  for nh in 3 4 6; do
    fn="${fns[$i]}.halo${nh}.nc"
    target="$sourcedir/grid/$fn"
    symlink="$fn"
    if [ -f "$target" ]; then
        echo "$target -> $symlink"
        ln -sf $target $symlink
    else
      printf "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
      exit 1
    fi
  done
done


fns=( \
"oro_data.tile7" \
"oro_data_ls.tile7" \
"oro_data_ss.tile7" \
)

fns=( "${fns[@]/#/${cres}_}" )

num_file_categories=${#fns[@]}
for (( i=0; i<${num_file_categories}; i++ )); do
  for nh in 0 4; do
    fn="${fns[$i]}.halo${nh}.nc"
    target="$sourcedir/orog/$fn"
    symlink="$fn"
    if [ -f "$target" ]; then
        echo "$target -> $symlink"
        ln -sf $target $symlink
    else
      printf "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
      #exit 1
    fi
  done
done


sfc_climo_fields=( \
"facsf" \
"maximum_snow_albedo" \
"slope_type" \
"snowfree_albedo" \
"soil_type" \
"substrate_temperature" \
"vegetation_greenness" \
"vegetation_type" \
)

fns=( "${sfc_climo_fields[@]/#/${cres}.}" )
fns=( "${fns[@]/%/.tile${tile_rgnl}}" )

num_file_categories=${#fns[@]}
for (( i=0; i<${num_file_categories}; i++ )); do
  for nh in 0 4; do
    fn="${fns[$i]}.halo${nh}.nc"
    target="$sourcedir/sfc_climo/$fn"
    symlink="$fn"
    if [ -f "$target" ]; then
        echo "$target -> $symlink"
        ln -sf $target $symlink
    else
      printf "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
      exit 1
    fi
  done
done


fns=( "${sfc_climo_fields[@]/#/${cres}.}" )
fns_tile7_halo4=( "${fns[@]/%/.tile${tile_rgnl}.halo${nh4}.nc}" )
fns_tile7_no_halo=( "${fns[@]/%/.tile${tile_rgnl}.nc}" )

#printf "%s\n" "${fns_tile7_halo4[@]}"
#echo
#printf "%s\n" "${fns_tile7_no_halo[@]}"
#exit

num_files=${#fns[@]}
for (( i=0; i<${num_files}; i++ )); do
  target="${fns_tile7_halo4[$i]}"
  symlink="${fns_tile7_no_halo[$i]}"
  if [ -f "$target" ]; then
      echo "$target -> $symlink"
      ln -sf $target $symlink
  else
    printf "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
    exit 1
  fi
done



fns_tile7_halo0=( "${fns[@]/%/.tile${tile_rgnl}.halo${nh0}.nc}" )
fns_tile1_no_halo=( "${fns[@]/%/.tile1.nc}" )

num_files=${#fns[@]}
for (( i=0; i<${num_files}; i++ )); do
  target="${fns_tile7_halo0[$i]}"
  symlink="${fns_tile1_no_halo[$i]}"
  if [ -f "$target" ]; then
      echo "$target -> $symlink"
      ln -sf $target $symlink
  else
    printf "\
Cannot create symlink because target file (target) does not exist:
  target = \"${target}\""
    exit 1
  fi
done

#
# Modify run-time files
#

cat > model_grid.$eventdt <<EOF
output_grid=${WRTCMP_output_grid}
cen_lat=${ESGgrid_LAT_CTR}
cen_lon=${ESGgrid_LON_CTR}
stdlat1=${WRTCMP_stdlat1}
stdlat2=${WRTCMP_stdlat2}
nx=${WRTCMP_nx}
ny=${WRTCMP_ny}
dx=${WRTCMP_dx}
dy=${WRTCMP_dy}
lat1=${WRTCMP_lat_lwr_left}
lon1=${WRTCMP_lon_lwr_left}
EOF

#echo "Modify target_lat/target_lon in input.nml & input.nml_fcst"
#target_dir="$2/static/FV3LAM/FV3_HRRR"
#for fn in input.nml input.nml_fcst; do
#    sed -i "/target_lat/s/=.*/= $cen_lat/;/target_lon/s/=.*/= $cen_lon/" $target_dir/$fn
#done
#
#echo "Modify WRITE_COMPONENT in model_configure_fcst"
#target_file="$target_dir/model_configure_fcst"
#sed -i "/cen_lat/s/:.*/: $cen_lat/;/cen_lon/s/:.*/: $cen_lon/;/^lat1/s/:.*/: $lat1/;/^lon1/s/:.*/: $lon1/" $target_file

# modify static file in statics/FV3LAM
fixdir="${targetdir}/static/FV3LAM"
cd $fixdir
ln -s ../CHGRES/Fix_sar.$eventdt .

exit 0
