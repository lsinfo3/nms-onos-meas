#!/usr/bin/env Rscript

# function calculation the throughput based on the ingoing or max bandwidth
#
# traffic: dataframe holding in- and outgoing bandwidth in kbit
# trafficLimit: defining the bandwidth limit for the network in kbit
# inName: header name of the ingoing bandwidth column for the traffic dataframe
# outName: header name of the outgoing bandwidth column for the traffic dataframe

getThroughput <- function(traffic, trafficLimit, inName, outName) {
  
  # remove zeros at the beginning and end
  traffic <- traffic[min( which( traffic[, inName] != 0)) : max( which( traffic[, inName] != 0)), ]
  # restrict in going traffic to bandwidth limit
  traffic[is.na(traffic[[inName]]), inName] <- 0
  traffic[traffic[[inName]] > trafficLimit, inName] <- trafficLimit
  
  # get quotient
  throughput <- data.frame("time"=traffic[, "time"])
  throughput[["throughput"]] <- traffic[[outName]]/traffic[[inName]]
  
  # remove na and nan values
  throughput[is.na(throughput[["throughput"]]) | is.nan(throughput[["throughput"]]), "throughput"] <- 0
  # max throughput is 1
  throughput[throughput[["throughput"]] > 1, "throughput"] <- 1
  
  return(throughput)
}