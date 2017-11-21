require(dplyr)
require(stringr)
rm(list = ls())

multmerge = function(mypath){
  filenames = list.files(path = mypath, full.names = TRUE)
  datalist = lapply(filenames, function(x){read.table(file = x,header = F)})
  merged.list = datalist[[1]]
  for (item in datalist[-1]) {
    merged.list <- full_join(merged.list, item, by = "V1")
  }
  colnames(merged.list) <- c("gene", str_replace_all(filenames, "files/unzip/|.FPKM.txt", ""))
  return(merged.list)
}

x <- multmerge("files/unzip")


