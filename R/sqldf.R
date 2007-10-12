
sqldf <- function(x, stringsAsFactors = TRUE, col.classes = NULL, 
   row.names = FALSE, envir = parent.frame(), method = c("auto", "raw"), 
   file.format = list(), dbname, drv = getOption("dbDriver")) {

   as.POSIXct.character <- function(x) structure(as.numeric(x),
	class = c("POSIXt", "POSIXct"))
   as.Date.character <- function(x) structure(as.numeric(x), class = "Date")
   as.dates.character <- function(x) structure(as.numeric(x), class = c("dates", "times"))
   as.times.character <- function(x) structure(as.numeric(x), class = "times")


	overwrite <- FALSE
	dfnames <- fileobjs <- character(0)
	on.exit({ 
		if (dbname == ":memory:") dbDisconnect(con)
		else if (!dbPreExists && drv == "SQLite") {
			# data base not pre-existing
			dbDisconnect(con)
			file.remove(dbname)
		} else {
			# data base pre-existing
			for (nam in dfnames) dbRemoveTable(con, nam)
			for (fo in fileobjs) dbRemoveTable(con, fo)
			dbDisconnect(con)
		}
	})

	if (is.null(drv)) {
		drv <- if ("package:RMySQL" %in% search()) "MySQL" 
		else "SQLite"
	}

	if (drv == "MySQL") {
		m <- dbDriver("MySQL")
		con <- if (missing(dbname)) { 
				dbConnect(m) 
			} else dbConnect(m, dbname = dbname)
			dbPreExists <- TRUE
	} else {
		m <- dbDriver("SQLite")
		if (missing(dbname)) dbname <- ":memory:"
		dbPreExists <- dbname != ":memory:" && file.exists(dbname)
		con <- dbConnect(m, dbname = dbname)
	}

	words <- strapply(x, "\\w+")
	if (length(words) > 0) words <- unique(words[[1]])
	is.special <- sapply(
		mget(words, envir, "any", NA, inherits = TRUE), 
		function(x) is.data.frame(x) + 2 * inherits(x, "file"))

	# process data frames
	dfnames <- words[is.special == 1]
	for(i in seq_along(dfnames)) {
		nam <- dfnames[i]
		if (dbPreExists && !overwrite && dbExistsTable(con, nam)) {
			# exit code removes tables in dfnames
			# so only include those added so far
			dfnames <- head(dfnames, i-1)
			stop(paste("sqldf:", "table", nam, 
				"already in", dbname, "\n"))
		}
		dbWriteTable(con, nam, as.data.frame(get(nam, envir)), 
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
		if (dbPreExists && !overwrite && dbExistsTable(con, Filename)) {
			# exit code should only remove tables added so far
			fileobjs <- head(fileobjs, i-1)
			stop(paste("sqldf:", "table", fo, "from file", 
				Filename, "already in", dbname, "\n"))
		}
		args <- c(list(conn = con, name = fo, value = Filename), 
			modifyList(list(eol = eol), file.format))
		args <- modifyList(args, as.list(attr(get(fo, envir), "file.format")))
		do.call("dbWriteTable", args)
	}

	# process select statement
	for(xi in x) rs <- dbGetQuery(con, xi)

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

