% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.R
\docType{data}
\name{ts_list}
\alias{ts_list}
\title{Probability timeseries for 18LX}
\format{
An object of class \code{list} of length 27.
}
\usage{
ts_list
}
\description{
This dataset contains the data generated with the GeoPressure API for the
vignette \code{basic_example.Rmd}and \code{labeling_tracks.Rmd}.
}
\details{
\code{ts_list} was created with
}
\examples{
\dontrun{
ts_list <- list()
for (i_r in 1:length(prob_map_list)) {
  i_s <- metadata(prob_map_list[[i_r]])$sta_id

  # find the max value of probability
  tmp <- as.data.frame(prob_map_list[[i_r]], xy = T)
  lon <- tmp$x[which.max(tmp[, 3])]
  lat <- tmp$y[which.max(tmp[, 3])]

  # query the pressure at this location
  message("query:", i_r, "/", length(sta_id_keep))
  ts_list[[i_r]] <- geopressure_ts(lon,
    lat,
    pressure = subset(pam_data$pressure, sta_id == 1)
  )
  # Add sta_id
  ts_list[[i_r]]["sta_id"] <- i_s

  # Remove mean
  ts_list[[i_r]]$pressure0 <- ts_list[[i_r]]$pressure -
    mean(ts_list[[i_r]]$pressure) + mean(pam_data$pressure$obs[id])
}
# Save the data for vignette
usethis::use_data(ts_list, overwrite = T)
}
}
\keyword{datasets}
