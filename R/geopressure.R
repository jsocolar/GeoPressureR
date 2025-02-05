#' Request and download mismatch maps of pressure
#'
#' This function return the mismatch map of atmospheric pressure measured by a
#' geolocator (`PAM_data`). It performs the following actions: (1) Send a query
#' to produce the Google Earth Engine (GEE) url of the code producing the maps
#' for each stationary periods separately, (2) then read these map (geotiff) in
#' a raster and (3) compute the likelihood map from the mismatch. See [the
#' GeoPressure API documentation
#' ](https://raphaelnussbaumer.com/GeoPressureServer/#description)
#'
#' @param pressure pressure list from PAM logger dataset list.
#' @param extent Geographical extend of the map to query as a list ordered by
#' West,East,South,North  (e.g. c(-6,43,0,47))
#' @param scale Number of pixel per latitude, longitude. 10 for a resoltion of
#' 0.1° (~10) and 4 for a resolution of 0.25° (~30km). To avoid interpolating
#' the ERA5 data, scale should be smaller than 10. Read more about scale on
#' Google earth Engine documention.
#' @param max_sample The computation of the mismatch is only performed on
#' `max_sample` datapoints of pressure to reduce computational time. The samples
#' are randomly (uniformly) selected on the timeserie.
#' @param margin The margin is used in the threshold map to accept some
#' measurement error. unit in meter. (1hPa~10m)
#' @return List of raster map
#' @examples
#' \dontrun{
#' pam_data <- pam_read(
#'   pathname = system.file("extdata", package = "GeoPressureR"),
#'   crop_start = "2017-06-20", crop_end = "2018-05-02"
#' )
#' pam_data <- trainset_read(pam_data,
#'   pathname = system.file("extdata", package = "GeoPressureR")
#' )
#' pam_data <- pam_sta(pam_data)
#' raster_list <- geopressure_map(
#'   pam_data$pressure,
#'   extent = c(-16, 20, 0, 50),
#'   scale = 10,
#'   max_sample = 250,
#'   margin = 30
#' )
#' }
#' data("raster_list", package = "GeoPressureR")
#' raster::metadata(raster_list[[1]])
#' raster::plot(raster_list[[1]],
#'   main = c("Mean Square Error", "Mask of pressure")
#' )
#' @export
geopressure_map <-
  function(pressure,
           extent,
           scale = 10,
           max_sample = 250,
           margin = 30) {
    # Check input
    testthat::expect_type(pressure, "list")
    testthat::expect_true("date" %in% names(pressure))
    testthat::expect_is(pressure$date, "POSIXt")
    testthat::expect_true("obs" %in% names(pressure))
    testthat::expect_is(pressure$obs, c("integer", "numeric"))
    testthat::expect_true("class" %in% names(pressure))
    testthat::expect_is(pressure$class, "logical")
    testthat::expect_true("sta_id" %in% names(pressure))
    testthat::expect_length(pressure$obs, length(pressure$date))
    testthat::expect_length(pressure$class, length(pressure$date))
    testthat::expect_length(pressure$sta_id, length(pressure$date))
    testthat::expect_is(extent, c("integer", "numeric"))
    testthat::expect_length(extent, 4)
    testthat::expect_true(extent[1] >= -180 & extent[1] <= 180)
    testthat::expect_true(extent[2] >= -180 & extent[2] <= 180)
    testthat::expect_true(extent[3] >= -90 & extent[3] <= 90)
    testthat::expect_true(extent[4] >= -90 & extent[4] <= 90)
    testthat::expect_true(extent[1] < extent[2])
    testthat::expect_true(extent[3] < extent[4])
    testthat::expect_is(scale, c("integer", "numeric"))
    testthat::expect_gt(scale, 0)
    testthat::expect_lte(scale, 10)
    testthat::expect_is(max_sample, c("integer", "numeric"))
    testthat::expect_gt(max_sample, 0)
    testthat::expect_is(margin, c("integer", "numeric"))
    testthat::expect_gte(margin, 0)

    # convert from hPa to Pa
    pres <- pressure$obs * 100

    # remove outliar as labeled in TRAINSET
    pres[pressure$class] <- NA

    # remove flight period
    pres[pressure$sta_id == 0] <- NA

    # smooth the data to 1hr
    # need to be done

    # downscale to 1hour
    pres[format(pressure$date, "%M") != "00"] <- NA

    # remove stationary period with NA
    pres[is.na(pressure$sta_id)] <- NA

    # Format query
    body_df <- list(
      time = jsonlite::toJSON(
        as.numeric(as.POSIXct(pressure$date[!is.na(pres)]))
      ),
      label = jsonlite::toJSON(pressure$sta_id[!is.na(pres)]),
      pressure = jsonlite::toJSON(pres[!is.na(pres)]),
      W = extent[1],
      S = extent[3],
      E = extent[2],
      N = extent[4],
      scale = scale,
      max_sample = max_sample,
      margin = margin
    )

    # Request URLS
    message("Sending requests...")
    res <-
      httr::POST("http://glp.mgravey.com:24853/GeoPressure/v1/map/",
        body = body_df
      )

    # check that the response is successful
    if (!httr::content(res)$status == "success") {
      message(httr::content(res))
      stop("Error with request")
    } else {
      # Get URIS
      uris <- unlist(httr::content(res)$data$urls)
      labels <- unlist(httr::content(res)$data$labels)
      message(
        "Request generated successfully for ",
        length(labels),
        " stationary periods (",
        sprintf("%d, ", sort(labels)),
        ")"
      )
    }

    # Perform the call in parallel
    # GEE allows up to 12 requests at the same time, so we set the worker to 10
    future::plan(future::multisession, workers = 10)
    f <- c()
    message("Starting download:")
    progress_bar(0, max = length(uris))
    for (i_u in seq_len(length(uris))) {
      f[[i_u]] <- future::future({
          raster::brick(uris[i_u])
        },
        seed = TRUE
      )
      progress_bar(i_u, max = length(uris))
    }

    # Get the raster
    raster_list <- c()
    message("Receiving download (geotiff):")
    progress_bar(0, max = length(uris))
    for (i_u in seq_len(length(uris))) {
      raster_list[[i_u]] <- future::value(f[[i_u]])
      progress_bar(i_u, max = length(uris))

      # Add datum
      raster::crs(raster_list[[i_u]]) <-
        "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

      # convert MSE from Pa to hPa
      raster_list[[i_u]][[1]] <- raster_list[[i_u]][[1]] / 100 / 100

      # Writing some metadata
      raster::metadata(raster_list[[i_u]]) <- list(
        sta_id = labels[i_u],
        nb_sample = sum(pressure$sta_id[!is.na(pres)] == labels[i_u]),
        max_sample = max_sample,
        extend_sample = c(
          min(pressure$date[!is.na(pres) & pressure$sta_id == labels[i_u]]),
          max(pressure$date[!is.na(pres) & pressure$sta_id == labels[i_u]])
        ),
        margin = margin
      )
    }

    # return
    raster_list
  }








