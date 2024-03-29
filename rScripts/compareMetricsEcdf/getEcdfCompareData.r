#!/usr/bin/env Rscript


getEcdfCompareData <- function(detail, folderName, folders, numMeas, parameterName) {

  for(folderName in folderNames) {
    
    # get average csv file names
    if(detail == FALSE) {
      for(i in folders) {
        for(j in seq(1, 1)) {
          if(exists("tempFiles")) {
            tempFiles <- c(tempFiles, paste(folderName, "/", i, "/metrics.csv", sep=""))
          } else {
            tempFiles <- c(paste(folderName, "/", i, "/metrics.csv", sep=""))
          }
        }
        if(exists("tempValues")) {
          tempValues <- c(tempValues, rep(toString(i), 1))
        } else {
          tempValues <- c(rep(toString(i), 1))
        }
      }
    }
    
    # get detailed csv file names
    if(detail == TRUE) {
      for(i in folders) {
        for(j in seq(1, numMeas)) {
          if(exists("tempFiles")) {
            tempFiles <- c(tempFiles, paste(folderName, "/", i, "/", j, "/metrics_detail.csv", sep=""))
          } else {
            tempFiles <- c(paste(folderName, "/", i, "/", j, "/metrics_detail.csv", sep=""))
          }
        }
        if(exists("tempValues")) {
          tempValues <- c(tempValues, rep(toString(i), numMeas))
        } else {
          tempValues <- c(rep(toString(i), numMeas))
        }
      }
    }
    
    # get load measurement csv file names
    for(i in folders) {
      for(j in seq(1, numMeas)) {
        if(exists("tempLoadFiles")) {
          tempLoadFiles <- c(tempLoadFiles, paste(folderName, "/", i, "/", j, "/systemLoad.csv", sep=""))
        } else {
          tempLoadFiles <- c(paste(folderName, "/", i, "/", j, "/systemLoad.csv", sep=""))
        }
      }
      if(exists("tempLoadValues")) {
        tempLoadValues <- c(tempLoadValues, rep(toString(i), numMeas))
      } else {
        tempLoadValues <- c(rep(toString(i), numMeas))
      }
    }
    
    
    if(!exists("metricCsv")) {
      metricCsv <- tempFiles
    } else {
      metricCsv <- c(metricCsv, tempFiles)
    }
    
    if(!exists("metricValues")) {
      metricValues <- tempValues
    } else {
      metricValues <- c(metricValues, tempValues)
    }
    
    if(!exists("loadCsv")) {
      loadCsv <- tempLoadFiles
    } else {
      loadCsv <- c(loadCsv, tempLoadFiles)
    }
    
    if(!exists("loadValues")) {
      loadValues <- tempLoadValues
    } else {
      loadValues <- c(loadValues, tempLoadValues)
    }
    
    if(!exists("metricMeasName")) {
      metricMeasName <- rep(folderName, length(tempFiles))
    } else {
      metricMeasName <- c(metricMeasName, rep(folderName, length(tempFiles)))
    }
    
    if(!exists("loadMeasName")) {
      loadMeasName <- rep(folderName, length(tempLoadFiles))
    } else {
      loadMeasName <- c(loadMeasName, rep(folderName, length(tempLoadFiles)))
    }
    
    rm(tempFiles, tempLoadFiles, tempValues, tempLoadValues, i, j)
    
  }
  
  rm(folders, numMeas)
  
  
  # get load measurement values
  for(i in 1:length(loadCsv)) {
    if(file.exists(loadCsv[i])){
    loadPart <- read.csv(loadCsv[i], header=TRUE, sep=",", quote="\"", dec=".", fill=TRUE)
    loadPart[["parameter"]] <- loadValues[i]
    loadPart[["measurement"]] <- loadMeasName[i]
    
    # remove non convertible time columns
    loadPart <- loadPart[ !is.na(as.numeric(loadPart[, "time"])), ]
    
    # normalize time values to begin with 0
    minTime = min(floor(as.numeric(loadPart[, "time"])))
    loadPart[, "time"] <- floor(as.numeric(loadPart[, "time"])) - minTime
    
    # change onosLoad data into long format
    colnames(loadPart)[colnames(loadPart)=="cpu"] <- "cpuLoad"
    loadPart <- melt(loadPart,
                     id.vars=c("parameter", "measurement", "time"),
                     measure.vars="cpuLoad")
    loadPart <- loadPart[, c("parameter", "measurement", "variable", "value")]
    
    # build average if no detail information is wished
    if(detail==FALSE) {
      loadPart <- data.frame("parameter"=loadValues[i],
                             "variable"="cpuLoad",
                             "value"=mean(loadPart[, "value"], na.rm=TRUE),
                             "measurement"=loadMeasName[i])
    }
    
    if(exists("onosLoad")) {
      onosLoad <- rbind(onosLoad, loadPart)
    } else {
      onosLoad <- loadPart
    }
    }
  }
  rm(loadPart)
  
  
  # combine all csv data into wide format
  for(i in 1:length(metricCsv)) {
    metricsPart <- read.csv(metricCsv[i], header=TRUE, sep=",", quote="\"", dec=".", fill=TRUE)
    metricsPart[["parameter"]] <- metricValues[i]
    metricsPart[["measurement"]] <- metricMeasName[i]
    
    if(exists("metrics")) {
      metrics <- rbind(metrics, metricsPart)
    } else {
      metrics <- metricsPart
    }
  }
  rm(metricsPart)
  
  rm(metricCsv, loadCsv, metricValues, loadValues, metricMeasName, loadMeasName)
  
  
  metrics2 <- metrics
  # normalize reallocations
  #metrics[, "reallocations"] <- (1/(metrics[, "reallocations"]+1))^(1/10)
  #metrics[, "reallocations"] <- (1/(metrics[, "reallocations"]+1))
  #metrics[["reallocations"]] <- NULL
  
  # combine data into long format
  metrics <- melt(metrics, measure.vars=2:(ncol(metrics)-2), id.vars=c("parameter", "measurement", "time"))
  metrics <- metrics[, c("parameter", "measurement", "variable", "value")]
  metrics <- rbind(metrics, onosLoad)
  
  # remove rows with NA values
  metrics <- metrics[ !is.na(metrics[["value"]]), ]
  
  # set max value to 1
  metrics[metrics[["value"]] > 1 & metrics[["variable"]] != "reallocations", "value"] <- 1
  # set levels of dataframe
  if(detail==TRUE) {
    
  }
  
  labels <- c(throughput="Throughput",
              linkFairness="Link Fairness",
              flowFairness="Flow Fairness")
  if(detail==TRUE) {
    labels <- c(labels, cpuLoad="CPU Load")
  } else {
    labels <- c(labels, reallocations="Reallocations", cpuLoad="CPU Load")
  }
  levels(metrics$variable) <- labels
  #setattr(metrics$variable, "levels", labels)

return(metrics)
}