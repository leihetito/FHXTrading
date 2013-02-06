rm(list=ls(all=TRUE))
DRIVE <- Sys.getenv("HOME")  # create your project directory relative to HOME
WD <- paste(DRIVE,"/FHX/workspace_R/FHX_model/",sep="") # working dir
inDataDir <- paste(DRIVE, "/data/statstream/",sep="")
outDataDir <- paste(DRIVE, "/data/statstream/",sep="")
source(paste(WD,"dft_statstream_func.r",sep=""))

corr_output <- process_sliding_window(1,WD,inDataDir,outDataDir)
