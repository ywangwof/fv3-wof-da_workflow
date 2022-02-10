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
!  dfile          dtype       dplat     dsis                 dval    dthin dsfcalc
   prepbufr       ps          null      ps                   1.0     0     0
   prepbufr       t           null      t                    1.0     0     0
   prepbufr       uv          null      uv                   1.0     0     0
   prepbufr       q           null      q                    1.0     0     0
   prepbufr       spd         null      spd                  1.0     0     0
   prepbufr       dw          null      dw                   1.0     0     0
   prepbufr       sst         null      sst                  1.0     0     0
   prepbufr1       ps          null      ps                   1.0     0     0
   prepbufr1       t           null      t                    1.0     0     0
   prepbufr1       uv          null      uv                   1.0     0     0
   prepbufr1       spd         null      spd                  1.0     0     0
   prepbufr1       dw          null      dw                   1.0     0     0
   prepbufr1       sst         null      sst                  1.0     0     0
   prepbufr2       ps          null      ps                   1.0     0     0
   prepbufr2       t           null      t                    1.0     0     0
   prepbufr2       uv          null      uv                   1.0     0     0
   prepbufr2       spd         null      spd                  1.0     0     0
   prepbufr2       dw          null      dw                   1.0     0     0
   prepbufr2       sst         null      sst                  1.0     0     0
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
   diagnostic_reg=.false.,regional=.true.,
   filled_grid=.false.,half_grid=.true.,netcdf=${bk_if_netcdf},fv3_regional=${bk_core_fv3},
 /
 &BKGERR
   vs=${vs_op}
   hzscl=${hzscl_op}
   bw=0.,fstat=.true.,
 /
 &ANBKGERR
   anisotropic=.false.,an_vs=1.0,ngauss=1,
   an_flen_u=-5.,an_flen_t=3.,an_flen_z=-200.,
   ifilt_ord=2,npass=3,normal=-200,grid_ratio=4.,nord_f2a=4,
/
 &JCOPTS
 /
 &STRONGOPTS
   nstrong=0,nvmodes_keep=20,period_max=3.,
   baldiag_full=.true.,baldiag_inc=.true.,
 /
 &OBSQC
   dfact=0.75,dfact1=3.0,noiqc=.false.,c_varqc=0.02,vadfile='prepbufr',
 /
 &OBS_INPUT
   dmesh(1)=120.0,dmesh(2)=60.0,dmesh(3)=60.0,dmesh(4)=60.0,dmesh(5)=120,
   ext_sonde=.true.,
   time_window_max=0.45,
 /
OBS_INPUT::
!   dfile          dtype       dplat       dsis       dval     dthin   dsfcalc   time_window
    okmeso.mdf      okt          null        okt       1.0      0       0         0.125
    okmeso.mdf      oktd         null        oktd      1.0      0       0         0.125
    okmeso.mdf      okuv         null        okuv      1.0      0       0         0.125
    okmeso.mdf      okps         null        okps      1.0      0       0         0.125
    dbzobs.nc       dbz          null        dbz       1.0      0       0         0.04166666667
    vrobs.nc        rw           null        rw        1.0      0       0         0.11666666667
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
