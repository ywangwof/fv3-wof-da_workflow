# define namelist for gsi

export comgsi_namelist="

 &SETUP
   miter=${nummiter},niter(1)=10,niter(2)=10,
   write_diag(1)=.true.,write_diag(2)=.false.,write_diag(3)=.true.,
   gencode=78,qoption=1,
   factqmin=0.0,factqmax=0.0,
   iguess=-1,
   oneobtest=.false.,retrieval=.false.,
   nhr_assimilation=3,l_foto=.false.,
   use_pbl=.false.,
   lread_obs_save=${if_read_obs_save},lread_obs_skip=${if_read_obs_skip},
   use_fv3_cloud=.f.,
 /
 &GRIDOPTS
   JCAP=62,JCAP_B=62,NLAT=60,NLON=60,nsig=60,regional=.true.,
   wrf_nmm_regional=${bk_core_nmm},wrf_mass_regional=${bk_core_arw},
   nems_nmmb_regional=${bk_core_nmmb},nmmb_reference_grid='H',diagnostic_reg=.false.,
   filled_grid=.false.,half_grid=.true.,netcdf=${bk_if_netcdf},fv3_regional=${bk_core_fv3},
 /
 &BKGERR
   vs=${vs_op}
   hzscl=${hzscl_op}
   bw=0.,fstat=.true.,
 /
 &ANBKGERR
 /
 &JCOPTS
 /
 &STRONGOPTS
 /
 &OBSQC
   dfact=0.75,dfact1=3.0,noiqc=.false.,c_varqc=0.02,vadfile='prepbufr',
 /
 &OBS_INPUT
   dmesh(1)=120.0,dmesh(2)=60.0,dmesh(3)=30,time_window_max=1.5,
 /
OBS_INPUT::
!  dfile          dtype       dplat     dsis                 dval    dthin dsfcalc    time_window
   prepbufr       ps          null      ps                   1.0     0      0           0.5
   prepbufr       t           null      t                    1.0     0      0           0.5
   prepbufr       uv          null      uv                   1.0     0      0           0.5
   prepbufr       q           null      q                    1.0     0      0           0.5
   prepbufr       spd         null      spd                  1.0     0      0           0.5
   prepbufr       dw          null      dw                   1.0     0      0           0.5
   prepbufr       sst         null      sst                  1.0     0      0           0.5
   prepbufr1       ps          null      ps                   1.0     0     0           0.5
   prepbufr1       t           null      t                    1.0     0     0           0.5
   prepbufr1       uv          null      uv                   1.0     0     0           0.5
   prepbufr1       spd         null      spd                  1.0     0     0           0.5
   prepbufr1       dw          null      dw                   1.0     0     0           0.5
   prepbufr1       sst         null      sst                  1.0     0     0           0.5
   prepbufr2       ps          null      ps                   1.0     0     0           0.5
   prepbufr2       t           null      t                    1.0     0     0           0.5
   prepbufr2       uv          null      uv                   1.0     0     0           0.5
   prepbufr2       spd         null      spd                  1.0     0     0           0.5
   prepbufr2       dw          null      dw                   1.0     0     0           0.5
   prepbufr2       sst         null      sst                  1.0     0     0           0.5
::
 &SUPEROB_RADAR
   del_azimuth=5.,del_elev=.25,del_range=5000.,del_time=.5,elev_angle_max=5.,minnum=50,range_max=100000.,
   l2superob_only=.false.,
 /
 &LAG_DATA
 /
 &HYBRID_ENSEMBLE
   l_hyb_ens=.false.,
 /
 &RAPIDREFRESH_CLDSURF
 /
 &CHEM
 /
 &SINGLEOB_TEST
   maginnov=1.0,magoberr=0.8,oneob_type='t',
   oblat=38.,oblon=279.,obpres=500.,obdattim=${ANAL_TIME},
   obhourset=0.,
 /
 &NST
 /
"

# define namelist for gsi

export comgsi_namelist_radar="

 &SETUP
   miter=${nummiter},niter(1)=10,niter(2)=10,
   write_diag(1)=.true.,write_diag(2)=.false.,write_diag(3)=.true.,
   gencode=78,qoption=2,
   factqmin=0.0,factqmax=0.0,
   iguess=-1,
   oneobtest=.false.,retrieval=.false.,
   nhr_assimilation=3,l_foto=.false.,
   use_pbl=.false.,
   lread_obs_save=${if_read_obs_save},lread_obs_skip=${if_read_obs_skip},
   if_model_dbz=.true., static_gsi_nopcp_dbz=0.0,
   rmesh_dbz=4.0,rmesh_vr=4.0,zmesh_dbz=1000.0,zmesh_vr=1000.0,
   missing_to_nopcp=.true.,diag_radardbz=.t.,
   use_fv3_cloud=.t.,
   !doradaroneob=.true., oneobddiff=20., oneobvalue=-999.,
 /
 &GRIDOPTS
   JCAP=62,JCAP_B=62,NLAT=60,NLON=60,nsig=60,regional=.true.,
   wrf_nmm_regional=${bk_core_nmm},wrf_mass_regional=${bk_core_arw},
   nems_nmmb_regional=${bk_core_nmmb},nmmb_reference_grid='H',diagnostic_reg=.false.,
   filled_grid=.false.,half_grid=.true.,netcdf=${bk_if_netcdf},fv3_regional=${bk_core_fv3},
 /
 &BKGERR
   vs=${vs_op}
   hzscl=${hzscl_op}
   bw=0.,fstat=.true.,
 /
 &ANBKGERR
 /
 &JCOPTS
 /
 &STRONGOPTS
 /
 &OBSQC
   dfact=0.75,dfact1=3.0,noiqc=.false.,c_varqc=0.02,vadfile='prepbufr',
 /
 &OBS_INPUT
   dmesh(1)=120.0,dmesh(2)=60.0,dmesh(3)=30,time_window_max=1.5,ext_sonde=.true.,
 /
OBS_INPUT::
!  dfile          dtype       dplat     dsis                 dval    dthin dsfcalc
   dbzobs.nc      dbz         null        dbz                   1.0      0      0
::
   vr_vol         rw          null        rw                    1.0      0      0
 &SUPEROB_RADAR
   del_azimuth=5.,del_elev=.25,del_range=5000.,del_time=.5,elev_angle_max=5.,minnum=50,range_max=100000.,
   l2superob_only=.false.,
 /
 &LAG_DATA
 /
 &HYBRID_ENSEMBLE
   l_hyb_ens=.false.,
 /
 &RAPIDREFRESH_CLDSURF
 /
 &CHEM
 /
 &SINGLEOB_TEST
   maginnov=1.0,magoberr=0.8,oneob_type='t',
   oblat=38.,oblon=279.,obpres=500.,obdattim=${ANAL_TIME},
   obhourset=0.,
 /
 &NST
 /
"

