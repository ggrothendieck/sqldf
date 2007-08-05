
sqldf <- function(x, stringsAsFactors = TRUE, col.classes = NULL, 
   row.names = FALSE, envir = parent.frame(), method = c("auto", "raw"), 
   file.format = list(), overwrite = FALSE, 
   dbname, drv = getOption("dbDriver")) {
	on.exit({ 
		dbDisconnect(con)
		if (!dbPreExists && drv == "SQLite" && dbname != ":memory:")
			file.remove(dbname)
	})

	if (is.null(drv)) {
		drv <- if ("package:RMySQL" %in% search()) "MySQL" 
		else "SQLite"
	}

	if (drv == "MySQL") {
		m <- dbDriver("MySQL")
		con <- dbConnect(m) 
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
	dfnames <- words[is.special == 1]
	for(nam in dfnames) {
		if (dbPreExists && !overwrite && dbExistsTable(con, nam))
			stop(paste("sqldf:", "table", nam, 
				"already in", dbname, "\n"))
		dbWriteTable(con, nam, as.data.frame(get(nam, envir)), 
			row.names = row.names)
	}
	filenames <- if (is.null(file.format)) character(0)
	else {
		eol <- if (.Platform$OS == "windows") "\r\n" else "\n"
		words[is.special == 2]
	}

	for(nam in filenames) {
		Filename <- summary(get(nam, envir))$description
		if (dbPreExists && !overwrite && dbTableExists(con, Filename))
			stop(paste("sqldf:", "table", nam, "from file", 
				Filename, "already in", dbname, "\n"))
		args <- c(list(conn = con, name = nam, value = Filename), 
			modifyList(list(eol = eol), file.format))
		args <- modifyList(args, as.list(attr(nam, "file.format")))
		do.call("dbWriteTable", args)
	}
	rs <- dbGetQuery(con, x)
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

