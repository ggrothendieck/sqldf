\name{sqldf}
\alias{sqldf}
\title{SQL select on data frames}
\description{
SQL select on data frames
}
\usage{

sqldf(x, stringsAsFactors = TRUE, col.classes = NULL, 
   row.names = FALSE, envir = parent.frame(), 
   method = getOption("sqldf.method"),
   file.format = list(), dbname, drv = getOption("sqldf.driver"), 
   user, password = "", host = "localhost",
   dll = getOption("sqldf.dll"), connection = getOption("sqldf.connection"))
}

\arguments{
  \item{x}{ Character string representing an SQL select statement or
   character vector whose components each represent a successive SQL
   statement to be executed. 
   The select statement syntax must conform to the particular database 
   being used.  If x is missing then it establishes a connection
   which subsequent sqldf statements access.  In that case the database
   is not destroyed until the next sqldf statement with no x.}
  \item{stringsAsFactors}{ If \code{TRUE} then output \code{"character"} 
   columns are 
   converted to \code{"factor"} if the heuristic is unable to determine 
   the class.
   If \code{method="raw"} then \code{stringsAsFactors} is ignored.}
  \item{col.classes}{ Not currently used.}
  \item{row.names}{For \code{TRUE} the tables in the data base are given
   a \code{row_names} column filled with the row names of the corresponding
   data frames.  Note that in SQLite a special \code{rowid} (or equivalently
   \code{oid} or \code{_rowid_}) is available in any case.}
  \item{envir}{ The environment where the data frames representing the tables
   are to be found.}
  \item{method}{\code{"auto"} means automatically assign the class of each
   column using the heuristic described later.  \code{"raw"} means use
   whatever classes are returned by the database with no automatic processing.
   If this argument is not specified the value of 
   \code{getOption("sqldf.method")}
   is used and if that is not specified either then \code{"auto"} is used.}
  \item{file.format}{A list whose components are passed to 
    \code{sqliteImportFile}.  Components may include \code{sep}, 
    \code{header}, \code{row.names}, \code{skip}, \code{eol} and \code{filter}.
    Except for \code{filter} they are passed to
    \code{sqliteImportFile} and have the same default values as 
    in \code{sqliteImportFile} (except for \code{eol} which defaults
    to the end of line character(s) for the operating system in use). 
    \code{filter} may optionally contain a batch/shell command through which the
    input file is piped prior to reading it in.
    \code{file.format} may be set to \code{NULL} in order not to search
    for input file objects at all.  The \code{file.format} can also
    be specified as an attribute in each file object itself in which case 
    such specification overrides any given through the argument list.  There
    is further discussion of \code{file.format} below.}
  \item{dbname}{Name of the database.  For SQLite data bases this defaults to
   \code{":memory:"} which results in an embedded database.}
  \item{drv}{\code{"SQLite"} or \code{"MySQL"}.  If not specified then
   the \code{"dbDriver"} option is checked and if that is not set then
   \code{"SQLite"} is used unless the RMySQL package is loaded.}
  \item{user}{user name.  Not needed for embedded databases.}
  \item{password}{password. Not needed for embedded databases.}
  \item{host}{host.  Default of "localhost" is normally sufficient.}
  \item{dll}{Name of an SQLite loadable extension to automatically load.
    Default is \code{"libspatial-1.dll"}.  If found on PATH then it is 
	automatically loaded and the SQLite functions it in will be accessible.}
  \item{connection}{If this is \code{NULL} then a connection is created;
   otherwise the indicated connection is used.  The default is
   the value of the option \code{sqldf.connection}.  If neither 
   \code{connection} nor \code{sqldf.connection} are specified a connection
   is automatically generated on-the-fly and closed on exit of the call to 
   \code{sqldf}.  If this argument is not \code{NULL} then the specified
   connection is left open on termination of the \code{sqldf} call.  Usually 
   this argument is left unspecified.  It can be used to make repeated calls
   to a database without reloading it.}
}
\details{
The typical action of \code{sqldf} is to 
\describe{
\item{create a database}{in memory}
\item{read in the data frames and files}{used in the select statement.  
This is done by scanning the select statement to see which words in 
the select statement are of class "data.frame" or "file" in the parent frame,  or the
specified environment if \code{envir} is used, and for each object
found by reading it into the database if it is a data frame.  Note
that this heuristic usually reads in the wanted data frames and files
but on occasion may harmlessly reads in extra ones too.}
\item{run the select statement}{getting the result as a data frame}
\item{assign the classes}{of the returned data frame's columns if
\code{method = "auto"}.  This is done by checking all the column
names in the read-in data frames and if any are the same
as in the output data frame their class (and their factor levels
if factor) is used.  If they are not matched then they are returned
as is except that if 
\code{stringsAsFactors = TRUE} then any character strings are converted
to factors.  If \code{method = "raw"} then the classes are returned
as is from the database and \code{stringsAsFactors} is ignored. }
\item{cleanup}{If the database was created by sqldf then it is deleted;
otherwise, all tables that were created are dropped in order to leave
the database in the same state that it was before.  The database
connection is terminated.}
}
Warning. Although sqldf is usually used with on-the-fly databases
which it automatically sets up and destroys if you wish to use it
with existing databases be sure to back up your database prior to
using it since incorrect operation could destroy the entire 
database.

}
\note{
If \code{row.names = TRUE} is used then 
any \code{NATURAL JOIN} will make use of it which may not be what was
intended.

3/2 and 3.0/2 are the same in R but in SQLite the first one
causes integer arithmetic to be used whereas the second using floating point.  
Thus both evaluate to 
1.5 in R but they evaluate to 1 and 1.5 respectively in SQLite.

The \code{dbWriteTable}/\code{sqliteImportFile} routines that sqldf uses to transfer files to the data base are intended for speed and they are not as flexible as \code{\link{read.table}}.  Also they have slightly different defaults. (If more flexible input is needed use the slower \code{read.table} to read the data into a data frame instead of reading directly from a file.)  The default for \code{sep} is \code{sep = ","}. If the first row of the file has one fewer entry than subsequent ones then it is assumed that \code{header <- row.names <- TRUE} and otherwise that \code{header <- row.names <- FALSE}. The \code{header} can be forced to \code{header <- TRUE} by specifying \code{file.format = list(header = TRUE)} as an argument to \code{sqldf.} \code{sep} and \code{row.names} are other \code{file.format} subarguments. Also, one limitation with .csv files is that quotes are not regarded as special within files so a comma within a data field such as \code{"Smith, James"} would be regarded as a field delimiter and the quotes would be entered as part of the data which probably is not what is intended.  

Typically the SQL result will have the same data as the analogous
non-database \code{R} code manipulations using data frames 
but may differ in row names and other attributes.  In the
examples below we use \code{identical} in those cases where the two
results are the same in all respects or set the row names to \code{NULL}
if they would have otherwise differed only in row names or use
\code{all.equal} if the data portion is the same but attributes aside
from row names differ.

The SQLite code has been tested but the MySQL code has only been partly
tested.  

On MySQL the database must pre-exist.  Create a \code{c:\\my.cnf} file 
on Windows or a \code{/etc/my.cnf}
file on UNIX to contain information about the database.  This file may 
include the username, password, database and port.  The password
can be omitted if one has not been set and the database can be omitted if
its passed as the \code{dbname} argument to \code{sqldf}.  The \code{port}
argument can usually be omitted as well.  See \url{http://dev.mysql.com/doc/refman/5.0/en/option-files.html}.

In versions of the \code{DBI} package prior to \code{DBI 0.2-5}, 
SQL reserved words such as 
\code{time} and \code{date} were automatically translated to 
\code{time__1} and \code{date__1}, etc. to prevent collisions.  The new version
of \code{DBI} used with the current version of sqldf automatically quotes those
variables instead so that the database will use the column names of \code{date}
and code{time} instead of \code{date__1} and \code{time__1}.  
The user moving from older versions of \code{sqldf} to this one 
should be aware of this change in \code{DBI}.  

If \code{getOption("sqldf.dll")}, defaulting to \code{"libspatial.dll"} 
is found on the PATH
then it will be loaded as an SQLite loadable extension.  With the default the
user will also have access to these additional SQL functions:
\url{http://www.gaia-gis.it/spatialite/spatialite-sql-2.3.1.html}
The sqldf package does not itself include this or any other dll and the user 
must download and place it on the PATH if they wish to use it.  The dll can
be found here:
\url{http://www.gaia-gis.it/spatialite}
If \code{sqldf} does not find the dll on the \code{PATH} then \code{sqldf} 
will continue to work 
but, of course, those functions will not be available.
If you add \code{libspatialite-1.dll} to your \code{PATH}
part way through your session then it will be necessary to set the 
\code{sqldf.dll} option to \code{NULL}: \code{options(sqldf.dll = NULL)} as 
well.

}

\value{
  The result of the specified select statement is output as a data frame.
  If a vector of sql statements is given as \code{x} then the result of
  the last one is returned.  If the \code{x} and \code{connection}
  arguments are missing then it returns a new connection and also places
  this connection in the option \code{sqldf.connection}.
  
}
\references{ 
The sqldf home page \url{http://code.google.com/p/sqldf/} contains
more examples as well as links to SQLite pages that may be helpful in 
formulating queries.
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

a2r <- subset(CO2, grepl("^Qn", Plant))
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
a7s <- sqldf("select * from a5s union all select * from a6s")
# sqldf drops the unused levels of Mois but rbind does not; however,
# all data is the same and the other columns are identical
row.names(a7r) <- NULL
identical(a7r[-1], a7s[-1])

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

# table
a15r <- table(warpbreaks$tension, warpbreaks$wool)
a15s <- sqldf("select sum(wool = 'A'), sum(wool = 'B') 
   from warpbreaks group by tension")
all.equal(as.data.frame.matrix(a15r), a15s, check.attributes = FALSE)

# reshape
t.names <- paste("t", unique(as.character(DF$t)), sep = "_")
a16r <- reshape(DF, direction = "wide", timevar = "t", idvar = "g", varying = list(t.names))
a16s <- sqldf("select g, sum((t == 1) * v) t_1, sum((t == 2) * v) t_2, sum((t == 3) * v) t_3, sum((t == 4) * v) t_4, sum((t == 5) * v) t_5 from DF group by g")
all.equal(a16r, a16s, check.attributes = FALSE)

# order
a17r <- Formaldehyde[order(Formaldehyde$optden, decreasing = TRUE), ]
a17s <- sqldf("select * from Formaldehyde order by optden desc")
row.names(a17r) <- NULL
identical(a17r, a17s)

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
all.equal(r18, s18)

# merge.  a19r and a19s are same except row order and row names
A <- data.frame(a1 = c(1, 2, 1), a2 = c(2, 3, 3), a3 = c(3, 1, 2))
B <- data.frame(b1 = 1:2, b2 = 2:1)
a19s <- sqldf("select * from A, B")
a19r <- merge(A, B)
Sort <- function(DF) DF[do.call(order, DF),]
all.equal(Sort(a19s), Sort(a19r), check.attributes = FALSE)

# within Date, of the highest quality records list the one closest 
# to noon.  Note use of two sql statements in one call to sqldf.

Lines <- "DeployID Date.Time LocationQuality Latitude Longitude
STM05-1 2005/02/28 17:35 Good -35.562 177.158
STM05-1 2005/02/28 19:44 Good -35.487 177.129
STM05-1 2005/02/28 23:01 Unknown -35.399 177.064
STM05-1 2005/03/01 07:28 Unknown -34.978 177.268
STM05-1 2005/03/01 18:06 Poor -34.799 177.027
STM05-1 2005/03/01 18:47 Poor -34.85 177.059
STM05-2 2005/02/28 12:49 Good -35.928 177.328
STM05-2 2005/02/28 21:23 Poor -35.926 177.314
"

DF <- read.table(textConnection(Lines), skip = 1,  as.is = TRUE,
 col.names = c("Id", "Date", "Time", "Quality", "Lat", "Long"))

sqldf(c("create temp table DFo as select * from DF order by
  Date DESC, Quality DESC,
  abs(substr(Time, 1, 2) + substr(Time, 4, 2) /60 - 12) DESC",
  "select * from DFo group by Date"))

\dontrun{

# test of file connections with sqldf

# create test .csv file of just 3 records
write.table(head(iris, 3), "iris3.dat", sep = ",", quote = FALSE)

# look at contents of iris3.dat
readLines("iris3.dat")

# set up file connection
iris3 <- file("iris3.dat")
sqldf("select * from iris3 where Sepal_Width > 3")

# using a non-default separator
# file.format can be an attribute of file object or an arg passed to sqldf
write.table(head(iris, 3), "iris3.dat", sep = ";", quote = FALSE)
iris3 <- file("iris3.dat")
sqldf("select * from iris3 where Sepal_Width > 3", file.format = list(sep = ";"))

# same but pass file.format through attribute of file object
attr(iris3, "file.format") <- list(sep = ";")
sqldf("select * from iris3 where Sepal_Width > 3")

# copy file straight to disk without going through R
# and then retrieve portion into R  
sqldf("select * from iris3 where Sepal_Width > 3", dbname = tempfile())

### same as previous example except it allows multiple queries against
### the database.  We use iris3 from before.  This time we use an
### in memory SQLite database.

sqldf() # open a connection
sqldf("select * from iris3 where Sepal_Width > 3")

# At this point we have an iris3 variable in both
# the R workspace and in the SQLite database so we need to
# explicitly let it know we want the version in the database.
# If we were not to do that it would try to use the R version
# by default and fail since sqldf would prevent it from 
# overwriting the version already in the database to protect
# the user from inadvertent errors.
sqldf("select * from main.iris3 where Sepal_Width > 4")
sqldf("select * from main.iris3 where Sepal_Width < 4")
sqldf() # close connection

### another way to do this is a mix of sqldf and RSQLite statements
### In that case we need to fetch the connection for use with RSQLite
### and do not have to specifically refer to main since RSQLite can
### only access the database.

con <- sqldf()
# this iris3 refers to the R variable and file
sqldf("select * from iris3 where Sepal_Width > 3")
# these iris3 refer to the database table
dbGetQuery(con, "select from iris3 where Sepal_Width > 4")
dbGetQuery(con, "select from iris3 where Sepal_Width < 4")
sqldf()


### demonstrate use of libspatial.dll loadable extension functions
### In this example stddev_pop and var_pop are libspatial functions.
### This will only work if libspatial.dll is on the PATH.
\dontrun{
Sys.which("libspatialite-1.dll") # shows location of spatialite on PATH
sqldf("select avg(demand) mean, stddev_pop(demand) sd, var_pop(demand) var from BOD")
with(BOD, c(mean = mean(demand), sd = sd(demand), var = var(demand)))

}

}

}
\keyword{manip}
