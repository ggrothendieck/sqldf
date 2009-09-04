
sqldf <- function(x, stringsAsFactors = TRUE, col.classes = NULL, 
   row.names = FALSE, envir = parent.frame(), method = c("auto", "raw"), 
   file.format = list(), dbname, drv = getOption("sqldf.driver"), 
   connection = getOption("sqldf.connection")) {

   as.POSIXct.character <- function(x) structure(as.numeric(x),
	class = c("POSIXt", "POSIXct"))
   as.Date.character <- function(x) structure(as.numeric(x), class = "Date")
   as.dates.character <- function(x) structure(as.numeric(x), class = c("dates", "times"))
   as.times.character <- function(x) structure(as.numeric(x), class = "times")


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
    		if (dbname == ":memory:") dbDisconnect(connection)
    		else if (!dbPreExists && drv == "SQLite") {
    			# data base not pre-existing
    			dbDisconnect(connection)
    			file.remove(dbname)
    		} else {
    			# data base pre-existing
    			for (nam in dfnames) dbRemoveTable(connection, nam)
    			for (fo in fileobjs) dbRemoveTable(connection, fo)
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
    		drv <- if ("package:RMySQL" %in% search()) "MySQL" 
    		else "SQLite"
    	}
    
    	if (drv == "MySQL") {
    		m <- dbDriver("MySQL")
    		connection <- if (missing(dbname)) { 
    				dbConnect(m) 
    			} else dbConnect(m, dbname = dbname)
    			dbPreExists <- TRUE
    	} else {
    		m <- dbDriver("SQLite")
    		if (missing(dbname)) dbname <- ":memory:"
    		dbPreExists <- dbname != ":memory:" && file.exists(dbname)
    		connection <- dbConnect(m, dbname = dbname)
    	}
		attr(connection, "dbPreExists") <- dbPreExists
		if (missing(dbname) && drv == "SQLite") dbname <- ":memory:"
		attr(connection, "dbname") <- dbname
    	if (request.open) {
			options(sqldf.connection = connection)
			return(connection)
		}
	}

	if (request.con) dbPreExists <- attr(connection, "dbPreExists")

	words <- strapply(x, "[[:alnum:]._]+")
	if (length(words) > 0) words <- unique(words[[1]])
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
		nam2 <- if (regexpr(".", nam, fixed = TRUE)) {
			paste("`", nam, "`", sep = "")
		} else nam
		dbWriteTable(connection, nam2, as.data.frame(get(nam, envir)), 
			row.names = row.names)
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
		do.call("dbWriteTable", args)
	}

	# process select statement
	for(xi in x) rs <- dbGetQuery(connection, xi)

	# get result back
	if (match.arg(method) == "raw") return(rs)
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
	cn <- colnames(rs)
	rs2 <- lapply(colnames(rs), function(cn) {
		for(dfname in dfnames) {
			df <- get(dfname, envir)
			if (cn %in% colnames(df)) {
				cls <- class(df[[cn]])
				if (inherits(df[[cn]], "ordered"))
					return(as.ordered(factor(rs[[cn]], 
						levels = levels(df[[cn]]))))
				else if (inherits(df[[cn]], "factor"))
					return(factor(rs[[cn]], 
						levels = levels(df[[cn]])))
				else if (inherits(df[[cn]], "POSIXct"))
					return(as.POSIXct(rs[[cn]]))
				else {
					asfn <- paste("as", 
						class(df[[cn]]), sep = ".")
					asfn <- match.fun(asfn)
					return(asfn(rs[[cn]]))
				}
			}
		}
		if (stringsAsFactors) 
			if (is.character(rs[[cn]]))
				factor(rs[[cn]])
			else rs[[cn]]
	})
	rs[] <- rs2
	rs
}


read.csv.sql <- function(file, sql = "select * from file", 
	header = TRUE, sep = ",", row.names, eol, skip, dbname = tempfile(), ...) {
	file.format <- list(header = header, sep = sep)
	if (!missing(eol)) 
		file.format <- append(file.format, list(eol = eol))
	if (!missing(row.names)) 
		file.format <- append(file.format, list(row.names = row.names))
	if (!missing(skip)) 
		file.format <- append(file.format, list(skip = skip))
	pf <- parent.frame()
	p <- proto(pf, file = file(file))
	p <- do.call(proto, list(pf, file = file(file)))
	sqldf(sql, envir = p, file.format = file.format, dbname = dbname, ...)
}

read.csv2.sql <- function(file, sql = "select * from file", 
	header = TRUE, sep = ";", row.names, eol, skip, dbname = tempfile(), ...) {

	read.csv.sql(file = file, sql = sql, header = header, sep = sep, 
		row.names = row.names, eol = eol, skip = skip, dbname = dbname)
}
