

raster_variables <- function(data, extent = NULL,
                            zvar = NULL, z_type = "time",
                           data_name = "some.data", data_unit = "some.unit", long_name = "some.long.name") {
  dimension <- dim(data)
  if (is.null(zvar)) {
    zvar <- 0
    if (z_type == "time") zvar <- Sys.time()
  }
  z_stuff <- switch(z_type,
    time = list(unit = "seconds since 1970-01-01 00:00:00",
                dimension = "time",
                unlim = TRUE),
    elevation = list(unit = "metres", dimension = "elevation", unlim = FALSE),
    depth = list(unit = "metres", dimension = "depth", unlim = FALSE)
  )

 xx <- vaster::x_centre(extent, dimension)
  yy <- vaster::y_centre(extent, dimension)

  z_dim   <- ncdf4::ncdim_def(z_stuff$dimension, "", seq_along(zvar), unlim = z_stuff$unlim, create_dimvar = FALSE)
  x_dim <-   ncdf4::ncdim_def("x", "metres or degrees WIP", xx, create_dimvar = T)
  y_dim <-   ncdf4::ncdim_def("y", "metres or degrees WIP", yy, create_dimvar = T)


  ## prec should pivot on integer/float status of z
  var.z <- ncdf4::ncvar_def(z_stuff$dimension, z_stuff$unit, z_dim, prec = "double")

  var.data     <- ncdf4::ncvar_def(data_name, data_unit, list(x_dim, y_dim, z_dim), NA,    ## might want NULL here
                            longname = long_name, prec = "float")

  ## WIP we need grid_mapping and pivot on longlat/projected
##  https://github.com/mdsumner/fixoisst/blob/4adef5a28c4d12a6684f2578cfb2ec13a37bfe38/fix-oisst.R#L10-L17
  list(z = var.z,
       data = var.data)
}

#' Create raster file in NetCDF.
#'
#' Rasters need extent, dimension, projection - this writer gives the correct metadata for simple
#' raster inputs with minimal generality and no fuss.
#'
#'  These functions
#' aim to minimize the amount of manual handling of details, creating an NetCDF file that can be modified directly.

#' @param filename the NetCDF file to create
#' @param title name of the model
#' @param zvar actual time steps, need to be regularly space
#' @param transp_params optional details to put in the NetCDF notes
#' @param overwrite set to \code{TRUE} to clobber an existing file
#' @return the filename of the output (use ncdf4 to inspect, modify it)
#' @export
#' @importFrom ncdf4 nc_open ncatt_put ncvar_put nc_close ncdim_def ncvar_def
#' @examples
#' png <- system.file("textures/world.png", package = "rgl", mustWork = TRUE)
#' arr <- aperm(png::readPNG(png), c(2, 1, 3))
#' arr <- arr[,ncol(arr):1, ]
#' f <- write_nc(arr, extent = c(-180, 180, -90, 90), data_name = "world_image")
#' # terra::plotRGB(terra::rast(f) * 256)
#' # maps::map(add = T)
write_nc <- function(data, filename = NULL,
                     extent = NULL,
                             title = "raster",
zvar = NULL, z_type = "time",
                           data_name = NULL, data_unit = "some.unit", long_name = "some.long.name",
                             params = "", overwrite = FALSE) {

  dimension <- dim(data)
  if (is.null(extent)) extent <- c(0, dimension[1L], 0, dimension[2L])
  if (is.null(filename)) filename <- tempfile(fileext = ".nc")
  if (is.null(data_name)) data_name <- deparse1(substitute(data))
  data_name_clean <- gsub("\\s+", "", data_name)
  if (!identical(data_name, data_name_clean)) {
    message(sprintf("variable name taken from '%s' may not be suitable - set 'data_name = <sensible variable name>'", data_name))
    data_name <-data_name_clean

  }
 if (length(dimension) == 3) {
      len <- dimension[3L]
    } else {
      len <- 1
  }
  if (is.null(zvar)) {

    zvar <- Sys.time() + seq(0, by = 1, length.out = len)
  }


  stopifnot(length(zvar) == len)
  if (z_type == "time") stopifnot(inherits(zvar, "POSIXct"))
  if (length(zvar) > 1) stopifnot(length(unique(diff(unclass(zvar)))) == 1)

  variables <- raster_variables(data, extent = extent, zvar = NULL, z_type = "time",
                           data_name = data_name, data_unit = "some.unit", long_name = "some.long.name")

  if (file.exists(filename) && !overwrite) {
    stop(sprintf("'filename' already exists, use 'overwrite = TRUE' or delete: \n%s", filename))
  }
  nc_varfile <-  ncdf4::nc_create(filename, variables)
  on.exit(ncdf4::nc_close(nc_varfile), add = TRUE)

  #assign global attributes to file
  ncdf4::ncatt_put(nc_varfile,0,"title", title)
  ncdf4::ncatt_put(nc_varfile, "time","dt",86400,prec="double")

  ncdf4::ncvar_put(nc_varfile, variables$z, zvar, count = length(zvar))
  ## note this saves us from 1 or none in the 3rd slot
  ncdf4::ncvar_put(nc_varfile, variables$data, data, count = c(dimension[1:2], length(zvar)))

  filename
}