#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma version=3.2
#pragma IgorVersion=7
#pragma moduleName=baselines
#include <Readback ModifyStr>
// Project Updater header
static constant kProjectID=348 // the project node on IgorExchange
static strconstant ksShortTitle="Baselines" // the project short title on IgorExchange
 
// If you have installed or updated Spidergram using the IgorExchange
// Projects Installer (http: www.igorexchange.com/project/Updater) you can
// be notified when new versions of this project are released.

// Written by Tony Withers, https://www.wavemetrics.com/user/tony
// I would be very happy to hear from you if you find this package
// useful, or if you have any suggestions for improvement.

// How to use:

// Must have a spectrum plotted in the top graph window. When you select
// Baselines from the macros menu a baseline control panel is attached to
// the graph. Select spectrum and baseline type from popup menus in the
// control panel. Use the graph marquee tool (click and drag) to select a
// region of the spectrum, then either click within the marquee and
// select "add region to fit", or click the + button in the control panel
// to add a fitting region. Subtract will make copies of the current
// baseline and baseline-subtracted waves in the current data folder. The
// output waves have a _Sub or _BL suffix. Close the panel to clean up
// after fitting.

// The tangent baseline will attempt to find a common tangent to two
// cubic functions. You must have two regions selected for fitting. The
// fit will be successful only if the selected regions can each be fit
// nicely with a cubic function, and if the two cubics have a common
// tangent.

// The line between cursors baseline allows you to position the cursors
// labelled I and J manually.

// The gauss3 and lor3 baselines fit a Gauss1D or lor function with the
// first coefficient set to 0.

// Execute BL_SetRegion(x1, x2, value) with value = 0/1 to remove/add a
// fit region from the command line.

// Note that waves with _sub and _BL suffixes cannot be chosen as data
// waves for baseline fitting.

// A user-defined fit function can be added by editing the last three
// functions in this file.

// Version history

// 3.20  Fixed bug introduced when rtGlobals pragma setting was changed in
//       a previous release
// 3.15  adds compatibility with version 3 of the Updater project
// 3.14  adds missing include statement for Readback ModifyStr
// 3.13  respects the axes on which data wave is plotted
// 3.10  adds lor3
// 3.09  choose which waves to ignore during all-at-once fitting by
//       editing ksIGNORE
// 3.08  restores printing to history of commands for setting mask regions
// 3.07  Record fit coefficients in wave note of output waves, so that
//       user has access to these for further processing
// 3.06  Added headers for Project Updater.
// 3.05  Jan 5 2018 Adds an easy-to-edit user defined fit function - see
//       the last three functions in this file.
// 3.04  11/11/17 Should be backward compatible for Igor 6.
// 3.03  Panel size decreased for compatibility with smaller or lower
//       resolution screens. Some bugs fixed.
// 3.02  bug fix: spline fit was damaged by 'cosmetic' changes in version 3.01.
// 3.01  cosmetic changes
// 3.00  Sep 11 2017. Switch to panel interface. Closing panel should
//       clear baseline waves from graph. Baseline updates as user interacts
//       with controls on panel or changes mask wave. This was a major rewrite,
//       so let me know when you find the bugs.
// 2.20  code cleanup to use waverefs instead of global string variables
// 2.10  Aug 22 2017 cleaned up the 'tangent' baseline for a beta release
// 2.00  1/2/15 made it work for X-Y data; added wave notes to output waves
// 1.50  finally fixed offsets
// 1.22  fixed offset calculation
// 1.21  12/10/09
// 1.20  6/24/08 added line between cursors
// 1.12  6/9/08
// 1.11  9/12/07
// 1.10  7/23/07 added smoothed spline baseline
// 1.00  7/3/07

static constant kSILENT=0 // set kSILENT=1 to prevent some non-error output to history

// list of matchstrings for waves to ignore
// do not include "*_sub" in this list if you want to fit multiple baselines in sequence
static strconstant ksIGNORE="*_sub;*_BL;"
//static strconstant ksIGNORE="*_BL;"

Menu "Analysis"
	Submenu "Packages"
		"Baselines", /Q, baselines#BL_init()
	end
end

Menu "Macros"
	"Baselines", /Q, baselines#BL_init()
end

Menu "GraphMarquee", dynamic
	baselines#BL_MarqueeMenu("-")
	baselines#BL_MarqueeMenu("Add Region to Fit"), /Q, baselines#BL_setMarquee(1)
	baselines#BL_MarqueeMenu("Remove Region From Fit"), /Q, baselines#BL_setMarquee(0)
	baselines#BL_MarqueeMenu("Clear All Fit Regions"), /Q, baselines#BL_SetRegion(-Inf, Inf, 0);SetMarquee 0, 0, 0, 0
End

static function BL_setMarquee(add)
	variable add
	
	string graphStr=BL_getGraph()
	ControlInfo /W=$graphStr+"#BL_panel" popTrace
	string xAxisName=StringByKey("XAXIS", TraceInfo(graphStr,s_value,0))
	GetMarquee /W=$graphStr /K/Z $xAxisName
	if(v_flag==0)
		GetMarquee /W=BaselineBreakout /K/Z $xAxisName
	endif
	if (V_flag)
		variable success=BL_SetRegion(V_left, V_right, add)
		if(kSILENT==0 && success)
			printf "BL_SetRegion(%g, %g, %d)\r", V_left, V_right, add
		endif
		return 1
	endif
	return 0
end

static Function/DF GetDFREF()
	
	DFREF dfr = root:Packages:Baselines
	if (DataFolderRefStatus(dfr) != 1)
		DFREF dfr = CreatePackageFolder()
	endif
	return dfr
end

static function /DF CreatePackageFolder()
	
	NewDataFolder /O root:Packages
	NewDataFolder /O root:Packages:Baselines
	DFREF dfr = root:Packages:Baselines
	return dfr
end
 
static function/S BL_MarqueeMenu(str)
	string str
	
	string graphStr=BL_getGraph()
	if (strlen(graphStr)==0)
		return ""
	endif
	
	if (stringmatch(WinName(0,1),graphStr)==0 && stringmatch(WinName(0,1),"BaselineBreakout")==0)
		return ""
	endif
		
	DFREF dfr=GetDFREF()
	wave /Z /SDFR=dfr w_display, w_mask
	
	if (WaveExists(w_display)==0)
		return ""
	endif
	
	CheckDisplayed /W=$graphStr w_display
	if(V_flag==0) // not initialized
		return ""
	endif
	
	strswitch(str)
		case "Remove Region From Fit":
			if(WaveMax(w_mask)==0)
				return ""
			endif
		case "Clear All Fit Regions":
			if(WaveMax(w_mask)==0)
				return ""
			endif
	endswitch
 	return str
