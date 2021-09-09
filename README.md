# fv3-wof-da_workflow
FV3 EnKF workflow in the WoF framework

## Required outside code and programs

static/CHGRES/Fix_sar  
static/FV3LAM/fix_am  
static/FV3LAM/fix_am/fix_co2_proj  
static/FV3LAM/Fix_sar  

exec/CHGRES:  
chgres_cube.exe  

exec/FV3LAM:  
create_expanded_restart_files_for_DA.x  prep_for_regional_DA.x  ufs_weather_model  

exec/GSI:  
comgsi_namelist_all.sh  enkf_wrf_namelist.sh  gen_be_ensmean_ref.x  merge3d.x  
enkf_fv3reg.x           gen_be_ensmean.x      gsi.exe               move_DA_update_data.x  

## Required packages:

GSI_WoF/  
LBC_update/  
ensmean/
ufs-srweather-app/