#' Compute probability raster
#'
#' This function convert the raster of noramlized MSE and altitude threshold
#' \eqn{z_{thr}} computed by `geopressure_map()` into a probability map with,
#' \eqn{p = \exp \left(-w \frac{MSE}{s} \right) \left[z_{thr}>thr \right],}
#' where \eqn{s} is the standard deviation of pressure and \eqn{thr} is the
#' threashold. Because the auto-correlation of the timeseries is not accounted
#' for in this equation, we use a log-linear pooling weight \eqn{w=\log(n) - 1},
#' with \eqn{n} is the number of data point in the timeserie. This operation is
#' describe in
#'
#' @param raster_list list of raster loaded from `geopressure_map()`
#' @param s standard deviation of the pressure error
#' @param thr threshold of the percentage of data point outside the elevation
#' range to be considered not possible
#' @return List of the probability raster map
#' @examples
#' \dontrun{
#' pam_data <- pam_read(
#'   pathname = system.file("extdata", package = "GeoPressureR"),
#'   crop_start = "2017-06-20", crop_end = "2018-05-02"
#' )
#' pam_data <- trainset_read(pam_data,
#'   pathname = system.file("extdata", package = "GeoPressureR")
#' )
#' pam_data <- pam_sta(pam_data)
#' raster_list <- geopressure_map(
#'   pam_data$pressure,
#'   extent = c(-16, 20, 0, 50),
#'   scale = 10
#' )
#' prob_map_list <- geopressure_prob_map(
#'   raster_list,
#'   s = 0.4,
#'   thr = 0.9
#' )
#' }
#' data("prob_map_list", package = "GeoPressureR")
#' raster::metadata(prob_map_list[[1]])
#' raster::plot(prob_map_list[[1]],
#'   main = "Probability",
#'   xlim = c(5, 20), ylim = c(42, 50)
#' )
#' @export
geopressure_prob_map <- function(raster_list, s = 1, thr = 0.9) {
  raster_prob_list <- c()
  for (i_s in seq_len(length(raster_list))) {
    # get metadata
    mt <- raster::metadata(raster_list[[i_s]])

    # get MSE layer
    raster_prob_list[[i_s]] <- raster_list[[i_s]][[1]]
    # change 0 (water) in NA
    raster_prob_list[[i_s]][raster_prob_list[[i_s]] == 0] <- NA

    # compute Log-linear pooling weight
    # Number of datapoint could also be measured with
    # pres_n <- as.numeric(difftime(mt$extend_sample[2], mt$extend_sample[1],
    # units = "hours"))
    pres_n <- mt$nb_sample

    # Weight
    w <- log(pres_n) / pres_n

    # compute probability with equation
    raster_prob_list[[i_s]] <-
      (1 / (2 * pi * s^2)) ^ (pres_n * w / 2) * exp(-w * pres_n / 2 / (s^2)
        * raster_prob_list[[i_s]])
    # mask value of threashold
    raster_prob_list[[i_s]] <-
      raster_prob_list[[i_s]] * (raster_list[[i_s]][[2]] > thr)

    raster::metadata(raster_prob_list[[i_s]]) <-
      raster::metadata(raster_list[[i_s]])
  }
  raster_prob_list
}