end

static function BL_init()
		
	if(BL_MakePanel())
		BL_ResetPackage() // create fit waves and add to plot
		BL_doFit()
	endif
end

static function BL_MakePanel()
	
	if (strlen(WinList("*",";","WIN:1"))==0)  // no graphs
		DoAlert 0, "Baseline requires a trace plotted in a graph window."
		return 0
	endif

	// make sure the top graph is visible
	string graphStr=WinName(0,1)
	DoWindow /F $graphStr
		
	// clear any package detritus from the last used baseline graph
	BL_clear(1)
	
	// make sure there's space to the left of the graph for the panel
	GetWindow /Z $graphStr wsize
	if (V_left<200)
		#if IgorVersion() >= 7
			MoveWindow /W=$graphStr 200, V_top, -1, -1
		#else
			MoveWindow /W=$graphStr 200, V_top, 200+(V_right-V_left), v_bottom
		#endif
	endif

	// make panel
	NewPanel /K=1/N=BL_panel/W=(200,0,0,270)/HOST=$graphStr/EXT=1 as "Baseline Controls"
	ModifyPanel /W=$graphStr#BL_panel, noEdit=1
	
	if(strlen(baselines#BL_traces())==0)
		DoAlert 0, "no eligible traces for baseline fitting plotted in top graph - check wave names"
		KillWindow $graphStr+"#BL_panel"
		return 0
	endif
	
	variable i=0, deltaY=25, vL=30, vT=5, font=12, groupw=180
	
	GroupBox group0,pos={vL-20,vT+deltaY*i},size={groupw,deltaY*2},title="Data wave"
	GroupBox group0,fSize=font
	i+=1
	// store values internally in these controls
	PopupMenu popTrace, mode=1, Value=baselines#BL_traces(), title="",pos={vL,vT+deltaY*i},size={130,20}
	PopupMenu popTrace, help={"select data wave" }, proc=baselines#BL_popup
	i+=1.5
	GroupBox group1,pos={vL-20,vT+deltaY*i},size={groupw,deltaY*2},title="Baseline type"
	GroupBox group1,fSize=font
	i+=1
	string fNames="\"line;poly 3;poly 4;gauss;gauss3;lor;lor3;exp;dblexp;sin;hillequation;sigmoid;power;lognormal;"
	fNames+="spline;line between cursors;tangent;"
	fNames+=UserFitName()+"\""
	PopupMenu popBL, mode=1, title="",pos={vL,vT+deltaY*i},size={130,20}, Value=#fNames
	PopupMenu popBL, help={"select baseline type" }, proc=baselines#BL_popup, fSize=font
	
	SetVariable setvarSmooth,pos={vL+30,vT+deltaY*i},size={100,16},title=""
	SetVariable setvarSmooth,limits={1e-5,100,0.01},value=_NUM:0.1, bodyWidth=60
	SetVariable setvarSmooth,help={"spline smoothing factor"}, fSize=font, proc=baselines#BL_SetVar
	SetVariable setvarSmooth,disable=1
	i+=1.5
	GroupBox group2,pos={vL-20,vT+deltaY*i},size={groupw,deltaY*2.5},title="Fit regions"
	GroupBox group2, fSize=font
	i+=1
	Button BL_reset,pos={vL-5,vT+deltaY*i+5},size={60,20},title="Clear all", proc=baselines#BL_button
	Button BL_reset,help={"Clear all fit regions"}, fSize=font
	Button BL_add,pos={vL+70,vT+deltaY*i},size={30,30},title="+", proc=baselines#BL_button
	Button BL_add,help={"Remove marquee to fit region"}, fSize=font
	Button BL_remove,pos={vL+115,vT+deltaY*i},size={30,30},title="-", proc=baselines#BL_button
	Button BL_remove,help={"Remove marquee from fit region"}, fSize=font
	i+=2
	Button BL_sub,pos={60,vT+deltaY*i},size={70,20},title="Subtract", proc=baselines#BL_button
	Button BL_sub,help={"Subtract baseline"}, fSize=font
	i+=1
	Button BL_all,pos={60,vT+deltaY*i},size={70,20},title="All in one", proc=baselines#BL_button
	Button BL_all,help={"Subtract baseline from all traces"}, fSize=font
	
	return 1
end

// experimental development...
static function BL_breakOut()
		
	string graphStr=BL_getGraph()
	string traceStr=BL_getTrace(graphStr)
	
	KillWindow /Z BaselineBreakout
	string rec=WinRecreation(graphStr, 0)
	rec=ReplaceString("Display", rec, "Display /K=1", 1, 1)
	variable i=strsearch(rec, "NewPanel", 0)
	if(i>0)
		rec[i,strlen(rec)-1]=""
	endif
	if(strlen(rec)==0)
		return 0
	endif
	Execute /Q rec
	RenameWindow $(WinName(0, 1)), BaselineBreakout
	
	GetWindow /Z BaselineBreakout hook(BL_CsrHook)
	if(strlen(S_Value))
		SetWindow BaselineBreakout hook(BL_CsrHook)=baselines#BL_BreakoutCsrHook
	endif
	string xAxisName=StringByKey("XAXIS", TraceInfo("BaselineBreakout",traceStr,0))
	GetAxis /Q/W=BaselineBreakout $xAxisName
	if(V_min>V_max)
		SetAxis /W=BaselineBreakout /A/R/Z $xAxisName
	else
		SetAxis /W=BaselineBreakout /A/Z $xAxisName
	endif
	string toRemove=TraceNameList("BaselineBreakout", ",", 1)
	string toKeep=traceStr+",w_sub,w_base,w_display"
	toRemove=RemoveFromList(toKeep, toRemove, ",")
	Execute "RemoveFromGraph /W=BaselineBreakout/Z " + RemoveEnding(toRemove, ",")
end

// create fit waves and add to plot
static function BL_ResetPackage()
	
	string graphStr=BL_getGraph()
	RemoveFromGraph /W=$graphStr /Z w_display, w_base, w_sub, tangent0, tangent1
	string traceStr=BL_getTrace(graphStr)
	wave /Z w=TraceNameToWaveRef(graphStr, traceStr)
	if (WaveExists(w)==0)
		return 0
	endif
	wave /Z w_x=XWaveRefFromTrace(graphStr, traceStr)
	
	DFREF dfr=GetDFREF()
	
	Duplicate /O w dfr:w_display /WAVE=w_display
	
	// don't reset the mask wave if new data wave has same length as previous one
	// in case we want to apply the same fit to many spectra
	wave /Z w_mask=dfr:w_mask
	if (WaveExists(w_mask))
		if (numpnts(w_mask)!=numpnts(w_display))
			Duplicate /O w dfr:w_mask
			w_mask=0
			w_display=NaN
		endif
	else
		Duplicate /O w dfr:w_mask
		wave w_mask=dfr:w_mask
		w_mask=0
	endif
	
	// display the masked regions
	w_display = w_mask[p] ? Inf : NaN
	BL_appendToSameAxes(graphStr, traceStr, w_display, w_x, w_RGB={54693,56967,65535})
	ModifyGraph /W=$graphStr mode(w_display)=7,hbFill(w_display)=4
	ModifyGraph /W=$graphStr axisOnTop=1
	string firstTraceStr=StringFromList(0, TraceNameList(graphStr,";",5))
	ReorderTraces /W=$graphStr $firstTraceStr, {w_display}
	ModifyGraph  /W=$graphStr offset(w_display)={0,-1e9}
	
	// plot the baseline...
	Duplicate /O w  dfr:w_base /WAVE=w_base
	w_base=NaN
	BL_appendToSameAxes(graphStr, traceStr, w_base, w_x, offset=1)
	
	// ... and the baseline-subtracted result
	Duplicate /O w  dfr:w_sub /WAVE=w_sub
	w_sub=NaN
	BL_appendToSameAxes(graphStr, traceStr, w_sub, w_x)
	
	// prevent y-axis from autoscaling while fitting
	string yAxisName= StringByKey("YAXIS", TraceInfo(graphStr,traceStr,0))
	GetAxis /W=$graphStr /Q $yAxisName
	SetAxis /W=$graphStr /Z $yAxisName, V_min, V_max
end

// ------------ control action procedures --------------------

static function BL_popup(s)
	STRUCT WMPopupAction &s
	
	if (s.eventCode==-1)
		return 0
	endif
	
	string graphStr=ParseFilePath(0, s.win, "#", 0, 0)
	//string panelStr=graphStr+"#BL_panel"
	ControlInfo /W=$s.win popTrace
	string traceStr=s_value
			
	if(stringmatch(s.ctrlName,"popTrace"))
		BL_ResetPackage()
		ControlInfo /W=$s.win popBL
		// force an update of baseline
		ControlInfo /W=$s.win popBL
		s.ctrlName="popBL"
		s.popStr=s_value
		KillWindow /Z BaselineBreakout
	endif
	
	if(stringmatch(s.ctrlName,"popBL"))
		if(strlen(traceStr)==0 || stringmatch(traceStr, "_none_"))
			return 0
		endif
		
		// enable smooth setvar for spline baseline
		SetVariable setvarSmooth, Win=$s.win, disable=1-stringmatch(s.popStr,"spline")
		
		if(stringmatch(s.popStr,"line between cursors"))
			
			wave /Z w=TraceNameToWaveRef(graphStr, traceStr)
			if (WaveExists(w)==0)
				return 0
			endif
			wave /Z w_x=XWaveRefFromTrace(graphStr, traceStr)
			
			// put cursors on graph
			variable Xval, Yval
			string xAxisName= StringByKey("XAXIS", TraceInfo(graphStr,traceStr,0))
			string yAxisName= StringByKey("YAXIS", TraceInfo(graphStr,traceStr,0))
			
			GetAxis /W=$graphStr /Q $yAxisName
			SetAxis $yAxisName, V_min, V_max
			Yval=V_min+(V_max-V_min)/2
			GetAxis /W=$graphStr /Q $xAxisName
			Xval=V_min+(V_max-V_min)*.1
			if (WaveExists(w_x)==0)
				Yval=WaveMin(w, V_min, Xval)+BL_getYoffset(graphStr, traceStr)
			endif
			Cursor /F /W=$graphStr /N=1 I $traceStr Xval, Yval
			Xval=V_min+(V_max-V_min)*.9
			if (WaveExists(w_x)==0)
				Yval=WaveMin(w, Xval, V_max)+BL_getYoffset(graphStr, traceStr)
			endif
			
			// set the hook before placing second cursor on graph
			SetWindow $graphStr hook(BL_CsrHook)=baselines#BL_CsrLineHook
			Cursor /F /W=$graphStr /N=1 J $traceStr Xval, Yval
		else
			Cursor /K /W=$graphStr I
			Cursor /K /W=$graphStr J
			SetWindow $graphStr  hook(BL_CsrHook)=$""
		endif
		
		if(stringmatch(s.popStr,"tangent"))
			DFREF dfr=GetDFREF()
			Make /o/n=0 dfr:tangent0 /WAVE=tangent0, dfr:tangent1 /WAVE=tangent1
			
			// make sure the zero-point waves won't plot outside x-axis
			// range before appending to graph
			GetAxis /W=$graphStr /Q $(StringByKey("XAXIS", TraceInfo(graphStr,traceStr,0)))
			SetScale /P x, V_min, 1, tangent0, tangent1
					
			BL_appendToSameAxes(graphStr, traceStr, tangent0, $"", offset=1)
			BL_appendToSameAxes(graphStr, traceStr, tangent1, $"", offset=1)
			// preserve Y offsets; X offsets will lead only to trouble
		else
			RemoveFromGraph /Z /W=$graphStr tangent0, tangent1
		endif
	endif
	
	BL_DoFit()
end

static function BL_SetVar(s) : SetVariableControl
	STRUCT WMSetVariableAction &s
	
	if (s.eventCode==-1)
		BL_clear(0)
		return 0
	endif
	
	if(stringmatch(s.ctrlName,"setvarSmooth"))
		// reset increment value to 10% of current value
		SetVariable  setvarSmooth win=$s.win,limits={1e-5,Inf,abs(s.dval/10)}
	endif
	BL_doFit()
	
	return 0
end

static function BL_button(s)
	STRUCT WMButtonAction &s
		
	if(s.eventCode!=2)
		return 0
	endif
	
	string graphStr=ParseFilePath(0, s.win, "#", 0, 0)
			
	strswitch(s.ctrlName)
		case "BL_sub":
			BL_subtract(0)
			break
		case "BL_all":
			string msg="subtract baseline from all traces using current settings?\r"
			msg+="existing baselines will be overwritten!"
			DoAlert 1, msg
			if(v_flag==2)
				return 0
			endif
			ControlInfo /W=$graphStr+"#BL_panel" popTrace
			variable savMode=v_value
			string listStr=baselines#BL_traces()
			variable i
			for(i=0;i<ItemsInList(listStr); i+=1)
				PopupMenu popTrace, win=$s.win, mode=i+1
				if (BL_doFit())
					BL_subtract(1)
				else
					Print "Baselines all in one failed to fit "+StringFromList(i, listStr)
				endif
			endfor
			PopupMenu popTrace, win=$s.win, mode=savMode
			// return to spectrum for which we initialized
			BL_doFit()
			break
		case "BL_reset":
			BL_SetRegion(-Inf, Inf, 0)
			break
		default: // add or remove fit region
			variable add = stringmatch(	s.ctrlName, "BL_add") ? 1 : 0
			if(BL_setMarquee(add)==0)
				DoAlert 0, "first use marquee to select region on graph"
			endif
	endswitch

	return 0
end

static function BL_getYoffset(graphStr, traceStr)
	string graphStr, traceStr
	
	variable OffsetX=0,OffsetY=0
	string infostr=TraceInfo(graphStr, traceStr, 0 )
	infostr = GrepList(infostr, "offset", 0,";")
	infostr=StringFromList(0, infostr,";")
	sscanf infostr, "offset(x)={%g,%g}", OffsetX,OffsetY
	return OffsetY
end

static function /s BL_traces()
	
	string graphStr=BL_getGraph()
	string listStr=TraceNameList(graphStr,";",1+4)
	string removeStr="w_display;w_base;w_sub;tangent0;tangent1;"

	variable i
	for(i=0;i<ItemsInList(ksIGNORE);i+=1)
		removeStr+=ListMatch(listStr, StringFromList(i, ksIGNORE))
	endfor

	listStr=RemoveFromList(removeStr, listStr, ";", 0)
	return listStr
end

// set region between x1 and x2 to value
// value = 1 to include, 0 to exclude.
function BL_SetRegion(x1, x2, value)
	variable x1, x2, value
	
	DFREF dfr=GetDFREF()
	wave /Z /SDFR=dfr w_mask, w_display

	if (WaveExists(w_mask)==0)
		return 0
	endif
	
	string graphStr=BL_getGraph()
	string traceStr=BL_getTrace(graphStr)
	wave /Z w_data=TraceNameToWaveRef(graphStr, traceStr)
	wave /Z w_x=XWaveRefFromTrace(graphStr, traceStr)
	if(WaveExists(w_data)==0)
		return 0
	endif
	
	variable pLow, pHigh, pLeft, pRight
	
	if (WaveExists(w_x))
		variable xmax=WaveMax(w_x)
		variable xmin=WaveMin(w_x)
		x1=min(x1,xmax)
		x1=max(x1,xmin)
		x2=min(x2,xmax)
		x2=max(x2,xmin)
		
		FindLevel /Q/P w_x, x1
		if (v_flag)
			Print "baseline error: problem with findlevel"
			return 0
		endif
		pLeft=V_LevelX
		FindLevel /Q/P w_x, x2
		if (v_flag)
			Print "baseline error: problem with findlevel"
			return 0
		endif
		pRight=V_LevelX
		
		pLow=min(pLeft, pRight)
		pHigh=max(pLeft, pRight)
	else
		pLow=min(x2pnt(w_data,x1), x2pnt(w_data,x2))
		pHigh=max(x2pnt(w_data,x1), x2pnt(w_data,x2))
		pLow=max(0,pLow)
		pLow=min(numpnts(w_data)-1,pLow)
		pHigh=min(numpnts(w_data)-1,pHigh)
		pHigh=max(0,pHigh)
	endif
	if(pLow==pHigh)
		return 0
	endif
	w_mask[pLow, pHigh]=value
	w_display = w_mask[p] ? Inf : NaN
	
	BL_doFit()
	return 1
end

// clear baseline paraphernalia from graph
static function BL_clear(killPanel)
	variable killPanel
	
	string graphStr=BL_getGraph()
	if (strlen(graphStr)==0)
		return 0
	endif
	
	DFREF dfr=GetDFREF()
	wave /Z /SDFR=dfr w_display, w_base, w_sub, tangent0, tangent1
	
	do // remove all instances of w_display
		RemoveFromGraph /W=$graphStr/Z w_display
		CheckDisplayed /W=$graphStr w_display
	while (V_flag) // should be okay.
	// if somehow our package waves were displayed with different tracenames
	// that would be a problem.
	do // remove all instances of w_base
		RemoveFromGraph /W=$graphStr/Z w_base
		CheckDisplayed /W=$graphStr w_base
	while (V_flag)
	do // remove all instances of w_sub
		RemoveFromGraph /W=$graphStr/Z w_sub
		CheckDisplayed /W=$graphStr w_sub
	while (V_flag)
	do // remove all instances of tangent waves
		RemoveFromGraph /W=$graphStr /Z tangent0, tangent1
		CheckDisplayed /W=$graphStr tangent0, tangent1
	while (V_flag)
	// remove hook in case we were fitting to cursors
	SetWindow $graphStr  hook(BL_CsrHook)=$""
	Cursor /K /W=$graphStr I
	Cursor /K /W=$graphStr J
	
	if (killPanel)
		KillWindow $graphStr+"#BL_panel"
	endif
	KillWindow /Z BaselineBreakout
end

// subtract current baseline from w_data
static function BL_Subtract(overwrite)
	variable overwrite
	
	DFREF dfr=GetDFREF()
	
	string graphStr=BL_getGraph()
	string traceStr=BL_getTrace(graphStr)
	wave /Z w_data=TraceNameToWaveRef(graphStr, traceStr)
	if (WaveExists(w_data)==0)
		return 0
	endif
	wave /Z w_x=XWaveRefFromTrace(graphStr, traceStr)
	
	wave w_base=dfr:w_base
	if(numpnts(w_base)!=numpnts(w_data))
		if (overwrite)
			Print NameOfWave(w_data) +" and baseline have different length"
		else
			DoAlert 0, NameOfWave(w_data) +" and baseline have different length"
		endif
		return 0
	endif
	
	WaveStats /Q/M=1 w_base
	if (V_npnts==0)
		return 0
	endif
	
	// save a copy of the baseline
	string strNewName=CleanupName( NameOfWave(w_data)+"_BL",0)
	if (overwrite==0 && exists(strNewName))
		DoAlert 1, strNewName+" exists. Overwrite?"
		if(V_flag==2)
			return 0
		endif
	endif
	Duplicate /o w_base $strNewName
	wave newbase= $strNewName
	newbase=w_base
	
	// subtract baseline
	strNewName=CleanupName(NameOfWave(w_data)+"_sub",0)
	if (overwrite==0 && exists(strNewName))
		DoAlert 1, strNewName+" exists. Overwrite?"
		if(V_flag==2)
			return 0
		endif
	endif
	Duplicate /o w_data $strNewName
	wave subtracted= $strNewName
	subtracted=w_data-w_base
	 
	// append note from baseline wave to output wave note
	string noteStr=note(w_base)
	noteStr+="data="+NameOfWave(w_data)+";output="+NameOfWave(subtracted)+","+NameOfWave(newbase)+";"
	if (WaveExists(w_x))
		noteStr+="xwave="+NameOfWave(w_x)+";"
	endif
	noteStr+="\r"
	note/K subtracted, noteStr
	if(kSILENT==0)
		printf noteStr[strsearch(noteStr, "Baseline Parameters",0), strlen(noteStr)-1]
	endif
		
	if (WaveExists(w_x))
		noteStr=note(subtracted)
		noteStr=ReplaceStringByKey("Xwave", noteStr, NameOfWave(w_x), ":", "\r")
		note /K subtracted, noteStr
		noteStr=note(newbase)
		noteStr=ReplaceStringByKey("Xwave", noteStr, NameOfWave(w_x), ":", "\r")
		note /K newbase, noteStr
	endif
	
	BL_appendToSameAxes(graphStr, traceStr, subtracted, w_x, w_rgb={0,0,0})
end

// BL_DoFit() is called to update fit for all baseline types other than
// line between cursors
static function BL_DoFit()
	
	string graphStr=BL_getGraph()
	string panelStr=graphStr+"#BL_panel"
	ControlInfo /W=$panelStr popBL
	if (V_Flag==0)
		return 0
	endif
	string type=s_value
	
	DFREF dfr=GetDFREF()
	wave /Z /SDFR=dfr w_base,w_display,w_mask,w_sub
	
	ControlInfo /W=$panelStr popTrace
	wave /Z w_data=TraceNameToWaveRef(graphStr, s_value)
	wave /Z w_x=XWaveRefFromTrace(graphStr, s_value)
	
	if (WaveExists(w_data)==0 && WaveExists(w_base))
		w_base=NaN; w_sub=NaN
		return 0
	endif
	
	if (numpnts(w_data)!=numpnts(w_mask))
		return 0
	endif
	
	if(stringmatch(type, "line between cursors"))
		return 1 // fit will be updated when cursors move
	endif
	
	if (WaveMin(w_mask)==0 && WaveMax(w_mask)==0) // no region to fit
		w_base=NaN
		w_sub=NaN
		return 0
	endif
	
	string logStr="Baseline Parameters\r"
	logStr+="type="+type+";"
	string rangeStr=""
	
	// treat spline and tangent as special cases,
	// otherwise use CurveFit to fit selected function
	if (stringmatch(type, "spline"))
		
		w_display = w_mask[p] ? w_data : NaN
		
		ControlInfo /W=$panelStr setVarSmooth
		variable smoothVar=V_Value
		
		if (WaveExists(w_x))
			Duplicate /o w_x dfr:w_splineX /WAVE=w_splineX
			Interpolate2/T=3/I=3/F=(smoothVar)/X=w_splineX/Y=w_base w_x, w_display
		else
			Interpolate2/T=3/I=3/F=(smoothVar)/Y=dfr:w_base dfr:w_display
		endif
		w_display = w_mask[p] ? Inf : NaN
		sprintf logStr, "%ssmoothing=%g;", logStr,smoothVar
		
	elseif(stringmatch(type, "tangent"))
		// make sure we have two regions to fit
		FindLevels /Q/EDGE=1/P w_mask, 1
		if(V_LevelsFound+(w_mask[0]==1)!=2)
			//doalert 0, "Select two fit regions for tangent fitting"
			w_base=NaN
			w_sub=NaN
			return 0
		endif
		
		// find the points at edges of fit regions
		Make /free/n=4 w_limits, w_xrange
		
		variable pnt=0,j=0
		do
			if(pnt==0&&w_mask[pnt]==1)
				w_limits[j]=pnt
				j+=1
			elseif(pnt==numpnts(w_mask)-1 && w_mask[pnt]==1)
				w_limits[j]=pnt
				j+=1
			elseif(pnt>0 && w_mask[pnt]!=w_mask[pnt-1])
				w_limits[j]=pnt-w_mask[pnt-1]
				j+=1
			endif
			pnt+=1
		while(j<4 && pnt<numpnts(w_mask))
		if (j<3)
			w_base=NaN
			w_sub=NaN
			return 0
		endif

		Sort w_limits, w_limits
		w_xrange = (WaveExists(w_x)) ? w_x[w_limits] : pnt2x(w_data,w_limits)
		
		Make /D /free/n=9 w_9coef=0
		Make /o /n=200 dfr:tangent0 /WAVE=tangent0
		Make /o /n=200 dfr:tangent1 /WAVE=tangent1
		SetScale /i x, w_xrange[0], w_xrange[1], tangent0
		SetScale /i x, w_xrange[2], w_xrange[3], tangent1
		
		variable V_FitError=0
		CurveFit /Q  poly 4,  w_data[w_limits[0],w_limits[1]] /X=w_x /NWOK
		
		wave w_coef=w_coef
		tangent0=poly(w_coef,x)
		w_9coef[0,3]=w_coef
		
		V_FitError=0
		CurveFit /Q  poly 4,  w_data[w_limits[2],w_limits[3]] /X=w_x /NWOK
		
		w_9coef[4,7]=w_coef[p-4]
		tangent1=poly(w_coef,x)
		
		// switch limits to x values
		w_limits = WaveExists(w_x) ? w_x[w_limits] : pnt2x(w_mask, w_limits)
		
		// pass the mid position of second poly to function
		// to help choose the correct root
		w_9coef[8]=(w_limits[2]+w_limits[3])/2
		
		Make /free/n=300 w_temp
		SetScale /i x, w_limits[0], w_limits[1], w_temp
		w_temp=abs(BL_TangentDistance(w_9coef, x))
		WaveStats /Q w_temp
				
		variable delta=abs(w_limits[1]-w_limits[0])/150
		FindRoots /H=(V_minloc+delta) /L=(V_minloc-delta) /Q baselines#BL_TangentDistance, w_9coef
		if (V_flag)
			w_base=NaN; w_sub=NaN
			return 0
		endif
				
		variable grad=w_9coef[1]+2*w_9coef[2]*V_Root+3*w_9coef[3]*V_Root^2
		variable intercept=w_9coef[0]+w_9coef[1]*V_Root+w_9coef[2]*V_Root^2+w_9coef[3]*V_Root^3-grad*V_Root
		
		variable x1,y1,x2,y2
		x1=V_root
		y1=intercept+grad*x1
			
		// figure out second tangent point
		variable a,b,c, root1, root2
		a=3*w_9coef[7]
		b=2*w_9coef[6]
		c=w_9coef[5]-grad
		
		root1=(-b+sqrt(b^2-4*a*c))/(2*a)
		root2=(-b-sqrt(b^2-4*a*c))/(2*a)
	
		// choose root closest to midpoint of x range
		x2 = (abs(root1-w_9coef[8])<abs(root2-w_9coef[8])) ? root1 : root2
		y2 = intercept+grad*x2
					
		w_base = WaveExists(w_x) ? intercept + grad*w_x[p] : intercept + grad*x
		
		// create a coefficent wave for this fit in case user wants access for further processing
		w_coef={intercept, grad}
		sprintf logStr, "%sw_coef={%g,%g};contact points=(%g,%g),(%g,%g);", logStr, intercept, grad, x1, y1, x2, y2
		
	else // not one of the 'special case' baselines
		variable success=BL_FitWrap(w_data, w_x, w_mask, w_base, type)
		logStr+=note(w_base)
	endif
	
	// figure out ranges used for fitting from mask wave
	variable i, xVal, used=0
	wave w_mask=dfr:w_mask
	for(i=0;i<numpnts(w_mask); i+=1)
		if(w_mask[i]!=used)
			used=1-used
			if(used) // started to include
				xVal = (WaveExists(w_x)) ? w_x[i] : pnt2x(w_mask, i)
				sprintf rangeStr, "%s[%g", rangeStr, xVal
			else // stopped including
				xVal = (WaveExists(w_x)) ? w_x[i] : pnt2x(w_mask, i-1)
				sprintf rangeStr, "%s,%g],", rangeStr, xVal
			endif
		elseif( (i==numpnts(w_mask)-1) && used)
			xVal = (WaveExists(w_x)) ? w_x[i] : pnt2x(w_mask, i)
			sprintf rangeStr, "%s,%g]", rangeStr, xVal
		endif
	endfor
	rangeStr=RemoveEnding(rangeStr, ",")
	logStr+="range="+rangeStr+";"
	
	w_sub=w_data-w_base
	
	// update note in w_base so that it's copied to output wave by SubtractBaseline()
	string noteStr=note(w_data)
	noteStr=RemoveEnding(noteStr, "\r")
	if (strlen(noteStr))
		noteStr+="\r"
	endif
	noteStr+=logStr
	note /K w_base noteStr
	// the format of the note follows style of Bruker FTIR file header
	// not easily interrogated with StringByKey, unfortunately
	
	return 1
end

// for finding tangent to two 3rd degree polynomials
static function BL_TangentDistance(w, x)
	wave w
	variable x
	
	// first poly 4 is y=w[0]+w[1]*x+w[2]*x^2+w[3]*x^3
	// second poly 4 is y=w[4]+w[5]*x+w[6]*x^2+w[7]*x^3
	// w[8] is midpoint of x range for second poly
	
	// find gradiant of tangent at position x on first poly
	variable grad=w[1]+2*w[2]*x+3*w[3]*x^2
	variable intercept=w[0]+w[1]*x+w[2]*x^2+w[3]*x^3-grad*x
	
	// find distance from tangent to second poly
	// start by finding tangent to second poly with gradient == grad
		
	variable a, b, c, root1, root2
	
	// gradient of second poly is w[5]+2*w[6]*x+3*w[7]*x^2
	// so 3*w[7]*x^2 + 2*w[6]*x + w[5]-grad = 0
	
	a=3*w[7]
	b=2*w[6]
	c=w[5]-grad
	
	root1=(-b+sqrt(b^2-4*a*c))/(2*a)
	root2=(-b-sqrt(b^2-4*a*c))/(2*a)
	
	variable x0, y0
	
	// choose root closest to midpoint of x range
	x0 = (abs(root1-w[8])<abs(root2-w[8])) ? root1 : root2
	y0 = w[4]+w[5]*x0+w[6]*x0^2+w[7]*x0^3
	
	// distance to tangent
	return (intercept + grad*x0 - y0)/sqrt(1+grad^2)
	
end

// ------------------- hook functions ---------------

// BL_CsrLineHook() updates baseline and BL_sub waves whenever a cursor
// is repositioned
static function BL_CsrLineHook(s)
	STRUCT WMWinHookStruct &s
	
	if (s.eventcode!=7)
		return 0
	endif
	
	string traceStr=BL_getTrace(s.WinName)
	wave /Z w_data=TraceNameToWaveRef(s.WinName, traceStr)
	wave /Z w_x=XWaveRefFromTrace(s.WinName, traceStr)
	if (WaveExists(w_data)==0)
		return 0
	endif
	
	DFREF dfr=GetDFREF()
	wave /SDFR=dfr w_base,w_sub
	variable x1=hcsr(I), x2=hcsr(J), y1=vcsr(I), y2=vcsr(J)
	variable gradient=(y2-y1)/(x2-x1)
	variable intercept=y1+(0-x1)*gradient
	
	w_base =	(WaveExists(w_x)) ? intercept+gradient*(w_x[p]) : intercept+gradient*x
	
	// figure out vertical offset
	variable DataOffsetY=BL_getYoffset(s.WinName, traceStr)
	w_base-=DataOffsetY
	
	w_sub=w_data-w_base
	
	// create a coefficent wave for this fit in case user wants access for further processing
	Make /D/O w_coef={intercept, gradient}
		
	string logStr="Baseline Parameters\r"
	sprintf logStr "%stype=line between cursors;w_coef={%g,%g};coordinates=(%g,%g),(%g,%g);", logStr, intercept, gradient, x1, y1, x2, y2
	// update note in w_base so that it's copied to output wave by SubtractBaseline()
	string noteStr=note(w_data)
	noteStr=RemoveEnding(noteStr, "\r")
	if (strlen(noteStr))
		noteStr+="\r"
	endif
	noteStr+=logStr
	note /K w_base noteStr
	
	return 1
end


static function BL_BreakoutCsrHook(s)
	STRUCT WMWinHookStruct &s
	
	if (s.eventcode!=7)
		return 0
	endif
	
	if(FindListItem(s.cursorName, "I;J;")==-1)
		return 0
	endif
	
	string graphStr=BL_getGraph()
	string traceStr=BL_getTrace(graphStr)
	variable horiz=hcsr($s.cursorName, "BaselineBreakout")
	variable vert=vcsr($s.cursorName, "BaselineBreakout")
	Cursor /W=$graphStr/F $s.cursorName $traceStr horiz, vert
	return 1
end

// -----------------------------------------------------------------------

static function BL_FitWrap(w, w_x, w_mask, w_out, fName)
	wave /Z w, w_x, w_mask, w_out
	string fName
	
	DebuggerOptions
	variable sav_debug=V_debugOnError
	DebuggerOptions debugOnError=0 // switch this off in case the fit fails
	
	variable V_FitError=0, V_fitOptions=4
	try
		strswitch (fName)
			case "line":
				CurveFit /Q/N line, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				w_out = WaveExists(w_x) ? w_coef[0]+w_coef[1]*w_x : w_coef[0]+w_coef[1]*x
				break
			case "poly 3":
				CurveFit /Q/N poly 3, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				w_out = WaveExists(w_x) ? poly(w_coef,w_x) : poly(w_coef,x)
				break
			case "poly 4":
				CurveFit /Q/N poly 4, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				w_out = WaveExists(w_x) ? poly(w_coef,w_x) : poly(w_coef,x)
				break
			case "gauss":
				CurveFit /Q/N Gauss, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				w_out = WaveExists(w_x) ? Gauss1D(w_coef,w_x) : Gauss1D(w_coef,x)
				break
			case "gauss3":
				// first fit a Gaussian to populate w_coef
				CurveFit /Q/N Gauss, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				w_coef[0]=0
				CurveFit /Q/N /H="1000" Gauss, kwCWave=w_coef, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				w_out = WaveExists(w_x) ? Gauss1D(w_coef,w_x) : Gauss1D(w_coef,x)
				break
			case "lor":
				CurveFit /Q/N lor, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				wave w=w_coef
				w_out = WaveExists(w_x) ? w[0]+w[1]/((w_x-w[2])^2+w[3]) : w[0]+w[1]/((x-w[2])^2+w[3])
				break
			case "lor3":
				// first fit a Lorentzian to populate w_coef
				CurveFit /Q/N lor, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				wave w=w_coef
				w_coef[0]=0
				CurveFit /Q/N /H="1000" lor, kwCWave=w_coef, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				w_out = WaveExists(w_x) ? w[1]/((w_x-w[2])^2+w[3]) : w[1]/((x-w[2])^2+w[3])
				break
			case "exp":
				CurveFit /Q/N exp, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				w_out = WaveExists(w_x) ? w_coef[0]+w_coef[1]*exp(-w_coef[2]*w_x) : w_coef[0]+w_coef[1]*exp(-w_coef[2]*x)
				break
			case "dblexp":
				CurveFit /Q/N dblexp, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				wave w=w_coef
				w_out = WaveExists(w_x) ? w[0]+w[1]*exp(-w[2]*w_x)+w[3]*exp(-w[4]*w_x) : w[0]+w[1]*exp(-w[2]*x)+w[3]*exp(-w[4]*x)
				break
			case "sin":
				CurveFit /Q/N sin, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				wave w=w_coef
				w_out = WaveExists(w_x) ? w[0]+w[1]*sin(w[2]*w_x+w[3]) : w[0]+w[1]*sin(w[2]*x+w[3])
				break
			case "hillequation":
				CurveFit /Q/N hillequation, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				wave w=w_coef
				w_out = WaveExists(w_x) ? w[0]+(w[1]-w[0])*(w_x^w[2]/(1+(w_x^w[2]+w[3]^w[2]))) : w[0]+(w[1]-w[0])*(x^w[2]/(1+(x^w[2]+w[3]^w[2])))
				break
			case "sigmoid":
				CurveFit /Q/N sigmoid, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				wave w=w_coef
				w_out = WaveExists(w_x) ? w[0] + w[1]/(1+exp(-(w_x-w[2])/w[3])) : w[0] + w[1]/(1+exp(-(x-w[2])/w[3]))
				break
			case "power":
				CurveFit /Q/N power, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				w_out = WaveExists(w_x) ? w_coef[0]+w_coef[1]*w_x^w_coef[2] : w_coef[0]+w_coef[1]*x^w_coef[2]
				break
			case "lognormal":
				CurveFit /Q/N lognormal, w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				wave w_coef
				wave w=w_coef
				w_out = WaveExists(w_x) ? w[0]+w[1]*exp(-(ln(w_x/w[2])/w[3])^2) : w[0]+w[1]*exp(-(ln(x/w[2])/w[3])^2)
				break
			default:
				UserInitialGuess()
				wave w_coef
				FuncFit /Q/N UserFunc W_coef w /M=w_mask /X=w_x /NWOK; AbortOnRTE
				w_out = WaveExists(w_x) ? UserFunc(W_coef,w_x(x)) : UserFunc(W_coef,x)
				break
		endswitch
	catch
		if (V_AbortCode == -4)
			Print "Error during curve fit:"
			variable CFerror = GetRTError(1)	// 1 to clear the error
			Print GetErrMessage(CFerror)
		endif
	endtry
	
	DebuggerOptions debugOnError=sav_debug
	
	if (V_FitError	==0) // record fit coefficients in baseline wavenote
		wave w_coef=w_coef
		string coefStr
		variable i
		sprintf coefstr, "w_coef={"
		for(i=0;i<numpnts(w_coef);i+=1)
			sprintf coefstr, "%s%g,", coefstr, w_coef[i]
		endfor
		coefstr=RemoveEnding(coefstr, ",")+"};"
		note /K w_out, coefstr
	endif
	
	return (V_FitError	==0)
end

// removes first instance of w from graph 'graphStr', plots w,
// optionally vs w_x, on the same axes as the already plotted
// trace 'traceStr'
// BL_appendToSameAxes(graphStr, traceStr, w, w_x, w_rgb={r,g,b}, offset=1)
// appends w (vs w_x if w_x exists), sets color to (r,g,b) and matches y
// offset of traceStr
// Default is choose a color that contrasts with that of traceStr; matchRGB=1 forces
// color to match
static function BL_appendToSameAxes(graphStr, traceStr, w, w_x, [w_rgb, offset, matchRGB])
	string graphStr, traceStr
	wave /Z w, w_x, w_rgb
	variable offset  // match y offset
	variable matchRGB // match color of already plotted trace
	
	offset=ParamIsDefault(offset) ? 0 : offset
	matchRGB=ParamIsDefault(matchRGB) ? 0 : matchRGB
	
	string s_info=TraceInfo(graphStr, traceStr, 0)
	string s_Xax=StringByKey("XAXIS",s_info)
	string s_Yax=StringByKey("YAXIS",s_info)
	string s_flags=StringByKey("AXISFLAGS",s_info)
	variable flagBits=GrepString(s_flags, "/R")+2*GrepString(s_flags, "/T")
	offset = offset ? GetNumFromModifyStr(s_info,"offset","{",1) : 0
	
	// get color of already plotted trace
	variable c0,c1,c2
	variable startIndex=strsearch(s_info, ";rgb(x)=", 0)
	sscanf s_info[startIndex,strlen(s_info)-1], ";rgb(x)=(%d,%d,%d*", c0,c1,c2
	
	if (matchRGB==0 && ParamIsDefault(w_rgb)) // no color specified
		Make /free w_RGB={c0,c1,c2}, w_index={1,2,3}
		if(c0==c1 && c1==c2) // black or grey
			w_RGB={0,0,65535}
		endif
		MakeIndex /R  w_RGB, w_index // order of values from high to low
		Sort w_RGB, w_RGB // sort from lowest to highest
		IndexSort  w_index, w_RGB // resort highest value into original position of lowest, etc.
	endif
	
	if(matchRGB) // this overides any specified color
		Make /free/o w_RGB={c0,c1,c2}
	endif
		
	RemoveFromGraph /W=$graphStr/Z $NameOfWave(w)
	
	switch (flagBits)
		case 0:
			if(WaveExists(w_x))
				AppendToGraph /W=$graphStr/B=$s_Xax/L=$s_Yax/C=(w_rgb[0],w_rgb[1],w_rgb[2]) w vs w_x
			else
				AppendToGraph /W=$graphStr/B=$s_Xax/L=$s_Yax/C=(w_rgb[0],w_rgb[1],w_rgb[2]) w
			endif
			break
		case 1:
			if(WaveExists(w_x))
				AppendToGraph /W=$graphStr/B=$s_Xax/R=$s_Yax /C=(w_rgb[0],w_rgb[1],w_rgb[2]) w vs w_x
			else
				AppendToGraph /W=$graphStr/B=$s_Xax/R=$s_Yax /C=(w_rgb[0],w_rgb[1],w_rgb[2]) w
			endif
			break
		case 2:
			if(WaveExists(w_x))
				AppendToGraph /W=$graphStr/T=$s_Xax/L=$s_Yax /C=(w_rgb[0],w_rgb[1],w_rgb[2]) w vs w_x
			else
				AppendToGraph /W=$graphStr/T=$s_Xax/L=$s_Yax /C=(w_rgb[0],w_rgb[1],w_rgb[2]) w
			endif
			break
		case 3:
			if(WaveExists(w_x))
				AppendToGraph /W=$graphStr/T=$s_Xax/R=$s_Yax/C=(w_rgb[0],w_rgb[1],w_rgb[2]) w vs w_x
			else
				AppendToGraph /W=$graphStr/T=$s_Xax/R=$s_Yax/C=(w_rgb[0],w_rgb[1],w_rgb[2]) w
			endif
			break
	endswitch
	ModifyGraph /W=$graphStr offset($NameOfWave(w))={0,offset}
end

// for Igor 6 compatibility
// returns name of host window
static function /T BL_getGraph()

#if IgorVersion() >= 7
	GetWindow /Z BL_panel  activeSW
	return ParseFilePath(0, s_value, "#", 0, 0)
#endif
	
	string listStr=WinList("*", ";","WIN:1")
	string panelStr, graphStr
	variable i
	do
		graphStr=StringFromList(i, listStr)
		panelStr=graphStr+"#BL_panel"
		if (WinType(panelStr))
			return graphStr
		endif
		i+=1
	while (i<ItemsInList(listStr))
	return ""
end

static function /S BL_getTrace(graphStr)
	string graphStr
	
	ControlInfo /W=$graphStr+"#BL_panel" popTrace
	return s_value
end

// execute Baselines#makeSpectrum() to create a fake spectrum for demo
static function makeSpectrum()

	Make /n=1000 $(UniqueName("foo", 1, 0)) /WAVE=foo
	variable a=enoise(5), b=enoise(1e-3), c=enoise(1e-5), d=enoise(400)
	foo=gnoise(0.1)+a+b*x+c*(x-d)^2
	variable i, height, position, width
	for(i=0;i<5;i+=1)
		height=150+enoise(50)
		position=500+enoise(400)
		width=20+enoise(10)
		foo+=height*Gauss(x, position, width/sqrt(2))
	endfor
	Display /K=1 foo
end


// ---------  Example user-defined fit function.   ------------------

// Edit these three functions where indicated:

// 1. The fit function (you might replace the body of this function with
// that of one created by choosing 'new fit function' in Igor's curve
// fitting dialog). This example fits a line.
static function UserFunc(w,x) : FitFunc
	wave w // the coefficent wave
	variable x // the independent variable
	
	// edit this part:
	return w[0] + w[1]*x
	
end

// 2. Set the initial guesses for the fit coefficients
static function UserInitialGuess()
	
	// if you don't need any info to guide your initial guess for the fit
	// coefficients you can safely delete this part
	string graphStr=BL_getGraph()
	string traceStr=BL_getTrace(graphStr)
	DFREF dfr=GetDFREF()
	wave /Z /SDFR=dfr w_mask
	wave /Z w_data=TraceNameToWaveRef(graphStr, traceStr)
	wave /Z w_x=XWaveRefFromTrace(graphStr, traceStr)
	
	// Edit this part to create the coefficient wave. If you need them,
	// the wave refs for the wave to be fit, the mask wave and the x wave
	// are w_data, w_mask, and w_x, respectively. Just editing the list
	// within the curly braces, e.g. {3,4,5}, should be sufficient for a
	// simple fit function.
	
	Make/D/N=0/O W_coef  // don't change this line
	W_coef[0] = {1,1}  // set the initial guesses here
end

// 3. Set the name of your fit here:
static function /S UserFitName()
	return "" // Insert a name for your fit between the quotes, e.g. return "My Fit"
	// That's it! Next time you start the package you should see
	// your function in the baseline type list
end