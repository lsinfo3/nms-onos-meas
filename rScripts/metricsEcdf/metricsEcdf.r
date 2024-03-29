#!/usr/bin/env Rscript

library(ggplot2)
library(reshape2)

# remove all objects in workspace
rm(list=ls())

# get commandline args
args <- commandArgs(trailingOnly = TRUE)

# default values
csvFiles <- ""
values <- ""
parameterName <- ""
outFilePath <- "./out"

if(length(args) >= 1){
  csvFiles <- strsplit(as.character(args[1]), " ")[[1]]
}
if(length(args) >= 2){
  values <- strsplit(as.character(args[2]), " ")[[1]]
}
if(length(args) >= 3){
  parameterName <- as.character(args[3])
}
if(length(args) >= 4){
  outFilePath <- as.character(args[4])
}
rm(args)


# --- create file and value vector ---
detail=FALSE
folderName="nmsInt"
#folders=seq(20, 60, by=10)
#folders=c(4, 8, 16, 32, 64)
#folders=c("udp", "tcp")
folders=c(10, seq(30, 120, by=30))
numMeas=10
parameterName <- "Update Interval"

#tempFiles <- c("avg10/1.csv", "avg10/2.csv")
#tempValues <- c("10", "10")

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

#tempFiles <- c("10/1.csv", "10/2.csv", "10/3.csv", "10/4.csv", "10/5.csv", "10/6.csv", "10/7.csv", "10/8.csv", "10/9.csv", "10/10.csv")
#tempValues <- c("10", "10", "10", "10", "10", "10", "10", "10", "10", "10")

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

# get load measurement file names
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

csvFiles <- tempFiles
values <- tempValues
loadCsv <- tempLoadFiles
loadValues <- tempLoadValues
rm(tempFiles, tempLoadFiles, tempValues, tempLoadValues, i, j, folders, numMeas)


# get load measurement values
for(i in 1:length(loadCsv)) {
  loadPart <- read.csv(loadCsv[i], header=TRUE, sep=",", quote="\"", dec=".", fill=TRUE)
  loadPart[["parameter"]] <- loadValues[i]
  
  # remove non convertible time columns
  loadPart <- loadPart[ !is.na(as.numeric(loadPart[, "time"])), ]
  
  # normalize time values to begin with 0
  minTime = min(floor(as.numeric(loadPart[, "time"])))
  loadPart[, "time"] <- floor(as.numeric(loadPart[, "time"])) - minTime
  
  # change onosLoad data into long format
  colnames(loadPart)[colnames(loadPart)=="cpu"] <- "cpuLoad"
  loadPart <- melt(loadPart,
                   id.vars=c("parameter", "time"),
                   measure.vars="cpuLoad")
  loadPart <- loadPart[, c("parameter", "variable", "value")]
  
  # build average if no detail information is wished
  if(detail==FALSE) {
    loadPart <- data.frame("parameter"=loadValues[i],
                           "variable"="cpuLoad",
                           "value"=mean(loadPart[, "value"], na.rm=TRUE))
  }
  
  if(exists("onosLoad")) {
    onosLoad <- rbind(onosLoad, loadPart)
  } else {
    onosLoad <- loadPart
  }
}
rm(loadPart)

# combine all csv data into wide format
for(i in 1:length(csvFiles)) {
  metricsPart <- read.csv(csvFiles[i], header=TRUE, sep=",", quote="\"", dec=".", fill=TRUE)
  metricsPart[["parameter"]] <- values[i]
  
  if(exists("metrics")) {
    metrics <- rbind(metrics, metricsPart)
  } else {
    metrics <- metricsPart
  }
}
rm(metricsPart)

rm(csvFiles, loadCsv, values, loadValues)


metrics2 <- metrics
# normalize reallocations
#metrics[, "reallocations"] <- (1/(metrics[, "reallocations"]+1))^(1/10)
#metrics[, "reallocations"] <- (1/(metrics[, "reallocations"]+1))
#metrics[["reallocations"]] <- NULL

# combine data into long format
metrics <- melt(metrics[2:ncol(metrics)], measure.vars=1:(ncol(metrics)-2), id="parameter")
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

# round the values to max 3 digits
myBreaks <- function(x){
  precission <- 1
  fac <- 10^precission # factor
  breaks <- c(ceiling(min(x)*fac)/fac,round(median(x),precission),floor(max(x)*fac)/fac)
  while(length(unique(breaks)) < length(unique(x))+1) {
    precission <- precission + 1
    fac <- 10^precission # factor
    breaks <- c(ceiling(min(x)*fac)/fac,round(median(x),precission),floor(max(x)*fac)/fac)
  }
  if(breaks[1] < 0){
    breaks[1] <- 0
  }
  names(breaks) <- attr(breaks,"labels")
  breaks
}
myFacetLabeler <- function(variable, value) {
  return(paste("Interval=", value, "s", sep=""))
}

# set factor
#metrics[["parameter"]] <- factor(metrics[["parameter"]], levels=c('4', '6', '8', '10', '12'))
metrics[["parameter"]] <- factor(metrics[["parameter"]], levels=c('10', '30', '60', '90', '120'))
#metrics[["parameter"]] <- factor(metrics[["parameter"]], levels=c('20', '30', '40', '50', '60'))
#metrics[["parameter"]] <- factor(metrics[["parameter"]], levels=c('40', '60', '80', '100', '120'))
#metrics[["parameter"]] <- factor(metrics[["parameter"]], levels=c('4', '8', '12', '16', '20'))
#metrics[["parameter"]] <- factor(metrics[["parameter"]], levels=c('4', '8', '16', '32', '64'))
#metrics[["parameter"]] <- factor(metrics[["parameter"]], levels=c('tcp', 'udp'))

figure <- ggplot(data=metrics, aes(x=value, color=parameter)) +
  stat_ecdf(geom="step", na.rm=TRUE) +
  facet_grid(. ~ variable, scales="free_x")
if(detail == TRUE) {
  figure <- figure +
    scale_x_continuous(breaks=c(0, .5, .75, .875, 1.0), trans=scales::exp_trans(exp(3)))
}
figure <- figure +  
  labs(x="Metric Values", y="Cumulative Probability") +
  theme_bw() +
  scale_color_manual(name=parameterName, labels=labels, values=colorRampPalette(c("blue", "red"))(5)) +
  theme(axis.text.x=element_text(angle=45, hjust=1, vjust=1), text = element_text(size=12),
        panel.spacing.x = unit(0.75, "lines"), legend.position = "bottom")

# save plot as pdf
width <- 15.0; height <- 8.0
ggsave(paste(outFilePath, "_ecdf.pdf", sep=""), plot = figure, width = width, height = height, units="cm")


figure <- ggplot(data=metrics, aes(x=parameter, y=value, group=1)) +
  stat_summary(geom="ribbon", fun.data=mean_cl_normal, 
               fun.args=list(conf.int=0.95), fill="lightblue") +
  stat_summary(geom="line", fun.y=mean, linetype="dashed") +
  stat_summary(geom="point", fun.y=mean, color="red") +
  facet_grid(. ~ variable, scales="free_x") +
  labs(x="Parameters", y="Metric Values") +
  theme_bw() +
  theme(axis.text.x=element_text(angle=45, hjust=1, vjust=1), text = element_text(size=12),
        panel.spacing.x = unit(0.75, "lines"), legend.position = "right")

# save plot as pdf
width <- 15.0; height <- 8.0
ggsave(paste(outFilePath, "_conf.pdf", sep=""), plot = figure, width = width, height = height, units="cm")