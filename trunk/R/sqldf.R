
sqldf <- function(x, stringsAsFactors = TRUE, 
   row.names = FALSE, envir = parent.frame(), 
   to.df = getOption("sqldf.to.df"), to.db = getOption("sqldf.to.db"),
   method = getOption("sqldf.method"),
   file.format = list(), dbname, drv = getOption("sqldf.driver"), 
   user, password = "", host = "localhost",
   dll = getOption("sqldf.dll"), connection = getOption("sqldf.connection"),
   verbose = isTRUE(getOption("sqldf.verbose"))) {

   as.POSIXct.numeric <- function(x, origin = "1970-01-01 00:00:00", ...)
      base::as.POSIXct.numeric(x, origin = origin, ...)
   as.POSIXct.character <- function(x) structure(as.numeric(x),
	class = c("POSIXt", "POSIXct"))
   as.Date.character <- function(x) structure(as.numeric(x), class = "Date")
   as.Date2 <- function(x) UseMethod("as.Date2")
   as.Date2.character <- function(x) base:::as.Date.character(x)
   as.Date.numeric <- function(x, origin = "1970-01-01", ...) base::as.Date.numeric(x, origin = origin, ...)
   as.dates.character <- function(x) structure(as.numeric(x), class = c("dates", "times"))
   as.times.character <- function(x) structure(as.numeric(x), class = "times")


   # nam2 code is duplicated above.  Needs to be factored out.
   backquote.maybe <- function(nam) {
		if (drv == "h2") { nam
		} else if (drv == "pgsql") { nam
		} else {
			if (regexpr(".", nam, fixed = TRUE)) {
				paste("`", nam, "`", sep = "")
			} else nam
		}
	}

   name__class <- function(data, ...) {
	if (is.null(data)) return(data)
	cls <- sub(".*__([^_]+)|.*", "\\1", names(data))
	f <- function(i) {
		if (cls[i] == "") { 
			data[[i]] 
		} else {
			fun_name <- paste("as", cls[i], sep = ".")
			fun <- mget(fun_name, env = environment(), 
				mode = "function", ifnotfound = NA, inherit = TRUE)[[1]]
			if (identical(fun, NA)) data[[i]] else {
				# strip _class off name
				names(data)[i] <<- sub("__[^_]+$", "", names(data)[i])
				fun(data[[i]])
			}
		}
	}
	data[] <- lapply(1:NCOL(data), f)
	data
   }

	colClass <- function(data, cls) {
	  if (is.null(data)) return(data)
	  if (is.list(cls)) cls <- unlist(cls)
	  cls <- rep(cls, length = length(data))
	  f <- function(i) {
		if (cls[i] == "") { 
			data[[i]] 
		} else {
			fun_name <- paste("as", cls[i], sep = ".")
			fun <- mget(fun_name, env = environment(), 
				mode = "function", ifnotfound = NA, inherit = TRUE)[[1]]
			if (identical(fun, NA)) data[[i]] else {
				# strip _class off name
				names(data)[i] <<- sub("__[^_]+$", "", names(data)[i])
				fun(data[[i]])
			}
		 }
	   }
	data[] <- lapply(1:NCOL(data), f)
	data
   }

	overwrite <- FALSE

	request.open <- missing(x) && is.null(connection)
	request.close <- missing(x) && !is.null(connection)
	request.con <- !missing(x) && !is.null(connection)
	request.nocon <- !missing(x) && is.null(connection)

	dfnames <- fileobjs <- character(0)

	# if exactly one of x and connection are missing then close on exit
	if (request.close || request.nocon) { 

		on.exit({
			dbPreExists <- attr(connection, "dbPreExists")
			dbname <- attr(connection, "dbname")
    		if (!missing(dbname) && !is.null(dbname) && dbname == ":memory:") {
				if (verbose) {
					cat("sqldf: disconnecting database\n")
				}
				dbDisconnect(connection)
    		} else if (!dbPreExists && drv == "sqlite") {
    			# data base not pre-existing
				if (verbose) {
					cat("sqldf: disconnecting and removing database\n")
				}
    			dbDisconnect(connection)
    			file.remove(dbname)
    		} else {
    			# data base pre-existing

    			for (nam in dfnames) {
					nam2 <- backquote.maybe(nam)
					if (verbose) {
						cat("sqldf: removing table", nam2, "from database\n")
					}
					dbRemoveTable(connection, nam2)
				}
    			for (fo in fileobjs) {
					if (verbose) {
						cat("sqldf: removing table", fo, "from database\n")
					}
					dbRemoveTable(connection, fo)
				}
				if (verbose) {
					cat("sqldf: disconnecting database\n")
				}
    			dbDisconnect(connection)
    		}
    	})
		if (request.close) {
			if (identical(connection, getOption("sqldf.connection")))
				options(sqldf.connection = NULL)
			return()
		}
	}

	# if con is missing then connection opened
	if (request.open || request.nocon) {
    
    	if (is.null(drv)) {
    		drv <- if ("package:RpgSQL" %in% search()) { "pgSQL"
			} else if ("package:RMySQL" %in% search()) { "MySQL" 
    		} else if ("package:RH2" %in% search()) { "H2" 
    		} else "SQLite"
    	}
    
		drv <- tolower(drv)
    	if (drv == "mysql") {
			if (verbose) cat("sqldf: using mysql\n")
    		m <- dbDriver("MySQL")
    		connection <- if (missing(dbname) || dbname == ":memory:") { 
    				dbConnect(m) 
    			} else dbConnect(m, dbname = dbname)
    			dbPreExists <- TRUE
		} else if (drv == "pgsql") {
			if (verbose) cat("sqldf: using pgSQL\n")
    		m <- dbDriver("pgSQL")
			if (missing(dbname) || is.null(dbname)) {
				dbname <- getOption("RpgSQL.dbname")
				if (is.null(dbname)) dbname <- "test"
			}
			connection <- dbConnect(m, dbname = dbname)
    		dbPreExists <- TRUE
    	} else if (drv == "h2") {
			# jar.file <- "C:\\Program Files\\H2\\bin\\h2.jar"
			# jar.file <- system.file("h2.jar", package = "H2")
			# m <- JDBC("org.h2.Driver", jar.file, identifier.quote = '"')
			if (verbose) cat("sqldf: using H2\n")
			m <- H2()
    		if (missing(dbname) || is.null(dbname)) dbname <- ":memory:"
    		dbPreExists <- dbname != ":memory:" && file.exists(dbname)
			connection <- if (missing(dbname) || dbname == ":memory:") {
					dbConnect(m, "jdbc:h2:mem:", "sa", "")
				} else {
					jdbc.string <- paste("jdbc:h2", dbname, sep = ":")
					# dbConnect(m, jdbc.string, "sa", "")
					dbConnect(m, jdbc.string)
				}
		} else {
			if (verbose) cat("sqldf: using SQLite\n")
    		m <- dbDriver("SQLite")
    		if (missing(dbname)) dbname <- ":memory:"
    		dbPreExists <- dbname != ":memory:" && file.exists(dbname)

			# search for spatialite extension on PATH and, if found, load it
			if (is.null(getOption("sqldf.dll"))) {
				dll <- Sys.which("libspatialite-1.dll")
				if (dll != "") options(sqldf.dll = dll) else options(sqldf.dll = FALSE)
			}
			dll <- getOption("sqldf.dll")
			if (length(dll) != 1 || identical(dll, FALSE) || nchar(dll) == 0) {
				dll <- FALSE
			} else {
				if (dll == basename(dll)) dll <- Sys.which(dll)
			}
			options(sqldf.dll = dll)

			if (verbose) {
				cat("sqldf: connecting to database", dbname, "\n")
			}
			if (!identical(dll, FALSE)) {
				connection <- dbConnect(m, dbname = dbname, 
					loadable.extensions = TRUE)
				if (verbose) {
					cat("sqldf: loading extension", normalizePath(dll), "\n")
				}
				s <- sprintf("select load_extension('%s')", dll)
				dbGetQuery(connection, s)
			} else connection <- dbConnect(m, dbname = dbname)
			# if (require("RSQLite.extfuns")) init_extensions(connection)
			# load extension functions from RSQLite.extfuns
			if (verbose) cat("sqldf: loading extension from RSQLite.extfuns package\n")
			init_extensions(connection)
    	}
		attr(connection, "dbPreExists") <- dbPreExists
		if (missing(dbname) && drv == "sqlite") dbname <- ":memory:"
		attr(connection, "dbname") <- dbname
    	if (request.open) {
			options(sqldf.connection = connection)
			return(connection)
		}
	}

	# connection was specified
	if (request.con) {
		drv <- if (inherits(connection, "pgSQLConnection")) "pgSQL"
		else if (inherits(connection, "MySQLConnection")) "MySQL"
		else if (inherits(connection, "H2Connection")) "H2"
		else "SQLite"
		drv <- tolower(drv)
		dbPreExists <- attr(connection, "dbPreExists")
	}

	# words. is a list whose ith component contains vector of words in ith stmt
	# words is all the words in one long vector without duplicates
	words. <- words <- strapply(x, "[[:alnum:]._]+")
	if (length(words) > 0) words <- unique(unlist(words))
	is.special <- sapply(
		mget(words, envir, "any", NA, inherits = TRUE), 
		function(x) is.data.frame(x) + 2 * inherits(x, "file"))

	# process data frames
	dfnames <- words[is.special == 1]
	for(i in seq_along(dfnames)) {
		nam <- dfnames[i]
		if (dbPreExists && !overwrite && dbExistsTable(connection, nam)) {
			# exit code removes tables in dfnames
			# so only include those added so far
			dfnames <- head(dfnames, i-1)
			stop(paste("sqldf:", "table", nam, 
				"already in", dbname, "\n"))
		}
		# check if the nam2 processing works with MySQL
		# if not then ensure its only applied to SQLite
		DF <- as.data.frame(get(nam, envir))
		if (!is.null(to.db) && is.function(to.db)) DF <- to.db(DF)
		nam2 <- backquote.maybe(nam)
		if (verbose) cat("sqldf: writing", nam2, "to database\n")
		dbWriteTable(connection, nam2, DF, row.names = row.names)
	}

	# process file objects
	fileobjs <- if (is.null(file.format)) { character(0)
	} else {
		eol <- if (.Platform$OS == "windows") "\r\n" else "\n"
		words[is.special == 2]
	}
	for(i in seq_along(fileobjs)) {
		fo <- fileobjs[i]
		Filename <- summary(get(fo, envir))$description
		if (dbPreExists && !overwrite && dbExistsTable(connection, Filename)) {
			# exit code should only remove tables added so far
			fileobjs <- head(fileobjs, i-1)
			stop(paste("sqldf:", "table", fo, "from file", 
				Filename, "already in", dbname, "\n"))
		}
		args <- c(list(conn = connection, name = fo, value = Filename), 
			modifyList(list(eol = eol), file.format))
		args <- modifyList(args, as.list(attr(get(fo, envir), "file.format")))
		filter <- args$filter
		if (!is.null(filter)) {
			args$filter <- NULL
			Filename.tmp <- tempfile()
			args$value <- Filename.tmp
			cmd <- sprintf("%s < %s > %s", filter, Filename, Filename.tmp)
			# on Windows platform preface command with cmd /c 
			if (.Platform$OS == "windows") {
				cmd <- paste("cmd /c", cmd)
				if (FALSE) {
				key <- "SOFTWARE\\R-core"
				show.error.messages <- getOption("show.error.message")
				options(show.error.messages = FALSE)
				reg <- try(readRegistry(key, maxdepth = 3)$Rtools$InstallPath)
				reg <- NULL
				options(show.error.messages = show.error.messages)
				# add Rtools bin directory to PATH if found in registry
				if (!is.null(reg) && !inherits(reg, "try-error")) {
					Rtools.path <- file.path(reg, "bin", fsep = "\\")
					path <- Sys.getenv("PATH")
					on.exit(Sys.setenv(PATH = path), add = TRUE)
					path.new <- paste(path, Rtools.path, sep = ";")
					Sys.setenv(PATH = path.new)
				}
				}
			}
			system(cmd)
		}
		do.call("dbWriteTable", args)
	}

	# SQLite can process all statements using dbGetQuery.  
	# Other databases process select/call/show with dbGetQuery and other 
	# statements with dbSendQuery.
	if (drv == "sqlite") {
		for(xi in x) {
			if (verbose) {
				cat("sqldf: dbGetQuery:", xi, "\n")
			}
			rs <- dbGetQuery(connection, xi)
		}
	} else {
		for(i in seq_along(x)) {
			if (length(words.[[i]]) > 0) {
				dbGetQueryWords <- c("select", "show", "call", "explain")
				if (tolower(words.[[i]][1]) %in% dbGetQueryWords) {
					if (verbose) {
						cat("sqldf: dbGetQuery:", x[i], "\n")
					}
					rs <- dbGetQuery(connection, x[i])
				} else {
					if (verbose) {
						cat("sqldf: dbSendUpdate:", x[i], "\n")
					}
					rs <- dbSendUpdate(connection, x[i])
				}
			}
		}
	}

	# get result back
	if (!is.null(method) && !is.null(to.df)) {
		stop("cannot specify both method and to.df. Use just to.df.")
	}
	if (!is.null(method)) warning("method is deprecated. Use to.df instead.")
	if (!is.null(method)) to.df <- method

	if (is.null(to.df)) to.df <- "auto"
    if (is.function(to.df)) return(to.df(rs))
	# to.df <- match.arg(to.df, c("auto", "raw", "name__class"))
	if (identical(to.df, "raw")) return(rs)
	if (identical(to.df, "name__class")) return(do.call("name__class", list(rs)))
	if (!identical(to.df, "auto")) return(do.call("colClass", list(rs, to.df)))
	# process row_names
	rs <- if ("row_names" %in% names(rs)) {
		if (identical(row.names, FALSE)) {
			# subset(rs, select = - row_names)
			rs[names(rs) != "row_names"]
		} else { 
			rn <- rs$row_names
			# rs <- subset(rs, select = - row_names)
			rs <- rs[names(rs) != "row_names"]
			if (all(regexpr("^[[:digit:]]*$", rn) > 0)) 
				rn <- as.integer(rn)
			rownames(rs) <- rn
			rs
		}
	} else rs

	# fix up column classes
	#
	# For each column name in the result, match it against each column name
	# of each data frame in envir.
	# 
	#
	tab <- do.call("rbind", lapply(dfnames, function(dfname) {
		df <- get(dfname, envir)
		cbind(dfname, colnames(df))
	}))
	# column names which are duplicated
	dup <- tab[,2][duplicated(tab[,2])]

	f <- function(i) {
		cn <- colnames(rs)[[i]]
		if (! cn %in% dup && 
			(ix <- match(cn, tab[, 2], nomatch = 0)) > 0) {
			df <- get(tab[ix, 1], envir)
			if (inherits(df[[cn]], "ordered"))
				return(as.ordered(factor(rs[[cn]], 
					levels = levels(df[[cn]]))))
			else if (inherits(df[[cn]], "factor"))
				return(factor(rs[[cn]], 
					levels = levels(df[[cn]])))
			else if (inherits(df[[cn]], "POSIXct"))
				return(as.POSIXct(rs[[cn]]))
			else if (identical(class(df[[cn]]), "times")) 
				return(times(df[[cn]]))
			else {
				asfn <- paste("as", 
					class(df[[cn]]), sep = ".")
				asfn <- match.fun(asfn)
				return(asfn(rs[[cn]]))
			}
		}
		if (stringsAsFactors) 
			if (is.character(rs[[i]]))
				factor(rs[[i]])
			else rs[[i]]
	}
	# debug(f)
	rs2 <- lapply(seq_along(rs), f)
	rs[] <- rs2
	rs
}


