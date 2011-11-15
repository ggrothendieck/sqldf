
.onLoad <- function(libname, pkgname) {

	# append sqldf library directory to AWKPATH (. is always searched so it
	# need not be specified)
	sqldf.home <- normalizePath(file.path(libname, pkgname))
	AWKPATH <- Sys.getenv("AWKPATH")
	if (is.null(AWKPATH)) Sys.setenv(AWKPATH=sqldf.home)
	else {
		# if awkpath exists but is lower case then references will fail 
		# so delete it and replace it to be sure
		Sys.setenv(AWKPATH="")
		pathsep <- if (.Platform$OS.type == "windows") ";" else ":"
		Sys.setenv(AWKPATH=paste(AWKPATH, sqldf.home, sep = pathsep))
	}

	drv <- getOption("sqldf.driver")
	drv <- if (is.null(drv) || drv == "") {
		if ("package:RpgSQL" %in% search()) { 
			"pgSQL"
		} else if ("package:RMySQL" %in% search()) { 
			"MySQL" 
		} else if ("package:RH2" %in% search()) { 
			"H2" 
		} else "SQLite"
	} else if (!tolower(drv) %in% c("pgsql", "mysql", "h2")) {
		"SQLite"
	}
	if (drv != "SQLite") {
		msg <- paste("sqldf will default to using", drv)
		packageStartupMessage(msg)
	}
}

.onUnload <- function(libpath) {
}
