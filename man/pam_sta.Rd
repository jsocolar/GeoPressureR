% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pam.R
\name{pam_sta}
\alias{pam_sta}
\title{Compute stationary periods}
\usage{
pam_sta(pam)
}
\arguments{
\item{pam}{pam logger dataset list}
}
\value{
pam logger dataset list with a the dataframe of stationary periods
\code{pam$sta} as well as the new label named \code{sta_id} (\code{pam$pressure$sta_id} and
\code{pam$acceleration$sta_id})
}
\description{
This function computes the table of stationary periods from the class of
acceleration \code{pam$acceleration$class} and add it to the pam data as \code{sta_id}
}
\examples{
pam_data <- pam_read(
  pathname = system.file("extdata", package = "GeoPressureR"),
  crop_start = "2017-06-20", crop_end = "2018-05-02"
)
pam_data <- trainset_read(pam_data,
  pathname = system.file("extdata", package = "GeoPressureR")
)
pam_data <- pam_sta(pam_data)
head(pam_data$pressure)
head(pam_data$acceleration)
}
