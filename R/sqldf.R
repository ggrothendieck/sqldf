
# note that column names with . in them must be referenced using underscore
# in place of dot since dot is meaningful in SQL
sqldf <- function(..., stringsAsFactors = TRUE, col.classes = NULL, 
   row.names = FALSE, sep = " ", envir = parent.frame(), 
   method = c("auto", "raw"), drv = getOption("dbDriver")) {
	on.exit(dbDisconnect(con))

	if (is.null(drv)) {
		drv <- if ("package:RMySQL" %in% search()) "MySQL" 
		else "SQLite"
	}

	if (drv == "MySQL") {
		m <- dbDriver("MySQL")
		con <- dbConnect(m) 
	} else {
		m <- dbDriver("SQLite")
		con <- dbConnect(m, dbname = ":memory:") 
	}
	
	s <- paste(..., sep = sep)
	words <- strapply(s, "\\w+")
	if (length(words) > 0) words <- unique(words[[1]])
	is.df <- sapply(
		mget(words, envir, "any", NA, inherits = TRUE), 
		is.data.frame)
	dfnames <- words[is.df]
	for(nam in dfnames) 
		dbWriteTable(con, nam, as.data.frame(get(nam, envir)), row.names = row.names)
	rs <- dbGetQuery(con, s)
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

