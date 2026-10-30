#' Check a dataset before computing any metric
#'
#' Runs every `eiod_check_*` function over a data frame and returns a single
#' report. This is the function to call first, before
#' [eiod_absolute_threshold()] or anything else.
#'
#' @section What it checks:
#' \itemize{
#'   \item **Structure** - that each named column exists, and that impact
#'     columns are doubles rather than factors, characters or integers.
#'   \item **Validity** - no negative or non-finite impacts, exact zeros
#'     flagged, missingness reported.
#'   \item **Precision** - significant digits actually retained, and how many
#'     observations sit close enough to a cut-off that rounding could change
#'     their classification. See [eiod_check_precision()].
#'   \item **Unit magnitude** - each impact compared against the published
#'     global reference, with likely unit errors named. See
#'     [eiod_check_magnitude()].
#'   \item **Demographics** - age range and units, sex coding, coverage of the
#'     eight groups, and the count of under-twos.
#'   \item **GDQS** - type and range.
#' }
#'
#' @section Severity:
#' `error` means a metric computed on this data would be wrong, not merely
#' uncertain; fix it first. `warning` means proceed, but you need to have
#' looked. `note` is information worth having in the record.
#'
#' @param data A data frame.
#' @param impacts A named character vector mapping indicator names to column
#'   names, for example `c(biodiv = "biodiv_pdf", ghg = "ghg_kg")`. Names must
#'   be among the seven in [eiod_list_indicators()].
#' @param age,sex,gdqs Column names, or `NULL` to skip that check.
#' @param age_units `"years"` (default) or `"months"`.
#' @param male,female Optional sex codes; see [eiod_age_sex_group()].
#' @param tolerance Relative distance from a cut-off below which a
#'   classification is treated as not robust. Default `1e-6`.
#'
#' @return An object of class `eiod_check`. Use `summary()` for a single
#'   pass/fail, or treat it as a data frame to filter the findings.
#'
#' @seealso [eiod_check_impact()], [eiod_check_precision()],
#'   [eiod_check_magnitude()], [eiod_check_demographics()],
#'   [eiod_check_gdqs()]
#'
#' @examples
#' data(eiod_demo)
#'
#' report <- eiod_check_data(
#'   eiod_demo,
#'   impacts = c(biodiv = "biodiv_pdf", ghg = "ghg_kgco2e"),
#'   age = "age", sex = "sex", gdqs = "gdqs"
#' )
#' report
#' summary(report)
#'
#' @export
eiod_check_data <- function(data, impacts = NULL, age = NULL, sex = NULL,
                            gdqs = NULL, age_units = c("years", "months"),
                            male = NULL, female = NULL, tolerance = 1e-6) {

  age_units <- match.arg(age_units)
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  src <- deparse(substitute(data))
  n <- nrow(data)

  # the demographic group is needed by the impact checks, so it comes first
  dem <- .eiod_demographic_parts(data, age, sex, age_units, male, female)
  parts <- c(.eiod_missing_column_parts(data, impacts, age, sex, gdqs, src, n),
             dem$parts,
             .eiod_impact_parts(data, impacts, dem$grp, tolerance))
  if (!is.null(gdqs) && gdqs %in% names(data)) {
    parts[[length(parts) + 1]] <- eiod_check_gdqs(data[[gdqs]])
  }

  .eiod_combine_parts(parts, n, src)
}


#' A structure finding for any named column missing from the data
#' @return A list holding zero or one report.
#' @noRd
.eiod_missing_column_parts <- function(data, impacts, age, sex, gdqs, src, n) {
  wanted <- c(impacts, age = age, sex = sex, gdqs = gdqs)
  wanted <- wanted[!vapply(wanted, is.null, logical(1))]
  missing_cols <- setdiff(unname(unlist(wanted)), names(data))
  if (length(missing_cols) == 0) return(list())
  list(.eiod_report(list(.eiod_finding(
    "structure", toString(missing_cols), "error", NA_integer_,
    paste0("column(s) not found in ", src, "."))), n_obs = n))
}


#' The demographic report and the group vector, when age and sex are usable
#' @return A list: `parts` (zero or one report) and `grp` (or `NULL`).
#' @noRd
.eiod_demographic_parts <- function(data, age, sex, age_units, male, female) {
  if (is.null(age) || is.null(sex) || !all(c(age, sex) %in% names(data))) {
    return(list(parts = list(), grp = NULL))
  }
  report <- eiod_check_demographics(data[[age]], data[[sex]],
                                    age_units = age_units,
                                    male = male, female = female)
  grp <- tryCatch(
    eiod_age_sex_group(data[[age]], data[[sex]], age_units = age_units,
                       male = male, female = female),
    error = function(e) NULL)
  list(parts = list(report), grp = grp)
}