#' Request and download surface pressure timeseries at location
#'
#' This function return the surfrace atmospheric pressure timeseries from ERA5
#' at a particualy location specify by lat and lon. I uses SRTM-30 to translate
#' the pressure for the exact elevation of the ground level, accounting for
#' both temporal varation of pressure and temperature.
#'
#' If you supply the pressure (and time) of the geolocator, it will additionally
#' return the elevation of the geolocator above sea level considering that the
#' bird was located at the location specify
#'
#'  The timeserie of the response will be on the same as time if supply,
#'  otherwise, it will return on a hourly basis between `start_time` and
#' `end_time`.
#'
#' @param lon longitude to query (-180° to 180°).
#' @param lat latitude to query (0° to 90°).
#' @param pressure pressure list from PAM logger dataset list
#' @param start_time if pressure not provided, then the start_time of the
#' timeserie return is needed
#' @param end_time same as start_time
#' @return Timeserie of date, pressure and optionally altitude
#' @examples
#' \dontrun{
#' pam_data <- pam_read(
#'   pathname = system.file("extdata", package = "GeoPressureR"),
#'   crop_start = "2017-06-20", crop_end = "2018-05-02"
#' )
#' pam_data <- trainset_read(pam_data,
#'   pathname = system.file("extdata", package = "GeoPressureR")
#' )
#' pam_data <- pam_sta(pam_data)
#' ts_list[[1]] <- geopressure_ts(
#'   lon = 16.85,
#'   lat = 48.75,
#'   pressure = subset(pam_data$pressure, sta_id == 1)
#' )
#' }
#' data("ts_list", package = "GeoPressureR")
#' par(mfrow = c(2, 1), mar = c(2, 5, 1, 1))
#' plot(ts_list[[1]]$date,
#'   ts_list[[1]]$pressure,
#'   ylab = "Pressure [hPa]", xlab = ""
#' )
#' plot(ts_list[[1]]$date,
#'   ts_list[[1]]$altitude,
#'   ylab = "Altitude [m asl]", xlab = ""
#' )
#' @export
geopressure_ts <-
  function(lon,
           lat,
           pressure = NULL,
           end_time = NULL,
           start_time = NULL) {
    # Test
    testthat::expect_is(lon, "numeric")
    testthat::expect_is(lat, "numeric")
    testthat::expect_true(lon >= -180 & lon <= 180)
    testthat::expect_true(lat >= -90 & lat <= 90)
    if (!is.null(pressure)) {
      testthat::expect_type(pressure, "list")
      testthat::expect_true("date" %in% names(pressure))
      testthat::expect_is(pressure$date, "POSIXt")
      testthat::expect_true("obs" %in% names(pressure))
      testthat::expect_is(pressure$obs, c("numeric", "integer"))
      testthat::expect_length(pressure$obs, length(pressure$date))
      end_time <- NULL
      start_time <- NULL
    } else {
      testthat::expect_is(end_time, "POSIXt")
      testthat::expect_is(start_time, "POSIXt")
      testthat::expect_gt(end_time, start_time)
    }

    # Format query
    body_df <- list(
      lon = lon,
      lat = lat
    )
    if (!is.null(pressure)) {
      body_df$time <-
        jsonlite::toJSON(as.numeric(as.POSIXct(pressure$date)))
      body_df$pressure <- jsonlite::toJSON(pressure$obs * 100)
    } else {
      body_df$start_time <-
        jsonlite::toJSON(as.numeric(as.POSIXct(start_time)))
      body_df$end_time <-
        jsonlite::toJSON(as.numeric(as.POSIXct(end_time)))
    }

    # Request URLS
    message("Sending request...")
    res <-
      httr::POST("http://glp.mgravey.com:24853/GeoPressure/v1/timeseries",
        body = body_df
      )

    # check that the response is successful
    if (!httr::content(res)$status == "success") {
      print(httr::content(res))
      stop("Error with request")
    }
    message("Request generated successfully.")

    # Download the csv file
    message("Downloading csv data.")
    res2 <- httr::GET(httr::content(res)$data$url)

    # read csv
    out <-
      as.data.frame(httr::content(
        res2,
        type = "text/csv",
        encoding = "UTF-8",
        show_col_types = F
      ))

    # check for errors
    if (nrow(out) == 0) {
      stop(
        "Returned csv file is empty. Check that the time range is none-empty
        and that the location is not on water"
      )
    }

    # convert Pa to hPa
    out$pressure <- out$pressure / 100

    # convert time into date
    out$time <- as.POSIXct(out$time, origin = "1970-01-01")
    names(out)[names(out) == "time"] <- "date"

    # return
    out
  }






# Progress bar function
progress_bar <- function(x, max = 100) {
  percent <- x / max * 100
  cat(sprintf(
    "\r[%-50s] %d / %d",
    paste(rep("=", percent / 2), collapse = ""),
    x, max
  ))
  if (x == max) {
    cat("\n")
  }
}
