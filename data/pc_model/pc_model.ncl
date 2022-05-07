;========================================================================
;function string2array can transfer string into array.for instance,
; old_str = "['ACCESS1-0', 'FGOALS-g2']"
; new_arr = string2array(old_str)
; new_arr
;   Number of Dimensions: 1
;   Dimensions and sizes:	[2]
;   Coordinates:
;   (0)	    ACCESS1-0
;   (1)	    FGOALS-g2

undef("string2array")
function string2array(old_str:string)
local del_left,del_right,del_blank,multi_dim_arr,new_arr
begin
    sq = str_get_sq()
    dq = str_get_dq()
    del_sq  = str_sub_str(old_str, sq, "")
    del_dq  = str_sub_str(del_sq, dq, "")
    del_left = str_sub_str(del_dq, "[", "")
    del_right = str_sub_str(del_left, "]", "")
    del_blank = str_sub_str(del_right, " ", "")
    multi_dim_arr = str_split_csv(del_blank, ",", 0)
    new_arr = ndtooned(multi_dim_arr)
    return(new_arr)
end
;========================================================================

;EOF analysis
;
; Creat date: July 24, 2020
; modified date: July 24, 2020 


load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"

begin

;*******************************************************
; Input parameters
;*******************************************************

;-------------------------------------
; General
;-------------------------------------

	analy_strt	= toint(getenv("analyse_start_year"))  		;Start year of analyzing
	analy_endt	= toint(getenv("analyse_end_year"))    		;End year of analyzing

;XXX	rfbeg		= toint(getenv("reference_period_start"))	;Reference period, first year
;XXX	rfend		= toint(getenv("reference_period_end"))		;Reference period, last year

;	obs_file    = string2array(getenv("input_obs_file"))    ;Path of input obs file
;	obs_name	= string2array(getenv("obs_name"))			;Name of observation dataset

	model_file  = string2array(getenv("input_model_file"))  ;Path of input model file
	nmd		    = toint(getenv("model_number"))		        ;How many model datasets to be analyzed
	model_name	= string2array(getenv("model_name"))		;Name of model dataset
;	project		= string2array(getenv("project"))			;CMIP5/CMIP6
;	mip 		= string2array(getenv("mip"))				;Amon/Lmon/Omon...
;	expt 		= string2array(getenv("exp"))				;Experiment of CMIP, such as historicl/piControl/rcp26...
;	ensemble	= string2array(getenv("ensemble"))			;ensemble, such as historicl/piControl/rcp26...
;	grid		= string2array(getenv("grid"))				;grid label, CMIP6 only

	YNoutplot	= getenv("write_plot")				        ;Whether output plots, 1 = true, 0 = false
	outplot_type= getenv("out_plot_type")			        ;Format of plots, such as eps, ps, png, pdf
	YNoutdata	= getenv("write_data")			            ;Whether output data, 1 = true, 0 = false

	work_dir	= getenv("work_dir")			            ;Directory for working (analyzing)
	outdata_dir	= getenv("out_data_dir")			        ;Directory for output data
	outplot_dir	= getenv("out_plot_dir")			        ;Directory for output plots

;-------------------------------------
; Advanced
;-------------------------------------

	YNpolar		= toint(getenv("ynpolar"))			        ;(0-> shown in no polar map, 1-> shown in polar map)
	YNrmvmean	= toint(getenv("ynrmvmean"))			    ;If YNrmvmean = 0, the mean of analyzed field is removed before EOF analysis
	neof		= toint(getenv("neof"))			            ;The number of EOF modes
	jopt		= toint(getenv("jopt"))			            ; using covariance matrix (jopt=0), correlation matrix (jopt=1) in EOF analysis
	pcrit		= toint(getenv("pcrit"))			        ; Percentage of non-missing values in single grid

    input_model_var = getenv("modelvar")                    ;Variable in input model data, usually is psl
    input_model_lat = "lat"                                 ;Latitude variable in input model data
    input_model_lon = "lon"                                 ;Longitude variable in input model data

	latN		= tofloat(getenv("latN"))			        ;Region for EOF analysis, default is global
	latS		= tofloat(getenv("latS"))
	lonW		= tofloat(getenv("lonW"))
	lonE		= tofloat(getenv("lonE"))

;******************************************************************
; parameters for Test
;******************************************************************

