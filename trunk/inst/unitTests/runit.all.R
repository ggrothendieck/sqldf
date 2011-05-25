
library(svUnit)

test.all <- function() {

	# head
	a1r <- head(warpbreaks)
	a1s <- sqldf("select * from warpbreaks limit 6")
	checkIdentical(a1r, a1s)

	# subset / like
	a2r <- subset(CO2, grepl("^Qn", Plant))
	a2s <- sqldf("select * from CO2 where Plant like 'Qn%'")
	checkEquals(a2r, a2s, check.attributes = FALSE)

	# subset / in
	data(farms, package = "MASS")
	a3r <- subset(farms, Manag %in% c("BF", "HF"))
	a3s <- sqldf("select * from farms where Manag in ('BF', 'HF')")
	row.names(a3r) <- NULL
	checkIdentical(a3r, a3s)

	# subset / multiple inequality constraints
	a4r <- subset(warpbreaks, breaks >= 20 & breaks <= 30)
	a4s <- sqldf("select * from warpbreaks where breaks between 20 and 30", 
	   row.names = TRUE)
	checkIdentical(a4r, a4s)

	# subset
	a5r <- subset(farms, Mois == 'M1')
	a5s <- sqldf("select * from farms where Mois = 'M1'", row.names = TRUE)
	checkIdentical(a5r, a5s)

	# subset
	a6r <- subset(farms, Mois == 'M2')
	a6s <- sqldf("select * from farms where Mois = 'M2'", row.names = TRUE)
	checkIdentical(a6r, a6s)

	# rbind
	a7r <- rbind(a5r, a6r)
	a7s <- sqldf("select * from a5s union all select * from a6s")

	# sqldf drops the unused levels of Mois but rbind does not; however,
	# all data is the same and the other columns are identical
	row.names(a7r) <- NULL
	checkIdentical(a7r[-1], a7s[-1])

	# aggregate - avg conc and uptake by Plant and Type
	a8r <- aggregate(iris[1:2], iris[5], mean)
	a8s <- sqldf("select Species, avg(Sepal_Length) `Sepal.Length`, 
	   avg(Sepal_Width) `Sepal.Width` from iris group by Species")
	checkEquals(a8r, a8s)

	# by - avg conc and total uptake by Plant and Type
	a9r <- do.call(rbind, by(iris, iris[5], function(x) with(x,
		data.frame(Species = Species[1], 
			mean.Sepal.Length = mean(Sepal.Length),
			mean.Sepal.Width = mean(Sepal.Width),
			mean.Sepal.ratio = mean(Sepal.Length/Sepal.Width)))))
	row.names(a9r) <- NULL
	a9s <- sqldf("select Species, avg(Sepal_Length) `mean.Sepal.Length`,
		avg(Sepal_Width) `mean.Sepal.Width`, 
		avg(Sepal_Length/Sepal_Width) `mean.Sepal.ratio` from iris
		group by Species")
	checkEquals(a9r, a9s)

	# head - top 3 breaks
	a10r <- head(warpbreaks[order(warpbreaks$breaks, decreasing = TRUE), ], 3)
	a10s <- sqldf("select * from warpbreaks order by breaks desc limit 3")
	row.names(a10r) <- NULL
	checkIdentical(a10r, a10s)

	# head - bottom 3 breaks
	a11r <- head(warpbreaks[order(warpbreaks$breaks), ], 3)
	a11s <- sqldf("select * from warpbreaks order by breaks limit 3")
	# attributes(a11r) <- attributes(a11s) <- NULL
	row.names(a11r) <- NULL
	checkIdentical(a11r, a11s)

	# ave - rows for which v exceeds its group average where g is group
	DF <- data.frame(g = rep(1:2, each = 5), t = rep(1:5, 2), v = 1:10)
	a12r <- subset(DF, v > ave(v, g, FUN = mean))
	Gavg <- sqldf("select g, avg(v) as avg_v from DF group by g")
	a12s <- sqldf("select DF.g, t, v from DF, Gavg where DF.g = Gavg.g and v > avg_v")
	row.names(a12r) <- NULL
	checkIdentical(a12r, a12s)

	# same but reduce the two select statements to one using a subquery
	a13s <- sqldf("select g, t, v from DF d1, (select g as g2, avg(v) as avg_v from DF group by g) where d1.g = g2 and v > avg_v")
	checkIdentical(a12r, a13s)

	# same but shorten using natural join
	a14s <- sqldf("select g, t, v from DF natural join (select g, avg(v) as avg_v from DF group by g) where v > avg_v")
	checkIdentical(a12r, a14s)

	# table
	a15r <- table(warpbreaks$tension, warpbreaks$wool)
	a15s <- sqldf("select sum(wool = 'A'), sum(wool = 'B') 
	   from warpbreaks group by tension")
	checkEquals(as.data.frame.matrix(a15r), a15s, check.attributes = FALSE)

	# reshape
	t.names <- paste("t", unique(as.character(DF$t)), sep = "_")
	a16r <- reshape(DF, direction = "wide", timevar = "t", idvar = "g", varying = list(t.names))
	a16s <- sqldf("select g, sum((t == 1) * v) t_1, sum((t == 2) * v) t_2, sum((t == 3) * v) t_3, sum((t == 4) * v) t_4, sum((t == 5) * v) t_5 from DF group by g")
	checkEquals(a16r, a16s, check.attributes = FALSE)

	# order
	a17r <- Formaldehyde[order(Formaldehyde$optden, decreasing = TRUE), ]
	a17s <- sqldf("select * from Formaldehyde order by optden desc")
	row.names(a17r) <- NULL
	checkIdentical(a17r, a17s)

	# centered moving average of length 7
	set.seed(1)
	DF <- data.frame(x = rnorm(15, 1:15))
	s18 <- sqldf("select a.x x, avg(b.x) movavgx from DF a, DF b 
	   where a.row_names - b.row_names between -3 and 3 
	   group by a.row_names having count(*) = 7 
	   order by a.row_names+0", 
	 row.names = TRUE)
	r18 <- data.frame(x = DF[4:12,], movavgx = rowMeans(embed(DF$x, 7)))
	row.names(r18) <- NULL
	checkEquals(r18, s18)

	# merge.  a19r and a19s are same except row order and row names
	A <- data.frame(a1 = c(1, 2, 1), a2 = c(2, 3, 3), a3 = c(3, 1, 2))
	B <- data.frame(b1 = 1:2, b2 = 2:1)
	a19s <- sqldf("select * from A, B")
	a19r <- merge(A, B)
	Sort <- function(DF) DF[do.call(order, DF),]
	checkEquals(Sort(a19s), Sort(a19r), check.attributes = FALSE)

	# test system tables

	checkIdentical(dim(sqldf("pragma table_info(BOD)")), c(2L, 6L))

	sql <- c("select * from BOD", "select * from sqlite_master")
	checkIdentical(dim(sqldf(sql)), c(1L, 5L))

	checkTrue(sqldf("pragma database_list")$name == "main")

	DF <- data.frame(a = 1:2, b = 2:1)

	checkIdentical(sqldf("select a/b as quotient from DF")$quotient, c(0L, 2L))

	checkIdentical(sqldf("select (a+0.0)/b as quotient from DF")$quotient, c(0.5, 2.0))

	checkIdentical(sqldf("select cast(a as real)/b as quotient from DF")$quotient, c(0.5, 2.0))

	checkIdentical(sqldf(c("create table mytab(a real, b real)", 
	   "insert into mytab select * from DF",  
	   "select a/b as quotient from mytab"))$quotient, c(0.5, 2.0))

	tonum <- function(DF) replace(DF, TRUE, lapply(DF, as.numeric))
	checkIdentical(sqldf("select a/b as quotient from DF", method = list("auto", tonum))$quotient, c(0.5, 2.0))

}
