
.onAttach <- function(libname, pkgname) {

	drv <- getOption("sqldf.driver")
	drv <- if (is.null(drv) || drv == "") {

		if ("package:RPostgreSQL" %in% search()) { 
			"PostgreSQL"
		} else if ("package:RpgSQL" %in% search()) { 
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
	} else {
		loadNamespace("RSQLite")
	}
}

# .onUnload <- function(libpath) {}