;-------------------------------------
; General
;-------------------------------------
;        analy_strt      = 1856           ;Start year of analyzing
;        analy_endt      = 2014             ;End year of analyzing
;;XXX    rfbeg           = 1971       ;Reference period, first year
;;XXX    rfend           = 2000         ;Reference period, last year
;        obs_file    	= "/Users/HJB/Documents/workstation/Data/KaplanSST/1856-2019sst.mon.anom.nc"    ;Path of input obs file
;        obs_name        = "KaplanSST_V2"                      ;Name of observation dataset
;        model_file  	= "/Users/HJB/Documents/workstation/FastSSD/CMIP6/hist/TS/CanESM5/"  ;Path of input model file
;        nmd             = 2                   ;How many model datasets to be analyzed
;        model_name      = new((/nmd/),"string")            ;Name of model dataset
;	    model_name	= "CanESM5"
;;       project         = string2array(getenv("project"))                       ;CMIP5/CMIP6
;        mip             = "Amon"                          ;Amon/Lmon/Omon...
;        expt            = "historical"                           ;Experiment of CMIP, such as historicl/piControl/rcp26...
;;       ensemble        = getenv("ensemble")                      ;ensemble, such as historicl/piControl/rcp26...
;        grid            = "gn"                          ;grid label, CMIP6 only
;        YNoutplot       = 1                                 ;Whether output plots, 1 = true, 0 = false
;        outplot_type	= "eps"                           ;Format of plots, such as eps, ps, png, pdf
;        YNoutdata       = 1                             ;Whether output data, 1 = true, 0 = false
;        work_dir        = "/Users/HJB/Documents/workstation/FastSSD/CMIP6/hist/TS/CanESM5/work/EOF/model"   ;Directory for working (analyzing)
;        outdata_dir     = work_dir                                ;Directory for output data
;        outplot_dir     = work_dir                               ;Directory for output plots
;-------------------------------------
; Advanced
;-------------------------------------
;	YNpolar		= 0			;(0-> shown in no polar map, 1-> shown in polar map)
;	latN		=  90			;Region for EOF analysis
;	latS		=   0
;	lonW		= -180
;	lonE		=  180
;	ica	= 0			;0->annual, 1->seasonal
;	annsea(ica)	= "DJF"			;"DJF"->winter, "MAM"->spring, "JJA"->summer, "SON"->autumn if ica = 1
;	YNrmvmean		= 0			;If YNrmvmean = 0, the mean of analyzed field is removed before EOF analysis
;	neof		= 3			;The number of EOF modes
;	jopt		= 0			;using correlation matrix (jopt=0), covariance matrix (jopt=1) in EOF analysis
;	pcrit		= 50			; Percentage of non-missing values in single grid
;   input_model_var = "ts"		;getenv("modelvar")                                    		;Variable in input model data, usually is psl
;   input_model_lat = "lat"                                                                 ;Latitude variable in input model data
;   input_model_lon = "lon"                                                                 ;Longitude variable in input model data

;******************************************************
;******************************************************
;======================================================
; Print out Information about this program
;======================================================
 
print("The first "+neof+" normalized principal components of EOF analysis")
print("EOF analysis on annual & seasonal "+input_model_var+" in the region: "+latS+"-"+latN+"N, "+lonW+"-"+lonE+"E, considering area-weights") 
print( nmd+" model data in the period of "+analy_strt+"-"+analy_endt+" are used in this analysis: "+model_name)

;*****************************************************
;*****************************************************
; Reading and calculating EOF using each model data
;*****************************************************
;------------------------------------
; Read each model data with a loop
;------------------------------------

  do i	= 1-1,nmd-1

	input_mdfile    = model_file(i)
	print("Current input model file is: "+input_mdfile)

;	input_mdfile	= "ts_"+mip+"_"+model_name(i)+"_"+expt+"_r"+(i+1)+"i1p1f1_"+grid+"_185001-201412.nc"
;   fm	= addfile(model_file+input_mdfile,"r")

	fm	= addfile(input_mdfile,"r")
	modeltime= cd_calendar(fm->time, -5)
	fdmd	= modeltime(0,0)
	fmsst	= lonFlip(fm->$input_model_var$)

	msst	    = fmsst(time|:,{$input_model_lat$|latS:latN},{$input_model_lon$|lonW:lonE})

;=====================================================

	annsea  = (/"annual","DJF","MAM","JJA","SON"/)

 do ica = 1-1, 5-1
;-----------------------------------
; annual or seasonal average
;-----------------------------------

  if(ica.eq.0) then

	ysmsst	= month_to_annual(msst,1)

   else
	ysmsst	= month_to_season(msst,annsea(ica))

   end if

	nmsst	= ysmsst((analy_strt-fdmd):(analy_endt-fdmd),:,:)
	tmpmodel= nmsst

  if(YNrmvmean.eq.0) then
	nmsst	=  dim_rmvmean_n_Wrap(nmsst,0)
   end if

