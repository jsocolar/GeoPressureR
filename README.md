
<!-- README.md is generated from README.Rmd. Please edit that file -->

# GeoPressureR <img src="man/figures/logo.svg" align="right" height="139" />

<!-- badges: start -->

[![R-CMD-check](https://github.com/Rafnuss/GeoPressureR/workflows/R-CMD-check/badge.svg)](https://github.com/Rafnuss/GeoPressureR/actions)
<!-- badges: end -->

The goal of GeoPressureR is to help researcher to analyse pressure
measurement from geolocator. In particular, it provides a R wrapper
around the [GeoPressure
API](https://github.com/Rafnuss/GeoPressureServer) to query the
probability map using ERA5 pressure.

## Installation

You can install the development version of GeoPressureR from
[GitHub](https://github.com/Rafnuss/GeoPressureR) with:

``` r
# install.packages("devtools")
devtools::install_github("Rafnuss/GeoPressureR")
```

## Where to start?

The vignette [basic example](./basic_example.html) is probably the best
place to understand the basic workflow of the package.

## Related ressources

-   [GeoPressureMAT](https://github.com/Rafnuss/GeoPressureMAT)
    Developement of the method was done on MATLAB. Here is the repo with
    all the codes.
-   [GeoPressure API](https://github.com/Rafnuss/GeoPressureServer) This
    is where the hard core computation with Google Earth Engine is done.
    You can have a look here to see how this is done.
-   [GeoLight](https://github.com/slisovski/GeoLight/tree/Update_2.01) R
    package to analyse light data.
-   [PAMLr](https://github.com/KiranLDA/PAMLr): Extensive toolbox to
    analyse multi-sensor geolocator. Several function from this package
    are inspired from this package.

## How to cite?

*manuscript in preparation*

## Want to contribute?

Don’t hesitate to reach out if you’re interested in contributing. You
can also [submit an issue on
Github](https://github.com/Rafnuss/GeoPressureR/issues) with ideas, bug,
etc…
