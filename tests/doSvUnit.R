#! /usr/bin/Rscript --vanilla --default-packages=utils,stats,methods,svUnit
pkg <- "sqldf"
require(svUnit)  # Needed if run from R CMD BATCH
require(pkg, character.only = TRUE)  # Needed if run from R CMD BATCH
# unlink("mypkgTest.txt")  # Make sure we generate a new report
mypkgSuite <- svSuiteList(pkg, excludeList = NULL)  # List all our test suites
runTest(mypkgSuite, name = "svUnit")  # Run them...
# protocol(Log(), type = "text", file = "mypkgTest.txt")  # ... and write report
Log()