;-----------------------------------
; EOF, calculated with area-weight
;-----------------------------------

	latm	= nmsst&$input_model_lat$
	wgtm	= tofloat(sqrt(cos(latm*0.0174532)))
	nwgtm	= conform(nmsst,wgtm,1)

	nmsst	= nmsst*nwgtm
	copy_VarMeta(tmpmodel,nmsst)	

        opteof          = True
        opteof@jopt     = jopt          ;1->correlation matrix, 0->covariance matrix
        opteof@pcrit    = pcrit            ; default is 50% non-missing values in single grid
        dims            = 0             ; the time dimension

        eof     = eofunc_n_Wrap(nmsst, neof, opteof, dims)
        eof_ts  = eofunc_ts_n_Wrap(nmsst, eof, opteof, dims)

        eof_ts  = dim_standardize_n( eof_ts, 0, 1)

;****************************************************
; Plot
;*****************************************************

	if(ica.eq.0) then
	tname   = "annual"
	else
	tname   = annsea(ica)
	end if

	name	= analy_strt+"-"+analy_endt+"-"+tname+"-PC-"+model_name(i)
	outdata_name    = name
	outplot_name    = name

	plotname	=  outplot_dir+"/"+outplot_name
	print("Output plot save as: "+plotname+"."+outplot_type)

;---------------------------------

 	system("rm -f "+plotname+"."+outplot_type)
	wks   = gsn_open_wks(outplot_type,plotname)
	gsn_define_colormap(wks,"gui_default")

	plot	= new((/neof/),"graphic")
	mthd	= (/"cov","cor"/)


	rts	= True

	rts@gsnDraw              = False        ; don't draw yet
	rts@gsnFrame             = False        ; don't advance frame yet
	rts@gsnYRefLine           = 0.              ; reference line

	rts@vpWidthF		= 0.7
	rts@vpHeightF		= 0.35
	rts@tiYAxisString	= ""

	yrfrac =ispan(analy_strt,analy_endt,1)
	
	do n=0,neof-1
	rts@gsnLeftString       = "PC "+(n+1)+"_"+mthd(jopt)
	rts@gsnLeftStringFontHeightF            = 0.025
	rts@gsnRightString      = sprintf("%5.1f", eof@pcvar(n)) +"%"
	rts@gsnRightStringFontHeightF           = 0.025
	rts@gsnCenterString     = input_model_var+"_"+tname
	rts@gsnCenterStringFontHeightF          = 0.025
;	rts@gsnCenterStringOrthogonalPosF       = 0.03	

	plot(n)	= gsn_csm_xy (wks,yrfrac,eof_ts(n,:),rts)

	end do


;=======================================================

;-------------------------------------------------------

	resP			= True         ; modify the panel plot
	resP@gsnMaximize	= True         ; large format
	resP@txString		= analy_strt+"-"+analy_endt+"_"+model_name(i)
	resP@gsnPanelYWhiteSpacePercent = 3
	resP@txFontHeightF	= 0.013

	gsn_panel(wks,plot,(/neof,1/),resP)

;=========================================================
;=========================================================
;*********************************************************
; Output data with netcdf format
;*********************************************************

 if(YNoutdata.eq.1) then

;--------------------------------------------------------

	oname	= outdata_dir+"/"+outdata_name
	print("Output data save as: "+oname+".nc")

	system("rm -rf "+oname+".nc")

	fo	= addfile(oname+".nc","c")

	fo->eof		= eof
	fo->eof_ts	= eof_ts


fo@comment0 = "The first "+neof+" normalized principal components of EOF analysis"
if(ica.eq.0)
fo@comment1 = "EOF analysis on annual "+input_model_var+" in the region: "+latS+"-"+latN+"N, "+lonW+"-"+lonE+"E, considering area-weights"
else
fo@comment1 = "EOF analysis on "+annsea(ica)+" "+input_model_var+" in the region: "+latS+"-"+latN+"N, "+lonW+"-"+lonE+"E, considering area-weights "
end if
fo@comment2 = nmd+" model data in the period of "+analy_strt+"-"+analy_endt+" are used in this analysis"
fo@comment3 = "models: "+model_name+" "

 end if

;=======================================================
;---------------------------------
 delete([/ysmsst,nmsst,tmpmodel,latm,wgtm,nwgtm,eof,eof_ts/])

print(" ")
print( model_name(i)+"-"+annsea(ica)+" is finished !")
print("*****************************************************")
print(" ")

 end do
;---------------------------------
; Deleting reusable variables in a model loop
;---------------------------------
delete([/fm,fmsst,msst/])

 end do
;---------------------------------

end

exit()