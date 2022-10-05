
#' Add grid mapping
#'
#' grid_mapping by CF convention
#'
#' mapping is a list with elements 'name' of the crs variable, and 'atts' list
#' with named attributes and values (e.g. standard_parallel = c(10, 20))
#'
#' @param x file name
#' @param overwrite enforce user override to actually update the file
#' @param mapping list of name of variable and attributes for mapping params (see DEtails)
#'
#' @export
#' @return the name of the file modified, returned invisibly
#' @examples
#' mapping <- list(name = "crs",
#'                    atts = list(grid_mapping_name = "lambert_conformal_conic",
#'                                standard_parallel = c(-10, -50),
#'                                #standard_parallel = -50,
#'                                latitude_of_projection_origin = -30,
#'                                longitude_of_central_meridian =  134.33,
#'                                semi_major_axis = 6370000))
#'
add_grid_mapping <- function(x, mapping, overwrite = FALSE) {
  stopifnot(file.exists(x))
  if (!overwrite) stop("file will not be updated unless 'overwrite = TRUE'")
  nc <- try(RNetCDF::open.nc(x, write = TRUE))
  if (inherits(nc, "try-error")) stop()

  var <-   try(RNetCDF::var.def.nc(nc, mapping$name, "NC_INT", NA))
  if (inherits(var, "try-error")) stop(sprintf("\nLooks like file already has variable '%s'?", mapping$name))
  RNetCDF::var.put.nc(nc, mapping$name, 1L)
  #att.put.nc(nc, mapping$name, "_FillValue", "NC_INT", -9L)
   RNetCDF::att.put.nc(nc, mapping$name, "comment", "NC_CHAR",

            "This is a container variable that describes the grid_mapping used by the data in this file. This variable does not contain any data; only information about the geographic coordinate system.")

  nctype <- c(character = "NC_CHAR", double = "NC_FLOAT")
  for (i in seq_along(mapping$atts)) {
    RNetCDF::att.put.nc(nc, mapping$name, names(mapping$atts)[i], nctype[typeof(mapping$atts[[i]])],
                        mapping$atts[[i]])
  }


vars <- ncmeta::nc_vars(nc) |>  dplyr::filter(ndims == 2) |>  dplyr::pull(name)
for (varname in vars) {
  RNetCDF::att.put.nc(nc, varname, "grid_mapping", "NC_CHAR",  mapping$name)
}

RNetCDF::close.nc(nc)
invisible(x)
}
