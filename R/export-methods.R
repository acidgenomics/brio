#' @name export
#' @inherit AcidGenerics::export
#' @note Updated 2021-01-06.
#'
#' @section Row names:
#'
#' Some export utilities in R have a tendency to drop row names when writing to
#' disk in CSV format. For example, the [readr][] family of functions never
#' write row names by design. This is a *really poor* default setting for
#' handling genomic data, which often contain gene identifiers in the row names.
#' Here we're performing any internal tibble coercion step to ensure row names
#' are always moved to a `"rowname"` column in the CSV export.
#'
#' [readr]: https://readr.tidyverse.org/
#'
#' @section Debugging:
#'
#' Note that this function currently wraps `vroom::voom_write()` by default
#' for exporting `data.frame` and `matrix` class objects.
#'
#' @inheritParams AcidRoxygen::params
#' @param object Object.
#'   An object supporting [`dim()`][base::dim], or a supported class capable
#'   of being coerced to `data.frame`, to be written to disk.
#' @param ext `character(1)`.
#'   Output file format extension.
#'
#'   `matrix` supported arguments:
#'   - Comma separated values (CSV):
#'     `"csv"`, `"csv.bz2"`, `"csv.gz"`, `"csv.xz"`, `"csv.zip"`.
#'   - Tab separated values (TSV):
#'     `"tsv"`, `"tsv.bz2"`, `"tsv.gz"`, `"tsv.xz"`, `"tsv.zip"`.
#'
#'   `Matrix` (`sparseMatrix`) supported arguments:
#'   - MatrixMarket exchange (MTX):
#'     `"mtx"`, `"mtx.bz2"`, `"mtx.gz"`, `"mtx.xz"`, `"mtx.zip"`.
#' @param file `character(1)`.
#'   File path. When left unset (default), the `ext` and `dir` arguments will
#'   be used instead.
#' @param append `logical(1)`.
#'   Append to output file.
#'   When enabled, automatically sets `overwrite` argument to `FALSE`.
#'   Requires readr package to be installed.
#' @param ... Additional arguments.
#'
#' @return Invisible `character`.
#' File path(s).
#'
#' @seealso
#' Packages:
#'
#' - [data.table](http://r-datatable.com/).
#' - [readr](http://readr.tidyverse.org).
#' - [rio](https://cran.r-project.org/package=rio).
#' - [rtracklayer](http://bioconductor.org/packages/rtracklayer/).
#' - [vroom](https://vroom.r-lib.org).
#'
#' Export functions:
#'
#' - `data.table::fwrite()`.
#' - `readr::write_csv()`.
#' - `rio::export()`.
#' - `rtracklayer::export()`.
#' - `vroom::vroom_write()`.
#'
#' @examples
#' counts <- matrix(data = seq_len(100L), nrow = 10)
#' export(counts, ext = "csv")
#'
#' ## Clean up.
#' file.remove("counts.csv")
NULL



