#!/bin/bash

set -u

sourcedir="$1"
targetdir="$2"

#grid_name="$1"
res="3337"

cd "${targetdir}/static/CHGRES/Fix_sar"
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

exit 0
