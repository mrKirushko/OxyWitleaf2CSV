#!/usr/bin/env Rscript
# Witleaf PuseOxymeter data plot generation script.

#
#   Copyright (C) Kirill Raguzin, 2024.
#
#   This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by the
#   Free Software Foundation; either version 2, or (at your option) any later
#   version.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
#   Public License for more details.
#

# --- Initial setup ---
# Device name. gets added to the header of the graph.
source_device_info = "Witleaf WIT-S300 Pulse Oxymeter, DC: 2019-12, S/N: H3001912012"
# More screen-friendly and smooth graphics. May not be the best for printed documents though.
use_Cairo = FALSE
# Setting the file name if passing it as a script parameter is inconvenient.
# May be useful for debug as well.
#input_file = "patient.csv" 
# ---------------------

if (!exists("input_file")) {
    args = commandArgs(TRUE)
    if (length(args) != 1) stop("Got incorrect amount of arguments!")
    input_file = args[1]
    if (!nchar(input_file)) stop("Input file name is too short!")
}

data = read.csv2(input_file, header=TRUE, col.names=c("SECT","TS","SpO2","PR"))
data$TS = as.POSIXct(data$TS,format="%Y-%m-%dT%H:%M:%OS")

# Dual axis plots
if (!require("plotrix")) {
    install.packages("plotrix")
    library(plotrix) # Throw an error if the package is still missing
}

# Smooth plots
if (use_Cairo) {
    if (!require("Cairo")) {
        install.packages("Cairo")
        library(Cairo) # Throw an error if the package is still missing
    }
    #CairoX11(width=8, height=6) # Useful for debug
}

plot_data = function(p_data, png_name) {
    if (use_Cairo)
        CairoPNG(png_name, width=1050, height=600, pointsize = 15)
    else
        png(png_name, width = 1050, height = 600, pointsize = 15)
    TS = p_data$TS; SpO2 = p_data$SpO2; PR = p_data$PR;
    twoord.plot(TS, SpO2, TS, PR,
                xlab=NA,
                ylab="SpO2 (%)",rylab="PR (BPM)", lcol=4,
                type="l", lwd=3, xaxt="n",
                main=paste(
                    source_device_info,
                    paste(format(TS[1], "record start: %d.%m.%Y %H:%M:%S, "),
                        signif(as.numeric(max(TS)-min(TS), units="mins"), 4),
                        " minutes recorded",
                        sep=""),
                    paste("MIN/MAX/AVG: ",
                        "SpO2(%) ", min(SpO2), "/", max(SpO2), "/", round(mean(SpO2)), ", ",
                        "PR(BPM) ", min(PR), "/", max(PR), "/", round(mean(PR)),
                        sep=""),
                    sep="\n"),
                do.first="grid(nx=NA, ny=NULL)")

    abline(v=axis.POSIXct(side=1, line=0.1,
            at=seq(min(TS), max(TS), (max(TS)-min(TS))/6),
            format = "%d.%m.%Y\n%H:%M:%S", mgp = c(3, 2, 0)),
            col = "lightgray", lty = "dotted", lwd = par("lwd"))
    dev.off()
}

sects = c(1:max(data$SECT))
for(sect in sects) {
    cat(paste("Generating plot",sect,".png...\n", sep=""))
    plot_data(data[data$SECT == sect,], paste("plot",sect,".png", sep=""))
}