## Updated 2021-01-13.
`export,character` <-  # nolint
    function(
        object,
        ext = "txt",
        dir,
        file = NULL,
        append = FALSE,
        overwrite,
        quiet
    ) {
        assert(
            isString(ext),
            isString(dir),
            isString(file, nullOK = TRUE),
            isFlag(overwrite),
            isFlag(append),
            isFlag(quiet)
        )
        whatPkg <- match.arg(
            arg = getOption(
                x = "acid.export.engine",
                default = .defaultDelimEngine
            ),
            choices = .delimEngines
        )
        ## The vroom engine currently doesn't offer `write_lines` support,
        ## so fall back to readr (if installed), and then base R. Jim is
        ## currently working on `vroom_write_lines()`:
        ## https://github.com/r-lib/vroom/issues/291
        if (whatPkg == "vroom") {
            if (isInstalled("readr")) {
                whatPkg <- "readr"
            } else {
                whatPkg <- "base"  # nocov
            }
        }
        if (isTRUE(append)) {
            assert(!identical(whatPkg, "base"))
            overwrite <- FALSE
        }
        if (isTRUE(overwrite)) {
            assert(isFALSE(append))
        }
        requireNamespaces(whatPkg)
        if (is.null(file)) {
            call <- standardizeCall()
            sym <- call[["object"]]
            assert(is.symbol(sym))
            name <- as.character(sym)
            ext <- match.arg(
                arg = ext,
                choices = c("txt", "txt.bz2", "txt.gz", "txt.xz", "txt.zip")
            )
            dir <- initDir(dir)
            file <- file.path(dir, paste0(name, ".", ext))
        } else {
            dir <- initDir(dirname(file))
        }
        whatFile <- basename(file)
        whatDir <- realpath(dirname(file))
        match <- str_match(string = file, pattern = extPattern)
        compressExt <- match[1L, 4L]
        compress <- !is.na(compressExt)
        if (isAFile(file)) {
            file <- realpath(file)
            if (isTRUE(overwrite) && !isTRUE(quiet)) {
                alertWarning(sprintf(
                    fmt = "Overwriting {.file %s} at {.path %s}.",
                    whatFile, whatDir
                ))
            } else {
                stop(sprintf("File exists: '%s'", file))
            }
        }
        if (isTRUE(compress)) {
            file <- sub(
                pattern = paste0("\\.", compressExt, "$"),
                replacement = "",
                x = file
            )
        }
        switch(
            EXPR = whatPkg,
            "base" = {
                whatFun <- "writeLines"
                args <- list(
                    "text" = object,
                    "con" = file
                )
            },
            "data.table" = {
                whatFun <- "fwrite"
                args <- list(
                    "x" = as.list(object),
                    "file" = file,
                    "append" = append,
                    "sep" = "\n"
                )
            },
            "readr" = {
                ## readr v1.4 changed "path" to "file".
                whatFun <- "write_lines"
                args <- list(
                    "x" = object,
                    "file" = file,
                    "append" = append
                )
            }
        )
        if (!isTRUE(quiet)) {
            alert(sprintf(
                fmt = paste(
                    "Exporting {.file %s} at {.path %s}",
                    "using {.pkg %s}::{.fun %s}."
                ),
                whatFile, whatDir,
                whatPkg, whatFun
            ))
        }
        what <- get(x = whatFun, envir = asNamespace(whatPkg), inherits = TRUE)
        assert(is.function(what))
        do.call(what = what, args = args)
        if (isTRUE(compress)) {
            file <- compress(
                file = file,
                ext = compressExt,
                remove = TRUE,
                overwrite = TRUE
            )
        }
        file <- realpath(file)
        invisible(file)
    }

formals(`export,character`)[c("dir", "overwrite", "quiet")] <-
    formalsList[c("export.dir", "overwrite", "quiet")]



#' @rdname export
#' @export
setMethod(
    f = "export",
    signature = signature("character"),
    definition = `export,character`
)



