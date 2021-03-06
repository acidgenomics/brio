#' Drop unused levels from factors
#'
#' @name droplevels
#' @inherit base::droplevels description
#' @note Updated 2021-02-03.
#'
#' @inheritParams AcidRoxygen::params
#' @param ... Additional arguments.
#'
#' @return Modified object.
#'
#' @examples
#' data(GRanges, package = "AcidTest")
#'
#' ## Ranges ====
#' object <- GRanges
#' object <- droplevels(object)
#' print(object)
NULL



## Updated 2021-02-03.
`droplevels,DataFrame` <-  # nolint
    function(x) {
        except <- !bapply(X = decode(x), FUN = is.factor)
        if (all(except)) return(x)
        lst <- as(x, "List")
        lst <- droplevels(x = lst, except = except)
        out <- as.DataFrame(x = lst, row.names = rownames(x))
        out
    }



#' @rdname droplevels
setMethod(
    f = "droplevels",
    signature = signature("DataFrame"),
    definition = `droplevels,DataFrame`
)



## Updated 2021-02-03.
`droplevels,Ranges` <-  # nolint
    function(x) {
        if (hasCols(mcols(x))) {
            mcols(x) <- droplevels(mcols(x))
        }
        x
    }



#' @rdname droplevels
setMethod(
    f = "droplevels",
    signature = signature("Ranges"),
    definition = `droplevels,Ranges`
)
