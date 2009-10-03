\name{read.csv.sql}
\Rdversion{1.1}
\alias{read.csv.sql}
\alias{read.csv2.sql}
\title{
Read File Filtered by SQL
}
\description{
Read a file into R filtering it with an sql statement.  Only the filtered
portion is processed by R so that files larger than R can otherwise
handle can be accommodated.
}
\usage{
read.csv.sql(file, sql = "select * from file", header = TRUE, sep = ",", row.names, eol, skip, filter, dbname = tempfile(), ...)
read.csv2.sql(file, sql = "select * from file", header = TRUE, sep = ";", row.names, eol, skip, filter, dbname = tempfile(), ...)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{file}{
As in \code{read.csv}.
}
  \item{sql}{
character string holding an SQL statement.  The table representing the
file should be referred to as \code{file}.
}
  \item{header}{
As in \code{read.csv}.
}
  \item{sep}{
As in \code{read.csv}.
}
  \item{row.names}{
As in \code{read.csv}.
}
  \item{eol}{
Character which ends line.
}
  \item{skip}{
Skip indicated number of lines in input file.
}
  \item{filter}{
If specified, this should be a shell/batch command that the input file is piped through.  For \code{read.csv2.sql} it is by default the following on non-Windows systems: \code{tr , .}.  This translates all commas in the file to dots. On Windows similar functionalty is provided but to do that using a vbscript file that is included with \code{sqldf} to emulate the \code{tr} command.
}
  \item{dbname}{
As in \code{sqldf} except that the default is \code{tempfile()}.
}
  \item{\dots}{
Passed to \code{sqldf}.
}
}
\details{
Reads the indicated file into an sql database creating the database
if it does not already exist.  Then it applies the sql statement
returning the result as a data frame.  If the database did not exist
prior to this statement it is removed.  

Note that it uses facilities of \code{SQLite} to read the file 
which are intended for speed and therefore
not as flexible as in R.  For example, it does not
recognize quoted fields as special but will regard the quotes as 
part of the field. See the
\code{sqldf} help for more information.

\code{read.csv2.sql} is like \code{read.csv.sql} except
the default \code{sep} is \code{";"} and the default \code{filter} translates
all commas in the file to decimal points (i.e. to dots).

On Windows, if the \code{filter} argument is used and if Rtools is detected
in the registry then the Rtools bin directory is added to the search path
facilitating use of those tools without explicitly setting any the path.
}
\value{
If the sql statement is a select statement then a data frame
is returned.
}

\examples{
\dontrun{
write.table(iris, "iris.csv", sep = ",", quote = FALSE, row.names = FALSE)
iris2 <- read.csv.sql("iris.csv", 
	sql = "select * from file where Sepal.Length > 5")
}
}
\keyword{ manip }