#' Export `matrix` method
#'
#' @note Updated 2021-01-13.
#' @noRd
#'
#' @details
#' This method covers standard `matrix` but is also intended to work for
#' `data.table`, `tbl_df`, and `DataFrame` classes. Note that `rio::export()`
#' does not preserve row names by default, so we're ensuring row names get
#' coerced to "rowname" column consistently here.
`export,matrix` <-  # nolint
    function(
        object,
        ext,
        dir,
        file = NULL,
        rownames = TRUE,
        colnames = TRUE,
        overwrite,
        quiet
    ) {
        validObject(object)
        whatPkg <- match.arg(
            arg = getOption(
                x = "acid.export.engine",
                default = .defaultDelimEngine
            ),
            choices = .delimEngines
        )
        requireNamespaces(whatPkg)
        object <- as.data.frame(object)
        verbose <- getOption("acid.verbose", default = FALSE)
        assert(
            hasLength(object),
            hasRows(object),
            hasCols(object),
            hasNoDuplicates(colnames(object)),
            isString(ext),
            isString(dir),
            isString(file, nullOK = TRUE),
            isFlag(rownames),
            isFlag(colnames),
            isFlag(overwrite),
            isFlag(verbose)
        )
        if (is.null(file)) {
            call <- standardizeCall()
            sym <- call[["object"]]
            assert(is.symbol(sym))
            name <- as.character(sym)
            dir <- initDir(dir)
            file <- file.path(dir, paste0(name, ".", ext))
        } else {
            ext <- fileExt(file)
            dir <- initDir(dirname(file))
        }
        ## These are used in CLI messages.
        whatFile <- basename(file)
        whatDir <- realpath(dirname(file))
        ext <- match.arg(
            arg = ext,
            choices = c(
                "csv", "csv.bz2", "csv.gz", "csv.xz", "csv.zip",
                "tsv", "tsv.bz2", "tsv.gz", "tsv.xz", "tsv.zip"
            )
        )
        match <- str_match(string = file, pattern = extPattern)
        compressExt <- match[1L, 4L]
        compress <- !is.na(compressExt)
        ## Drop non-atomic columns automatically, if necessary.
        keep <- bapply(X = object, FUN = is.atomic)
        if (!all(keep)) {
            ## nocov start
            ## This is used to handle rowData with nested entrez identifiers.
            fail <- names(keep)[!keep]
            alertWarning(sprintf(
                "Dropping non-atomic columns: {.var %s}.",
                toString(fail, width = 200L)
            ))
            object <- object[, keep, drop = FALSE]
            ## nocov end
        }
        assert(allAreAtomic(object))
        if (isFALSE(rownames)) {
            rownames(object) <- NULL  # nocov
        }
        if (hasRownames(object)) {
            assert(areDisjointSets("rowname", colnames(object)))
            object[["rowname"]] <- rownames(object)
            rownames(object) <- NULL
            object <- object[
                ,
                c("rowname", setdiff(colnames(object), "rowname")),
                drop = FALSE
            ]
        }
        if (isAFile(file)) {
            file <- realpath(file)
            if (isTRUE(overwrite)) {
                if (!isTRUE(quiet)) {
                    alertWarning(sprintf(
                        fmt = "Overwriting {.file %s} at {.path %s}.",
                        whatFile, whatDir
                    ))
                }
                file.remove(file)
            } else {
                stop(sprintf("File exists: '%s'", file))
            }
        }
        if (isTRUE(compress)) {
            file <- sub(
                pattern = paste0("\\.", compressExt, "$"),
                replacement = "",
                x = file
            )
            ext <- match.arg(
                arg = fileExt(file),
                choices = c("csv", "tsv")
            )
        }
        switch(
            EXPR = whatPkg,
            "base" = {
                args <- list(
                    "x" = object,
                    "file" = file,
                    "append" = FALSE,
                    "col.names" = colnames,
                    "row.names" = FALSE
                )
                switch(
                    EXPR = ext,
                    "csv" = {
                        whatFun <- "write.csv"
                    },
                    "tsv" = {
                        whatFun <- "write.table"
                        args[["sep"]] <- "\t"
                    }
                )
            },
            "data.table" = {
                whatFun <- "fwrite"
                args <- list(
                    "x" = object,
                    "file" = file,
                    "append" = FALSE,
                    "col.names" = colnames,
                    "row.names" = FALSE,
                    "sep" = switch(
                        EXPR = ext,
                        "csv" = ",",
                        "tsv" = "\t"
                    ),
                    "verbose" = verbose
                )
            },
            "readr" = {
                whatFun <- switch(
                    EXPR = ext,
                    "csv" = "write_csv",
                    "tsv" = "write_tsv"
                )
                ## readr v1.4 changed "path" to "file".
                args <- list(
                    "x" = object,
                    "file" = file,
                    "append" = FALSE,
                    "col_names" = colnames
                )
            },
            "vroom" = {
                whatFun <- "vroom_write"
                args <- list(
                    "x" = object,
                    "path" = file,
                    "append" = FALSE,
                    "col_names" = colnames,
                    "delim" = switch(
                        EXPR = ext,
                        "csv" = ",",
                        "tsv" = "\t"
                    ),
                    "progress" = FALSE
                )
            }
        )
        if (!isTRUE(quiet)) {
            alert(sprintf(
                fmt = paste(
                    "Exporting {.file %s} at {.path %s}",
                    "using {.pkg %s}::{.fun %s}."
                ),
                whatFile, whatDir,
                whatPkg, whatFun
            ))
        }
        what <- get(x = whatFun, envir = asNamespace(whatPkg), inherits = TRUE)
        assert(is.function(what))
        do.call(what = what, args = args)
        if (isTRUE(compress)) {
            file <- compress(
                file = file,
                ext = compressExt,
                remove = TRUE,
                overwrite = TRUE
            )
        }
        file <- realpath(file)
        invisible(file)
    }