#' Stop unless `impacts` is a named vector of known indicator keys
#' @noRd
.eiod_check_impacts_arg <- function(impacts) {
  if (is.null(names(impacts)) || any(names(impacts) == "")) {
    stop("`impacts` must be a NAMED character vector, for example ",
         "c(biodiv = \"biodiv_pdf\").", call. = FALSE)
  }
  bad_ind <- setdiff(names(impacts), .eiod_valid_indicators())
  if (length(bad_ind)) {
    stop("unknown indicator name(s) in `impacts`: ",
         toString(bad_ind),
         ".\n  Valid names: ",
         toString(.eiod_valid_indicators()), call. = FALSE)
  }
  invisible(TRUE)
}


#' Impact, precision and magnitude reports for each named impact column
#' @noRd
.eiod_impact_parts <- function(data, impacts, grp, tolerance) {
  parts <- list()
  if (is.null(impacts)) return(parts)
  .eiod_check_impacts_arg(impacts)

  for (ind in names(impacts)) {
    col <- impacts[[ind]]
    if (!col %in% names(data)) next
    v <- data[[col]]

    imp <- eiod_check_impact(v, name = col, indicator = ind)
    parts[[length(parts) + 1]] <- imp

    # precision and magnitude only make sense on usable numeric data
    blocked <- any(imp$level == "error" & imp$check == "type")
    if (!blocked) {
      parts[[length(parts) + 1]] <- eiod_check_precision(
        v, group = grp, indicator = ind, name = col, tolerance = tolerance)
      parts[[length(parts) + 1]] <- eiod_check_magnitude(
        v, indicator = ind, group = grp, name = col)
    }
  }
  parts
}


#' Combine component reports into one eiod_check, errors first
#' @noRd
.eiod_combine_parts <- function(parts, n, src) {
  findings <- do.call(rbind, lapply(parts, function(p) {
    attributes(p) <- list(names = names(p), row.names = seq_len(nrow(p)),
                          class = "data.frame")
    p
  }))
  if (is.null(findings)) {
    findings <- .eiod_finding(character(0), character(0), character(0),
                              integer(0), character(0))
  }
  findings$level <- factor(as.character(findings$level),
                           levels = c("error", "warning", "note"))
  findings <- findings[order(findings$level), , drop = FALSE]
  rownames(findings) <- NULL

  structure(findings, class = c("eiod_check", "data.frame"),
            n_obs = n, source = src)
}


#' @param x An `eiod_check` object.
#' @param ... Ignored.
#' @rdname eiod_check_data
#' @export
print.eiod_check <- function(x, ...) {

  .eiod_print_check_header(attr(x, "source"), attr(x, "n_obs"))

  if (nrow(x) == 0L) {
    cat("  no findings.\n")
    return(invisible(x))
  }

  counts <- table(factor(as.character(x$level),
                         levels = c("error", "warning", "note")))
  cat(sprintf("  ERROR    %d\n  WARNING  %d\n  NOTE     %d\n\n",
              counts[["error"]], counts[["warning"]], counts[["note"]]))

  for (lv in c("error", "warning", "note")) {
    for (i in which(as.character(x$level) == lv)) {
      .eiod_print_finding(lv, x$variable[i], x$check[i], x$message[i])
    }
  }

  .eiod_print_check_footer(counts[["error"]])
  invisible(x)
}


#' Title and source line of an eiod_check printout
#' @noRd
.eiod_print_check_header <- function(src, n_obs) {
  cat("reiod data quality report\n")
  if (!is.null(src) && !is.na(n_obs)) {
    cat("  data: ", src, "   n = ", format(n_obs, big.mark = ","), "\n",
        sep = "")
  }
  cat("\n")
}


#' One finding, its message wrapped under a fixed-width heading
#' @noRd
.eiod_print_finding <- function(lv, variable, check, message) {
  head_txt <- sprintf("  %-8s %-14s %-12s ", toupper(lv), variable, check)
  msg <- strwrap(message, width = 76 - nchar(head_txt) + 36, prefix = "")
  cat(head_txt, msg[1], "\n", sep = "")
  for (m in msg[-1]) cat(strrep(" ", nchar(head_txt)), m, "\n", sep = "")
}


#' Closing line: how many blocking problems there are
#' @noRd
.eiod_print_check_footer <- function(n_err) {
  cat("\n")
  if (n_err > 0) {
    cat("  ", n_err, " blocking problem", if (n_err > 1) "s" else "",
        ". Fix before computing metrics.\n", sep = "")
  } else {
    cat("  No blocking problems.\n")
  }
}


#' @param object An `eiod_check` object.
#' @rdname eiod_check_data
#' @export
summary.eiod_check <- function(object, ...) {
  counts <- table(factor(as.character(object$level),
                         levels = c("error", "warning", "note")))
  structure(
    list(n_error = as.integer(counts[["error"]]),
         n_warning = as.integer(counts[["warning"]]),
         n_note = as.integer(counts[["note"]]),
         pass = counts[["error"]] == 0L),
    class = "summary.eiod_check")
}

#' @export
print.summary.eiod_check <- function(x, ...) {
  cat(if (x$pass) "PASS" else "FAIL",
      sprintf(" - %d error, %d warning, %d note\n",
              x$n_error, x$n_warning, x$n_note), sep = "")
  invisible(x)
}
