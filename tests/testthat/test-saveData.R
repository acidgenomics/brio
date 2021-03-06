context("saveData")

object1 <- "aaa"
object2 <- "bbb"
dir <- "example"
paths <- file.path(getwd(), dir, c("object1.rds", "object2.rds"))
names(paths) <- c("object1", "object2")

test_that("R data serialized", {
    object <- saveData(
        object1, object2,
        ext = "rds",
        dir = dir,
        overwrite = TRUE
    )
    expect_identical(object, expected = paths)
})

test_that("R data", {
    object <- saveData(
        object1, object2,
        ext = "rda",
        dir = dir,
        overwrite = TRUE
    )
    paths <- gsub(pattern = "\\.rds", replacement = ".rda", x = paths)
    expect_identical(object, paths)
})

test_that("overwrite = FALSE", {
    expect_message(
        object = saveData(
            object1, object2,
            dir = dir, overwrite = FALSE
        ),
        regexp = "No files were saved."
    )
    unlink(dir, recursive = TRUE)
})

test_that("List mode", {
    x <- TRUE
    y <- FALSE
    object <- saveData(list = c("x", "y"), dir = "XXX")
    expect_identical(
        object = basename(object),
        expected = c("x.rds", "y.rds")
    )
    expect_true(all(file.exists(file.path("XXX", paste0(c("x", "y"), ".rds")))))
    unlink("XXX", recursive = TRUE)
})

test_that("Invalid parameters", {
    expect_error(
        object = saveData(XXX),
        regexp = "object 'XXX' not found"
    )
    expect_error(
        object = saveData("example"),
        regexp = "non-standard evaluation"
    )
    expect_error(
        object = saveData(object1, dir = NULL),
        regexp = "isString"
    )
})