formals(`export,matrix`)[
    c("dir", "ext", "overwrite", "quiet")] <-
    formalsList[c("export.dir", "export.ext", "overwrite", "quiet")]



#' @rdname export
#' @export
setMethod(
    f = "export",
    signature = signature("matrix"),
    definition = `export,matrix`
)



`export,data.frame` <- `export,matrix`  # nolint



#' @rdname export
#' @export
setMethod(
    f = "export",
    signature = signature("data.frame"),
    definition = `export,data.frame`
)



`export,DataFrame` <- `export,data.frame`  # nolint



#' @rdname export
#' @export
setMethod(
    f = "export",
    signature = signature("DataFrame"),
    definition = `export,DataFrame`
)



#' Export `Matrix` (e.g. `sparseMatrix`) method
#'
#' @note Updated 2021-02-02.
#' @noRd
#'
#' @details
#' Note that "file" is referring to the matrix file.
#' The correponding column and row sidecar files are generated automatically.
#' Consider adding HDF5 support in a future update.
`export,Matrix` <-  # nolint
    function(
        object,
        ext = "mtx",
        dir,
        file = NULL,
        overwrite,
        quiet
    ) {
        validObject(object)
        assert(
            hasLength(object),
            isString(ext),
            isString(dir),
            isString(file, nullOK = TRUE),
            isFlag(overwrite),
            isFlag(quiet)
        )
        if (is.null(file)) {
            call <- standardizeCall()
            sym <- call[["object"]]
            assert(is.symbol(sym))
            name <- as.character(sym)
            dir <- initDir(dir)
            file <- file.path(dir, paste0(name, ".", ext))
        } else {
            ext <- fileExt(file)
            dir <- initDir(dirname(file))
        }
        ext <- match.arg(
            arg = ext,
            choices = c("mtx", "mtx.bz2", "mtx.gz", "mtx.xz", "mtx.zip")
        )
        match <- str_match(string = file, pattern = extPattern)
        compressExt <- match[1L, 4L]
        compress <- !is.na(compressExt)
        if (isAFile(file)) {
            file <- realpath(file)
            if (isTRUE(overwrite) && !isTRUE(quiet)) {
                alertWarning(sprintf(
                    fmt = "Overwriting {.file %s} at {.path %s}.",
                    basename(file), realpath(dirname(file))
                ))
            } else {
                stop(sprintf("File exists: %s", file))
            }
        }
        if (isTRUE(compress)) {
            file <- sub(
                pattern = paste0("\\.", compressExt, "$"),
                replacement = "",
                x = file
            )
        }
        if (!isTRUE(quiet)) {
            alert(sprintf(
                fmt = paste(
                    "Exporting {.file %s} at {.path %s}",
                    "using {.pkg %s}::{.fun %s}."
                ),
                basename(file), realpath(dirname(file)),
                "Matrix", "writeMM"
            ))
        }
        writeMM(obj = object, file = file)
        if (isTRUE(compress)) {
            file <- compress(
                file = file,
                ext = compressExt,
                remove = TRUE,
                overwrite = TRUE
            )
        }
        file <- realpath(file)
        ## Write barcodes (column names).
        barcodes <- colnames(object)
        barcodesFile <- paste0(file, ".colnames")
        export(
            object = barcodes,
            file = barcodesFile,
            overwrite = TRUE,
            quiet = quiet
        )
        ## Write features (row names).
        features <- rownames(object)
        featuresFile <- paste0(file, ".rownames")
        export(
            object = features,
            file = featuresFile,
            overwrite = TRUE,
            quiet = quiet
        )
        files <- c(
            matrix = file,
            barcodes = barcodesFile,
            genes = featuresFile
        )
        assert(allAreFiles(files))
        invisible(files)
    }

formals(`export,Matrix`)[
    c("dir", "overwrite", "quiet")] <-
    formalsList[c("export.dir", "overwrite", "quiet")]



#' @rdname export
#' @export
setMethod(
    f = "export",
    signature = signature("Matrix"),
    definition = `export,Matrix`
)



`export,GenomicRanges` <- `export,DataFrame`  # nolint



#' @rdname export
#' @export
setMethod(
    f = "export",
    signature = signature("GenomicRanges"),
    definition = `export,GenomicRanges`
)
