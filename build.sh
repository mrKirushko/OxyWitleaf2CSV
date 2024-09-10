#!/bin/sh
#===============================================================================

#set -o nounset                             # Treat unset variables as an error
dmd -O -release oxywitleaf2csv.d -w -wi -vcolumns -ofoxywitleaf2csv

read -rsp $'Press enter to exit...\n'
