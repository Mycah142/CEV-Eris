// Error viewing datums, responsible for storing error info, notifying admins
// when errors occur, and showing them to admins on demand.

// There are 3 different types used here:
//
// - ErrorCache keeps track of all error sources, as well as all individually
//   logged errors. Only one instance of this datum should ever exist, and it's
//   right here:

#ifdef DEBUG
var/global/datum/ErrorViewer/ErrorCache/error_cache = new()
#else
// If debugging is disabled, there's nothing useful to log, so don't bother.
var/global/datum/ErrorViewer/ErrorCache/error_cache = null
#endif

// - ErrorSource datums exist for each line (of code) that generates an error,
//   and keep track of all errors generated by that line.
//
// - ErrorEntry datums exist for each logged error, and keep track of all
//   relevant info about that error.

// Common vars and procs are kept at the ErrorViewer level
/datum/ErrorViewer/
	var/name = ""

/datum/ErrorViewer/proc/browseTo(var/user, var/html)
	if(user)
		var/datum/browser/popup = new(user, "error_viewer", "Runtime Viewer", 700, 500)
		popup.add_head_content({"<style>
			.runtime{
				background-color: #171717;
				border: solid 1px #202020;
				font-family:'Courier New',monospace;
				font-size:9pt;
				color: #DDDDDD;
			}
			p.runtime_list{
				font-family:'Courier New',monospace;
				font-size:9pt;
				margin: 0;
				padding: 0;
				text-indent:-13ch;
				margin-left:13ch;
			}
			</style>"})
		popup.set_content(html)
		popup.open(0)

/datum/ErrorViewer/proc/buildHeader(var/datum/ErrorViewer/back_to, var/linear, var/refreshable)
	// Common starter HTML for showTo
	var/html = ""

	if(istype(back_to))
		html += "[back_to.makeLink("<<<", null, linear)] "
	if(refreshable)
		html += "[makeLink("Refresh", null, linear)]"
	if(html)
		html += "<br><br>"
	return html

/datum/ErrorViewer/proc/showTo(var/user, var/datum/ErrorViewer/back_to, var/linear)
	// Specific to each child type
	return

/datum/ErrorViewer/proc/makeLink(var/linktext, var/datum/ErrorViewer/back_to, var/linear)
	var/back_to_param = ""
	if(!linktext)
		linktext = name
	if(istype(back_to))
		back_to_param = ";viewruntime_backto=\ref[back_to]"
	if(linear)
		back_to_param += ";viewruntime_linear=1"
	return "<A href='byond://?_src_=holder;viewruntime=\ref[src][back_to_param]'>[html_encode(linktext)]</A>"

/datum/ErrorViewer/ErrorCache
	var/list/errors = list()
	var/list/error_sources = list()
	var/list/errors_silenced = list()

/datum/ErrorViewer/ErrorCache/showTo(var/user, var/datum/ErrorViewer/back_to, var/linear)
	var/html = buildHeader(null, linear, refreshable=1)
	html += "[total_runtimes] runtimes, [total_runtimes_skipped] skipped<br><br>"
	if(!linear)
		html += "organized | [makeLink("linear", null, 1)]<hr>"
		var/datum/ErrorViewer/ErrorSource/error_source
		for(var/erroruid in error_sources)
			error_source = error_sources[erroruid]
			html += "<p class='runtime_list'>[error_source.makeLink(null, src)]<br></p>"
	else
		html += "[makeLink("organized", null)] | linear<hr>"
		for(var/datum/ErrorViewer/ErrorEntry/error_entry in errors)
			html += "<p class='runtime_list'>[error_entry.makeLink(null, src, 1)]<br></p>"
	browseTo(user, html)

/datum/ErrorViewer/ErrorCache/proc/logError(var/exception/e, var/list/desclines, var/skipCount, var/datum/e_src)
	if(!istype(e))
		return // Abnormal exception, don't even bother

	var/erroruid = "[e.file][e.line]"
	var/datum/ErrorViewer/ErrorSource/error_source = error_sources[erroruid]
	if(!error_source)
		error_source = new(e)
		error_sources[erroruid] = error_source

	var/datum/ErrorViewer/ErrorEntry/error_entry = new(e, desclines, skipCount, e_src)
	error_entry.error_source = error_source
	errors += error_entry
	error_source.errors += error_entry
	if(skipCount)
		return // Skip notifying admins about skipped errors

	// Show the error to admins with debug messages turned on, but only if one
	//  from the same source hasn't been shown too recently
	if(error_source.next_message_at <= world.time)
		var/const/viewtext = "\[view]" // Nesting these in other brackets went poorly
		log_debug("Runtime in [e.file],[e.line]: [html_encode(e.name)] [error_entry.makeLink(viewtext)]")
		error_source.next_message_at = world.time + ERROR_MSG_DELAY

/datum/ErrorViewer/ErrorSource
	var/list/errors = list()
	var/next_message_at = 0

/datum/ErrorViewer/ErrorSource/New(var/exception/e)
	if(!istype(e))
		name = "\[[time_stamp()]] Uncaught exceptions"
		return
	name = "\[[time_stamp()]] Runtime in [e.file],[e.line]: [e]"

/datum/ErrorViewer/ErrorSource/showTo(var/user, var/datum/ErrorViewer/back_to, var/linear)
	if(!istype(back_to))
		back_to = error_cache
	var/html = buildHeader(back_to, refreshable=1)
	for(var/datum/ErrorViewer/ErrorEntry/error_entry in errors)
		html += "<p class='runtime_list'>[error_entry.makeLink(null, src)]<br></p>"
	browseTo(user, html)

/datum/ErrorViewer/ErrorEntry
	var/datum/ErrorViewer/ErrorSource/error_source
	var/exception/exc
	var/desc = ""
	var/srcRef
	var/srcType
	var/turf/srcLoc
	var/usrRef
	var/turf/usrLoc
	var/isSkipCount

/datum/ErrorViewer/ErrorEntry/New(var/exception/e, var/list/desclines, var/skipCount, var/datum/e_src)
	if(!istype(e))
		name = "\[[time_stamp()]] Uncaught exception: [e]"
		return
	if(skipCount)
		name = "\[[time_stamp()]] Skipped [skipCount] runtimes in [e.file],[e.line]."
		isSkipCount = TRUE
		return
	name = "\[[time_stamp()]] Runtime in [e.file],[e.line]: [e]"
	exc = e
	if(istype(desclines))
		for(var/line in desclines)
			// There's probably a better way to do this than non-breaking spaces...
			desc += "&nbsp;&nbsp;" + html_encode(line) + "<br>"
	if(istype(e_src))
		srcRef = "\ref[e_src]"
		srcType = e_src.type
		srcLoc = get_turf(e_src)
	if(usr)
		usrRef = "\ref[usr]"
		usrLoc = get_turf(usr)

/datum/ErrorViewer/ErrorEntry/showTo(var/user, var/datum/ErrorViewer/back_to, var/linear)
	if(!istype(back_to))
		back_to = error_source
	var/html = buildHeader(back_to, linear)
	html += "<div class='runtime'>[html_encode(name)]<br>[desc]</div>"
	if(srcRef)
		html += "<br>src: <a href='byond://?_src_=vars;Vars=[srcRef]'>VV</a>"
		if(ispath(srcType, /mob))
			html += " <a href='byond://?_src_=holder;adminplayeropts=[srcRef]'>PP</a>"
			html += " <a href='byond://?_src_=holder;adminplayerobservefollow=[srcRef]'>Follow</a>"
		if(istype(srcLoc))
			html += "<br>src.loc: <a href='byond://?_src_=vars;Vars=\ref[srcLoc]'>VV</a>"
			html += " <a href='byond://?_src_=holder;adminplayerobservecoodjump=1;X=[srcLoc.x];Y=[srcLoc.y];Z=[srcLoc.z]'>JMP</a>"
	if(usrRef)
		html += "<br>usr: <a href='byond://?_src_=vars;Vars=[usrRef]'>VV</a>"
		html += " <a href='byond://?_src_=holder;adminplayeropts=[usrRef]'>PP</a>"
		html += " <a href='byond://?_src_=holder;adminplayerobservefollow=[usrRef]'>Follow</a>"
		if(istype(usrLoc))
			html += "<br>usr.loc: <a href='byond://?_src_=vars;Vars=\ref[usrLoc]'>VV</a>"
			html += " <a href='byond://?_src_=holder;adminplayerobservecoodjump=1;X=[usrLoc.x];Y=[usrLoc.y];Z=[usrLoc.z]'>JMP</a>"
	browseTo(user, html)

/datum/ErrorViewer/ErrorEntry/makeLink(var/linktext, var/datum/ErrorViewer/back_to, var/linear)
	if(isSkipCount)
		return html_encode(name)
	return ..()