read.csv.sql <- function(file, sql = "select * from file", 
	header = TRUE, sep = ",", row.names, eol, skip, filter, 
	dbname = tempfile(), drv = "SQLite", ...) {
	file.format <- list(header = header, sep = sep)
	if (!missing(eol)) 
		file.format <- append(file.format, list(eol = eol))
	if (!missing(row.names)) 
		file.format <- append(file.format, list(row.names = row.names))
	if (!missing(skip)) 
		file.format <- append(file.format, list(skip = skip))
	if (!missing(filter)) 
		file.format <- append(file.format, list(filter = filter))
	pf <- parent.frame()
	p <- proto(pf, file = file(file))
	p <- do.call(proto, list(pf, file = file(file)))
	sqldf(sql, envir = p, file.format = file.format, dbname = dbname, drv = drv, ...)
}


read.csv2.sql <- function(file, sql = "select * from file", 
	header = TRUE, sep = ";", row.names, eol, skip, filter, 
    dbname = tempfile(), drv = "SQLite", ...) {

	if (missing(filter)) {
		filter <- if (.Platform$OS == "windows")
			paste("cscript /nologo", normalizePath(system.file("trcomma2dot.vbs", package = "sqldf")))
		else "tr , ."
	}

read.csv.sql(file = file, sql = sql, header = header, sep = sep, 
		row.names = row.names, eol = eol, skip = skip, filter = filter, 
		dbname = dbname, drv = drv)
}
