
sqldf <- function(x, stringsAsFactors = FALSE,
   row.names = FALSE, envir = parent.frame(), 
   method = getOption("sqldf.method"),
   file.format = list(), dbname, drv = getOption("sqldf.driver"), 
   user, password = "", host = "localhost", port,
   dll = getOption("sqldf.dll"), connection = getOption("sqldf.connection"),
   verbose = isTRUE(getOption("sqldf.verbose"))) {

   # as.POSIXct.numeric <- function(x, origin = "1970-01-01 00:00:00", ...)
   #  base::as.POSIXct.numeric(x, origin = origin, ...)
   as.POSIXct.numeric <- function(x, ...)
      structure(x, class = c("POSIXct", "POSIXt"))
   as.POSIXct.character <- function(x) structure(as.numeric(x),
	class = c("POSIXct", "POSIXt"))
   as.Date.character <- function(x) structure(as.numeric(x), class = "Date")
   as.Date2 <- function(x) UseMethod("as.Date2")
   as.Date2.character <- function(x) as.Date.character(x)
   as.Date.numeric <- function(x, origin = "1970-01-01", ...) base::as.Date.numeric(x, origin = origin, ...)
   as.dates.character <- function(x) structure(as.numeric(x), class = c("dates", "times"))
   as.times.character <- function(x) structure(as.numeric(x), class = "times")


   # nam2 code is duplicated above.  Needs to be factored out.
   backquote.maybe <- function(nam) {
		if (drv == "h2") { nam
		} else if (drv == "mysql") { nam
		} else if (drv == "pgsql") { nam
		} else if (drv == "postgresql") { nam
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
			fun <- mget(fun_name, envir = environment(), 
				mode = "function", ifnotfound = NA, inherits = TRUE)[[1]]
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
			fun <- mget(fun_name, envir = environment(), 
				mode = "function", ifnotfound = NA, inherits = TRUE)[[1]]
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


	if (!is.list(method)) method <- list(method, NULL)
	to.df <- method[[1]]
	to.db <- method[[2]]

	# if exactly one of x and connection are missing then close on exit
	if (request.close || request.nocon) { 

		on.exit({
			dbPreExists <- attr(connection, "dbPreExists")
			dbname <- attr(connection, "dbname")
    		if (!missing(dbname) && !is.null(dbname) && dbname == ":memory:") {
				if (verbose) {
					cat("sqldf: dbDisconnect(connection)\n")
				}
				dbDisconnect(connection)
    		} else if (!dbPreExists && drv == "sqlite") {
    			# data base not pre-existing
				if (verbose) {
					cat("sqldf: dbDisconnect(connection)\n")
					cat("sqldf: file.remove(dbname)\n")
				}
    			dbDisconnect(connection)
    			file.remove(dbname)
    		} else {
    			# data base pre-existing

    			for (nam in dfnames) {
					nam2 <- backquote.maybe(nam)
					if (verbose) {
						cat("sqldf: dbRemoveTable(connection, ", nam2, ")\n")
					}
					dbRemoveTable(connection, nam2)
				}
    			for (fo in fileobjs) {
					if (verbose) {
						cat("sqldf: dbRemoveTable(connection, ", fo, ")\n")
					}
					dbRemoveTable(connection, fo)
				}
				if (verbose) {
					cat("sqldf: dbDisconnect(connection)\n")
				}
    			dbDisconnect(connection)
    		}
    	}, add = TRUE)
		if (request.close) {
			if (identical(connection, getOption("sqldf.connection")))
				options(sqldf.connection = NULL)
			return()
		}
	}

	# if con is missing then connection opened
	if (request.open || request.nocon) {
    
    	if (is.null(drv) || drv == "") {
    		drv <- if ("package:RPostgreSQL" %in% search()) { "PostgreSQL"
    		} else if ("package:RpgSQL" %in% search()) { "pgSQL"
			} else if ("package:RMySQL" %in% search()) { "MySQL" 
    		} else if ("package:RH2" %in% search()) { "H2" 
    		} else "SQLite"
    	}

		drv <- sub("^[Rr]", "", drv)
		pkg <- paste("R", drv, sep = "")
		if (verbose) {
			if (!is.loaded(pkg)) cat("sqldf: library(", pkg, ")\n", sep = "")
			library(pkg, character.only = TRUE)
		} else library(pkg, character.only = TRUE)

		drv <- tolower(drv)

    	if (drv == "mysql") {
			if (verbose) cat("sqldf: m <- dbDriver(\"MySQL\")\n")
    		m <- dbDriver("MySQL")
			if (missing(dbname) || is.null(dbname)) {
				dbname <- getOption("RMySQL.dbname")
				if (is.null(dbname)) dbname <- "test"
			}
    		connection <- if (missing(dbname) || dbname == ":memory:") { 
    				dbConnect(m) 
    			} else dbConnect(m, dbname = dbname)
    			dbPreExists <- TRUE
		} else if (drv == "postgresql") {
			if (verbose) cat("sqldf: m <- dbDriver(\"PostgreSQL\")\n")
    		m <- dbDriver("PostgreSQL")
			if (missing(user) || is.null(user)) {
				user <- getOption("sqldf.RPostgreSQL.user")
				if (is.null(user)) user <- "postgres"
			}
			if (missing(password) || is.null(password)) {
				password <- getOption("sqldf.RPostgreSQL.password")
				if (is.null(password)) password <- "postgres"
			}
			if (missing(dbname) || is.null(dbname)) {
				dbname <- getOption("sqldf.RPostgreSQL.dbname")
				if (is.null(dbname)) dbname <- "test"
			}
			if (missing(host) || is.null(host)) {
				host <- getOption("sqldf.RPostgreSQL.host")
				if (is.null(host)) host <- "localhost"
			}
			if (missing(port) || is.null(port)) {
				port <- getOption("sqldf.RPostgreSQL.port")
				if (is.null(port)) port <- 5432
			}
			connection.args <- list(m, user = user, password,
				dbname = dbname, host = host, port = port)
			connection.args.other <- getOption("sqldf.RPostgreSQL.other")
			if (!is.null(connection.args.other))
			connection.args <- modifyList(connection.args,
						connection.args.other)
			connection <- do.call("dbConnect", connection.args)
			# connection <- dbConnect(m, user = user, password, dbname = dbname,
				# host = host, port = port)

		    if (verbose) {
			    cat(sprintf("sqldf: connection <- dbConnect(m, user='%s', password=<...>, dbname = '%s', host = '%s', port = '%s', ...)\n", user, dbname, host, port))
			    if (!is.null(connection.args.other)) {
				    cat("other connection arguments:\n")
				    print(connection.args.other)
			    }
		    }
    		dbPreExists <- TRUE
		} else if (drv == "pgsql") {
			if (verbose) cat("sqldf: m <- dbDriver(\"pgSQL\")\n")
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
			if (verbose) cat("sqldf: m <- dbDriver(\"H2\")\n")
			# m <- H2()
			m <- dbDriver("H2")
    		if (missing(dbname) || is.null(dbname)) dbname <- ":memory:"
    		dbPreExists <- dbname != ":memory:" && file.exists(dbname)
			connection <- if (missing(dbname) || is.null(dbname) || 
				dbname == ":memory:") {
					dbConnect(m, "jdbc:h2:mem:", "sa", "")
				} else {
					jdbc.string <- paste("jdbc:h2", dbname, sep = ":")
					# dbConnect(m, jdbc.string, "sa", "")
					dbConnect(m, jdbc.string)
				}
		} else {
			if (verbose) cat("sqldf: m <- dbDriver(\"SQLite\")\n")
    		m <- dbDriver("SQLite")
    		if (missing(dbname) || is.null(dbname)) dbname <- ":memory:"
    		dbPreExists <- dbname != ":memory:" && file.exists(dbname)

			# search for spatialite extension on PATH and, if found, load it
			# if (is.null(getOption("sqldf.dll"))) {
			#	dll <- Sys.which("libspatialite-2.dll")
			#	if (dll == "") dll <- Sys.which("libspatialite-1.dll")
			#	dll <- if (dll == "") FALSE else normalizePath(dll)
			#	options(sqldf.dll = dll)
			# }
			dll <- getOption("sqldf.dll")
			if (length(dll) != 1 || identical(dll, FALSE) || nchar(dll) == 0) {
				dll <- FALSE
			} else {
				if (dll == basename(dll)) dll <- Sys.which(dll)
			}
			options(sqldf.dll = dll)

			if (!identical(dll, FALSE)) {
				if (verbose) {
					cat("sqldf: connection <- dbConnect(m, dbname = \"", dbname, 
						"\", loadable.extensions = TRUE\n", sep = "")
					cat("sqldf: select load_extension('", dll, "')\n", sep = "")
				}
				connection <- dbConnect(m, dbname = dbname, 
					loadable.extensions = TRUE)
				s <- sprintf("select load_extension('%s')", dll)
				dbGetQuery(connection, s)
			} else {
				if (verbose) {
				cat("sqldf: connection <- dbConnect(m, dbname = \"", dbname, "\")\n", sep = "")
				}
				connection <- dbConnect(m, dbname = dbname)
			}
			if (verbose) cat("sqldf: initExtension(connection)\n")
			initExtension(connection)
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
		drv <- if (inherits(connection, "PostgreSQLConnection")) "PostgreSQL"
		else if (inherits(connection, "pgSQLConnection")) "pgSQL"
		else if (inherits(connection, "MySQLConnection")) "MySQL"
		else if (inherits(connection, "H2Connection")) "H2"
		else "SQLite"
		drv <- tolower(drv)
		dbPreExists <- attr(connection, "dbPreExists")
	}

	# engine is "tcl" or "R".  
	engine <- getOption("gsubfn.engine")
	if (is.null(engine) || is.na(engine) || engine == "") {
		engine <- if (require("tcltk")) "tcl" else "R"
	} else if (engine == "tcl") require("tcltk")

	# words. is a list whose ith component contains vector of words in ith stmt
	# words is all the words in one long vector without duplicates
	#
	# If "tcl" is available use the faster strapplyc else strapply
	words. <- words <- if (engine == "tcl") {
		strapplyc(x, "[[:alnum:]._]+")
	} else strapply(x, "[[:alnum:]._]+", engine = "R")
	
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
		# if (verbose) cat("sqldf: writing", nam2, "to database\n")
		if (verbose) cat("sqldf: dbWriteTable(connection, '", nam2, "', ", nam, ", row.names = ", row.names, ")\n", sep = "")
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
			modifyList(list(eol = eol), 
            file.format))
		args <- modifyList(args, as.list(attr(get(fo, envir), "file.format")))
		filter <- args$filter
		if (!is.null(filter)) {
			args$filter <- NULL
			Filename.tmp <- tempfile()
			args$value <- Filename.tmp
			# for filter = list(cmd, x = ...) replace x in cmd with
			# temporary filename for a file created to hold ...
			filter.subs <- filter[-1]
			# filter subs contains named elements of filter
			if (length(filter.subs) > 0) {
				filter.subs <- filter.subs[sapply(names(filter.subs), nzchar)]
			}
			filter.nms <- names(filter.subs)
			# create temporary file names
			filter.tempfiles <- sapply(filter.nms, tempfile)
			cmd <- filter[[1]]
			# write out temporary file & substitute temporary file name into cmd
			for(nm in filter.nms) {
				cat(filter.subs[[nm]], file = filter.tempfiles[[nm]])
				cmd <- gsub(nm, filter.tempfiles[[nm]], cmd, fixed = TRUE)
			}
			cmd <- if (nchar(Filename) > 0)
				sprintf('%s < "%s" > "%s"', cmd, Filename, Filename.tmp)
			else sprintf('%s > "%s"', cmd, Filename.tmp)

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
			if (verbose) cat("sqldf: system(\"", cmd, "\")\n", sep = "")
			system(cmd)
			for(fn in filter.tempfiles) file.remove(fn)
		}
		if (verbose) cat("sqldf: dbWriteTable(", toString(args), ")\n")
		do.call("dbWriteTable", args)
	}

	# SQLite can process all statements using dbGetQuery.  
	# Other databases process select/call/show with dbGetQuery and other 
	# statements with dbSendQuery.
	if (drv == "sqlite" || drv == "mysql" || drv == "postgresql") {
		for(xi in x) {
			if (verbose) {
				cat("sqldf: dbGetQuery(connection, '", xi, "')\n", sep = "")
			}
			rs <- dbGetQuery(connection, xi)
		}
	} else {
		for(i in seq_along(x)) {
			if (length(words.[[i]]) > 0) {
				dbGetQueryWords <- c("select", "show", "call", "explain", 
					"with")
				if (tolower(words.[[i]][1]) %in% dbGetQueryWords || drv != "h2") {
					if (verbose) {
						cat("sqldf: dbGetQuery(connection, '", x[i], "')\n", sep = "")
					}
					rs <- dbGetQuery(connection, x[i])
				} else {
					if (verbose) {
						cat("sqldf: dbSendUpdate:", x[i], "\n")
					}
					rs <- get("dbSendUpdate")(connection, x[i])
				}
			}
		}
	}

	if (is.null(to.df)) to.df <- "auto"
    if (is.function(to.df)) return(to.df(rs))
	# to.df <- match.arg(to.df, c("auto", "raw", "name__class"))
	if (identical(to.df, "raw")) return(rs)
	if (identical(to.df, "name__class")) return(do.call("name__class", list(rs)))
	if (!identical(to.df, "nofactor") && !identical(to.df, "auto")) {
		return(do.call("colClass", list(rs, to.df)))
	}
	# process row_names
	row_names_name <- grep("row[_.]names", names(rs), value = TRUE)
	if (length(row_names_name) > 1) warning(paste("ambiguity regarding row names:", row_names_name))
	row_names_name <- row_names_name[1]
	# rs <- if ("row_names" %in% names(rs)) {
	rs <- if (!is.na(row_names_name)) {
		if (identical(row.names, FALSE)) {
			# subset(rs, select = - row_names)
			rs[names(rs) != row_names_name]
		} else { 
			rn <- rs[[row_names_name]]
			# rs <- subset(rs, select = - row_names)
			rs <- rs[names(rs) != row_names_name]
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
	# tab has one row for each column in each data frame with columns being: 
	# (1) data frame name, 
	# (2) column name, 
	# (3) class vector concatenated using toString,
	# (4) levels concatenated using toString
	#
	tab <- do.call("rbind", 
		lapply(dfnames, 
			# calculate tab for one data frame
			function(dfname) {
				df <- get(dfname, envir)
				nms <- names(df)
				do.call("rbind", 
					lapply(seq_along(df), 
						# calculate row in tab for one column of one data frame
						function(j) {
							column <- df[[j]]
							cbind(dfname, nms[j], toString(class(column)), 
								toString(levels(column)))
						}
					)
				)
			}
		)
	)
			
	# each row is a unique column name/class vector/levels combo
	tabu <- unique(tab[,-1,drop=FALSE])

	# dup is vector of column names that appear more than once in tabu.
	# Such column names have conflicting classes or levels and therefore
	# cannot form the basis of unique class and level assignments.
	dup <- unname(tabu[duplicated(tabu[,1]), 1])

	# cat("tab:\n")
	# print(tab)
	# cat("tabu:\n")
	# print(tabu)
	# cat("dup:\n")
	# print(dup)

	auto <- function(i) {
		cn <- colnames(rs)[[i]]
		if (! cn %in% dup && 
			(ix <- match(cn, tab[, 2], nomatch = 0)) > 0) {
			df <- get(tab[ix, 1], envir)
			if (inherits(df[[cn]], "ordered")) {
				if (identical(to.df, "auto")) {
					u <- unique(rs[[i]])
					levs <- levels(df[[cn]])
					if (all(u %in% levs))
						return(factor(rs[[i]], levels = levels(df[[cn]]), 
							ordered = TRUE))
					else return(rs[[i]])
				} else return(rs[[i]])
			} else if (inherits(df[[cn]], "factor")) {
				if (identical(to.df, "auto")) {
					u <- unique(rs[[i]])
					levs <- levels(df[[cn]])
					if (all(u %in% levs))
						return(factor(rs[[i]], levels = levels(df[[cn]])))
					else return(rs[[i]])
				} else return(rs[[i]])
			} else if (inherits(df[[cn]], "POSIXct"))
				return(as.POSIXct(rs[[i]]))
			else if (inherits(df[[cn]], "times")) 
				return(as.times.character(rs[[i]]))
			else {
				asfn <- paste("as", 
					class(df[[cn]]), sep = ".")
				asfn <- match.fun(asfn)
				return(asfn(rs[[i]]))
			}
		}
		if (stringsAsFactors && is.character(rs[[i]])) factor(rs[[i]])
		else rs[[i]]
	}
	# debug(f)
	rs2 <- lapply(seq_along(rs), auto)
	rs[] <- rs2
	rs
}


read.csv.sql <- function(file, sql = "select * from file", 
	header = TRUE, sep = ",", row.names, eol, skip, filter, nrows, field.types,
    colClasses, dbname = tempfile(), drv = "SQLite", ...) {
	file.format <- list(header = header, sep = sep)
	if (!missing(eol)) 
		file.format <- append(file.format, list(eol = eol))
	if (!missing(row.names)) 
		file.format <- append(file.format, list(row.names = row.names))
	if (!missing(skip)) 
		file.format <- append(file.format, list(skip = skip))
	if (!missing(filter)) 
		file.format <- append(file.format, list(filter = filter))
	if (!missing(nrows)) 
		file.format <- append(file.format, list(nrows = nrows))
	if (!missing(field.types)) 
		file.format <- append(file.format, list(field.types = field.types))
	if (!missing(colClasses))
		file.format <- append(file.format, list(colClasses = colClasses))
	pf <- parent.frame()

	if (missing(file) || is.null(file) || is.na(file)) file <- ""
	
    ## filesheet
    tf <- NULL
    if ( substring(file, 1, 7) == "http://" ||
         substring(file, 1, 6) == "ftp://" ) {

        tf <- tempfile()
		on.exit(unlink(tf), add = TRUE)
        # if(verbose)
        # cat("Downloading",
        #      dQuote.ascii(file), " to ",
        #      dQuote.ascii(tf), "...\n")
        download.file(file, tf, mode = "wb")
        # if(verbose) cat("Done.\n")
        file <- tf
      }

	p <- proto(pf, file = file(file))
	p <- do.call(proto, list(pf, file = file(file)))
	sqldf(sql, envir = p, file.format = file.format, dbname = dbname, drv = drv, ...)
}

read.csv2.sql <- function(file, sql = "select * from file", 
	header = TRUE, sep = ";", row.names, eol, skip, filter, nrows, field.types,
    colClasses, dbname = tempfile(), drv = "SQLite", ...) {

	if (missing(filter)) {
		filter <- if (.Platform$OS == "windows")
			paste("cscript /nologo", normalizePath(system.file("trcomma2dot.vbs", package = "sqldf")))
		else "tr , ."
	}

read.csv.sql(file = file, sql = sql, header = header, sep = sep, 
		row.names = row.names, eol = eol, skip = skip, filter = filter, 
		nrows = nrows, field.types = field.types, 
		colClasses = colClasses, dbname = dbname, drv = drv)
}
