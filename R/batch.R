# ---------------------------------------------------------------------------- #
# Multi-indicator convenience wrappers.
#
# These exist for two reasons. The obvious one is convenience: seven calls
# become one. The less obvious one matters more - they give the documentation
# a correct idiom to teach.
#
# The old examples looped `eiod_demo[[ind]]` over `eiod_indicators$indicator`,
# which reads as though the package requires your columns to be named after the
# indicator keys. It never did. But that loop is what people copy, and in the
# companion Stata package the same pattern led users to believe a rename was
# mandatory. Taking an explicit `map` makes the distinction between "indicator
# key" and "your column name" impossible to miss.
# ---------------------------------------------------------------------------- #

#' Validate a map from indicator key to column name
#' @noRd
.eiod_check_map <- function(map, data, arg = "map") {

  if (!is.character(map) || !length(map)) {
    stop("`", arg, "` must be a non-empty NAMED character vector mapping ",
         "indicator keys to the column names in your data, for example\n",
         "  c(ghg = \"ghg_kgco2e\", biodiv = \"biodiv_pdf\")", call. = FALSE)
  }
  nm <- names(map)
  if (is.null(nm) || anyNA(nm) || any(nm == "")) {
    stop("every element of `", arg, "` must be named with an indicator key.\n",
         "  The NAME is the indicator (one of ",
         toString(.eiod_valid_indicators()), ");\n",
         "  the VALUE is the column in your data holding that impact.",
         call. = FALSE)
  }
  bad <- setdiff(nm, .eiod_valid_indicators())
  if (length(bad)) {
    stop("unknown indicator key(s) in `", arg, "`: ",
         toString(bad), ".\n  Valid keys: ",
         toString(.eiod_valid_indicators()),
         ".\n  See eiod_list_indicators().", call. = FALSE)
  }
  if (anyDuplicated(nm)) {
    stop("`", arg, "` names an indicator more than once: ",
         toString(unique(nm[duplicated(nm)])), ".", call. = FALSE)
  }
  missing_cols <- setdiff(map, names(data))
  if (length(missing_cols)) {
    stop(length(missing_cols), " column(s) named in `", arg,
         "` are not in `data`: ", toString(missing_cols), ".",
         call. = FALSE)
  }
  invisible(TRUE)
}


#' All absolute threshold metrics at once (Table 3)
#'
#' Applies [eiod_absolute_threshold()] to several indicators in one call and
#' returns a data frame of results, one column per indicator.
#'
#' @section The map is the point:
#' `map` states, explicitly, which column of your data holds which indicator.
#' The **name** is the indicator key reiod knows (`"ghg"`); the **value** is
#' whatever your column is actually called (`"ghg_kgco2e"`). They are different
#' things, and nothing in reiod has ever required them to match - the vector API
#' means `eiod_absolute_threshold(d$anything, grp, "ghg")` works.
#'
#' Supply any subset. Indicators you do not name are simply absent from the
#' result; there is no need to have all seven.
#'
#' @param data A data frame with one row per respondent-day.
#' @param group Integer vector of demographic groups 1-8, from
#'   [eiod_age_sex_group()], of length `nrow(data)`.
#' @param map Named character vector: names are indicator keys, values are
#'   column names in `data`. See [eiod_demo_map] for the shape.
#' @param prefix Prefix for the returned column names. Default `"abs_"`.
#'
#' @return A data frame with `nrow(data)` rows and one integer column per
#'   indicator in `map`, named `paste0(prefix, indicator)`.
#'
#' @seealso [eiod_absolute_threshold()] for the single-indicator form and the
#'   full discussion of the metric; [eiod_relative_all()].
#'
#' @examples
#' data(eiod_demo)
#' grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)
#'
#' # your own column names, stated once
#' res <- eiod_absolute_all(eiod_demo, grp,
#'                          map = c(ghg = "ghg_kgco2e", biodiv = "biodiv_pdf"))
#' colMeans(res, na.rm = TRUE)
#'
#' # all seven, using the mapping shipped with the demo data
#' all7 <- eiod_absolute_all(eiod_demo, grp, eiod_demo_map)
#' round(100 * colMeans(all7, na.rm = TRUE), 1)
#'
#' @export
eiod_absolute_all <- function(data, group, map, prefix = "abs_") {

  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  .eiod_check_map(map, data)
  .eiod_check_group(group, n = nrow(data))

  out <- lapply(names(map), function(ind)
    eiod_absolute_threshold(data[[map[[ind]]]], group, ind))
  names(out) <- paste0(prefix, names(map))
  as.data.frame(out, stringsAsFactors = FALSE)
}


#' All relative benchmark metrics at once (Tables 4a-4g)
#'
#' Applies [eiod_relative_band()] to several indicators in one call and returns
#' a data frame of results, one column per indicator.
#'
#' @inheritSection eiod_absolute_all The map is the point
#'
#' @param group Integer vector of demographic groups 1-8, of length
#'   `nrow(data)`.
#' @param map Named character vector: names are indicator keys, values are
#'   column names in `data`.
#' @param midpoint If `TRUE`, return band midpoint percentiles rather than band
#'   numbers. See [eiod_relative_band()] for why a mean band is not a mean
#'   impact.
#' @param prefix Prefix for the returned column names. Default `"band_"`.
#'
#' @inheritParams eiod_absolute_all
#'
#' @return A data frame with `nrow(data)` rows and one integer column per
#'   indicator in `map`.
#'
#' @seealso [eiod_relative_band()], [eiod_absolute_all()]
#'
#' @examples
#' data(eiod_demo)
#' grp <- eiod_age_sex_group(eiod_demo$age, eiod_demo$sex)
#'
#' bands <- eiod_relative_all(eiod_demo, grp, eiod_demo_map)
#' sapply(bands, function(b) round(mean(b, na.rm = TRUE), 2))
#'
#' @export
eiod_relative_all <- function(data, group, map, midpoint = FALSE,
                              prefix = "band_") {

  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  .eiod_check_map(map, data)
  .eiod_check_group(group, n = nrow(data))
  if (!is.logical(midpoint) || length(midpoint) != 1L || is.na(midpoint)) {
    stop("`midpoint` must be TRUE or FALSE.", call. = FALSE)
  }

  out <- lapply(names(map), function(ind)
    eiod_relative_band(data[[map[[ind]]]], group, ind, midpoint = midpoint))
  names(out) <- paste0(prefix, names(map))
  as.data.frame(out, stringsAsFactors = FALSE)
}
