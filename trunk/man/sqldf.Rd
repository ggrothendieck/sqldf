\name{sqldf}
\alias{sqldf}
\title{ SQL select on data frames }
\description{
SQL select on data frames
}
\usage{
sqldf(..., stringsAsFactors = TRUE, col.classes = NULL, row.names = FALSE, 
   sep = " ", envir = parent.frame(), method = c("auto", "raw"), 
   drv = getOption("dbDriver"))
}
\arguments{
  \item{\dots}{ Character strings which are pasted together to form the
   select statement.  The select statement syntax must conform to the
   particular database being used.}
  \item{stringsAsFactors}{ If TRUE then output "character" columns are 
   converted to factor.}
  \item{col.classes}{ Not currently used.}
  \item{row.names}{ If \code{TRUE} then any \code{row_names} column in the output
   is used as the rownames in the output instead.  Otherwise any 
   \code{row_names} column is dropped.}
  \item{sep}{ A character string used for pasting together \dots. }
  \item{envir}{ The environment where the data frames representing the tables
   are to be found.}
  \item{method}{\code{"auto"} means automatically assign the class of each
   column using the heuristic described later.  \code{"raw"} means use
   whatever classes are returned by the database with no automatic processing.}
  \item{drv}{\code{"SQLite"} or \code{"MySQL"}.  If not specified then
   the \code{"dbDriver"} option is checked and if that is not set then
   \code{"SQLite"} is used unless the RMySQL package is loaded.}
}
\details{
  \code{sqldf} scans the select statement for tables, creates or accesses
  a database, reads data frames with the indicated table names into the 
  database, performs the
  select statement, converts the columns to appropriate classes,
  outputs the result as a data frame and deletes the
  database.  The select statement must use the syntax and expressions
  of the database, SQLite or MySQL, being used.
  In typical usage the only argument is the SQL statement.

  If the default \code{method = "auto"} is used then
  the classes used for the columns of the result are determined heuristically
  in a two step manner.  First a column of the same name is searched for
  in the input data frames and the class of that column is used if found.
  If that column is a factor or ordered factor its levels are also used.  
  If no column is found using this method then if the column is of character 
  class then it is converted to factor; otherwise, it is whatever class 
  came back from the database.  The second step, i.e. automatic conversion of 
  unmatched character columns to factor, can be disabled while still performing
  the first step by setting the \code{stringsAsFactors} argument 
  to \code{FALSE}.

  Note that if \code{row.names = TRUE} is used then 
  any \code{NATURAL JOIN} will make use of it which may not be what was
  intended.

  The SQLite code has been tested but the MySQL code has not.
}
\note{
  Typically the SQL result will have the same data as the corresponding
  \code{R} code but may differ in row names and other attributes.  In the
  examples below we use \code{identical} in those cases where the two
  results are the same in all respects or set the row names to \code{NULL}
  if they would have otherwise differed only in row names or use
  \code{all.equal} if the data portion is the same but attributes aside
  from row names differ.  

}
\value{
  The result of the specified select statement is output as a data frame.

}
\references{ 
The sqldf home page \url{http://code.google.com/p/batchfiles/} contains
links to SQLite pages that may be helpful in formulating queries.
}
\examples{

#
# These ecamples show how to run a variety of data frame manipulations
# in R without SQL and then again with SQL
#

# head
a1r <- head(warpbreaks)
a1s <- sqldf("select * from warpbreaks limit 6")
identical(a1r, a1s)

# subset

a2r <- subset(CO2, regexpr("Qn", Plant) > 0)
a2s <- sqldf("select * from CO2 where Plant like 'Qn\%'")
all.equal(a2r, a2s, check.attributes = FALSE)

data(farms, package = "MASS")
a3r <- subset(farms, Manag \%in\% c("BF", "HF"))
a3s <- sqldf("select * from farms where Manag in ('BF', 'HF')")
row.names(a3r) <- NULL
identical(a3r, a3s)

a4r <- subset(warpbreaks, breaks >= 20 & breaks <= 30)
a4s <- sqldf("select * from warpbreaks where breaks between 20 and 30", 
   row.names = TRUE)
identical(a4r, a4s)

a5r <- subset(farms, Mois == 'M1')
a5s <- sqldf("select * from farms where Mois = 'M1'", row.names = TRUE)
identical(a5r, a5s)

a6r <- subset(farms, Mois == 'M2')
a6s <- sqldf("select * from farms where Mois = 'M2'", row.names = TRUE)
identical(a6r, a6s)

# rbind
a7r <- rbind(a5r, a6r)
a7s <- sqldf("select * from a5s union all select * from a6s", row.names = TRUE)
identical(a7r, a7s)

# aggregate - avg conc and uptake by Plant and Type
a8r <- aggregate(iris[1:2], iris[5], mean)
a8s <- sqldf("select Species, avg(Sepal_Length) `Sepal.Length`, 
   avg(Sepal_Width) `Sepal.Width` from iris group by Species")
all.equal(a8r, a8s)

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
all.equal(a9r, a9s)

# head - top 3 breaks
a10r <- head(warpbreaks[order(warpbreaks$breaks, decreasing = TRUE), ], 3)
a10s <- sqldf("select * from warpbreaks order by breaks desc limit 3")
row.names(a10r) <- NULL
identical(a10r, a10s)

# head - bottom 3 breaks
a11r <- head(warpbreaks[order(warpbreaks$breaks), ], 3)
a11s <- sqldf("select * from warpbreaks order by breaks limit 3")
# attributes(a11r) <- attributes(a11s) <- NULL
row.names(a11r) <- NULL
identical(a11r, a11s)

# ave - rows for which v exceeds its group average where g is group
DF <- data.frame(g = rep(1:2, each = 5), t = rep(1:5, 2), v = 1:10)
a12r <- subset(DF, v > ave(v, g, FUN = mean))
Gavg <- sqldf("select g, avg(v) as avg_v from DF group by g")
a12s <- sqldf("select DF.g, t, v from DF, Gavg where DF.g = Gavg.g and v > avg_v")
row.names(a12r) <- NULL
identical(a12r, a12s)

# same but reduce the two select statements to one using a subquery
a13s <- sqldf("select g, t, v from DF d1, (select g as g2, avg(v) as avg_v from DF group by g) where d1.g = g2 and v > avg_v")
identical(a12r, a13s)

# same but shorten using natural join
a14s <- sqldf("select g, t, v from DF natural join (select g, avg(v) as avg_v from DF group by g) where v > avg_v")
identical(a12r, a14s)

# reshape
t.names <- paste("t", unique(as.character(DF$t)), sep = "_")
a15r <- reshape(DF, direction = "wide", timevar = "t", idvar = "g", varying = list(t.names))
a15s <- sqldf("select g, sum((t == 1) * v) t_1, sum((t == 2) * v) t_2, sum((t == 3) * v) t_3, sum((t == 4) * v) t_4, sum((t == 5) * v) t_5 from DF group by g")
all.equal(a15r, a15s, check.attributes = FALSE)

# order
a16r <- Formaldehyde[order(Formaldehyde$optden, decreasing = TRUE), ]
a16s <- sqldf("select * from Formaldehyde order by optden desc")
row.names(a16r) <- NULL
identical(a16r, a16s)

}
\keyword{manip}
