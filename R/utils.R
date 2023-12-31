#' Transform a GCT object in to a long form \code{\link{data.table}}
#' (aka 'melt')
#' 
#' @description Utilizes the \code{\link{melt.data.table}} function to
#'   transform the
#'   matrix into long form. Optionally can include the row and column
#'   annotations in the transformed \code{\link{data.table}}.
#'   
#' @param g the GCT object
#' @param keep_rdesc boolean indicating whether to keep the row
#'   descriptors in the final result
#' @param keep_cdesc boolean indicating whether to keep the column
#'   descriptors in the final result
#' @param remove_symmetries boolean indicating whether to remove
#'   the lower triangle of the matrix (only applies if \code{g@mat}
#'   is symmetric)
#' @param suffixes the character suffixes to be applied if there are
#'   collisions between the names of the row and column descriptors
#' @param ... further arguments passed along to \code{data.table::merge}
#'   
#' @return a \code{\link{data.table}} object with the row and column ids and
#'   the matrix
#'   values and (optinally) the row and column descriptors
#'   
#' @examples 
#' # simple melt, keeping both row and column meta
#' head(melt_gct(ds))
#' 
#' # update row/colum suffixes to indicate rows are genes, columns experiments
#' head(melt_gct(ds, suffixes = c("_gene", "_experiment")))
#' 
#' # ignore row/column meta
#' head(melt_gct(ds, keep_rdesc = FALSE, keep_cdesc = FALSE))
#' 
#' @family GCT utilities
#' @export
setGeneric("melt_gct", function(g, suffixes=NULL, remove_symmetries=FALSE,
                                keep_rdesc=TRUE, keep_cdesc=TRUE, ...) {
  standardGeneric("melt_gct")
})
#' @rdname melt_gct
setMethod("melt_gct", signature("GCT"),
          function(g, suffixes, remove_symmetries=FALSE,
                   keep_rdesc=TRUE, keep_cdesc=TRUE, ...) {
          # melt a gct object's matrix into a data.frame and merge
          # row and column
          # annotations back in, using the provided suffixes
          # assumes rdesc and cdesc data.frames both have an 'id' field.
          # merges row and/or column annotations into the melted
          # matrix as indicated by
          # keep_rdesc and keep_cdesc, respectively.
          # if remove_symmetries, will check whether matrix is symmetric
          # and return only values corresponding to the upper triangle
          # check whether rdesc/cdesc are empty
          # if so, fill with id column
          m <- mat(g)
          rdesc <- meta(g)
          cdesc <- meta(g, dimension="col")
          rid <- ids(g)
          cid <- ids(g, dimension="col")
          if (nrow(rdesc) == 0) rdesc <- data.frame(id=rid)
          if (nrow(cdesc) == 0) cdesc <- data.frame(id=cid)
          # first, check if matrix is symmetric
          # if it is, use only the upper triangle
          message("melting GCT object...")
          if (remove_symmetries & isSymmetric(m)) {
            m[upper.tri(m, diag=FALSE)] <- NA
          }
          m <- data.table::data.table(m)
          m$rid <- rid
          d <- data.table::melt(m, id.vars="rid")
          data.table::setattr(d, "names", c("id.x", "id.y", "value"))
          d$id.x <- as.character(d$id.x)
          d$id.y <- as.character(d$id.y)
          # standard data.frame subset here to comply with testthat
          # d <- subset(d, !is.na(value))
          d <- d[!is.na(d$value), ]
          if (keep_rdesc && keep_cdesc) {
            # merge back in both row and column descriptors
            data.table::setattr(d, "names", c("id", "id.y", "value"))
            d <- merge(d, data.table::data.table(rdesc), by="id",
                       all.x=TRUE, ...)
            data.table::setnames(d, "id", "id.x")
            data.table::setnames(d, "id.y", "id")
            d <- merge(d, data.table::data.table(cdesc), by="id",
                       all.x=TRUE, ...)
            data.table::setnames(d, "id", "id.y")
          } else if (keep_rdesc) {
            # keep only row descriptors
            rdesc <- data.table::data.table(rdesc)
            data.table::setnames(rdesc, "id", "id.x")
            d <- merge(d, rdesc, by="id.x", all.x=TRUE, ...)
          } else if (keep_cdesc) {
            # keep only column descriptors
            cdesc <- data.table::data.table(cdesc)
            data.table::setnames(cdesc, "id", "id.y")
            d <- merge(d, cdesc, by="id.y", all.x=TRUE, ...)
          }
          # use suffixes if provided
          if (!is.null(suffixes) & length(suffixes) == 2) {
            newnames <- gsub("\\.x", suffixes[1], names(d))
            newnames <- gsub("\\.y", suffixes[2], newnames)
            data.table::setattr(d, "names", newnames)
          }
          message("done")
          return(d)
})


#' Check if x is a whole number
#'
#' @param x number to test
#' @param tol the allowed tolerance
#' @return boolean indicating whether x is tol away from a whole number value
#' @examples
#' is.wholenumber(1)
#' is.wholenumber(0.5)
#' @export
is.wholenumber <- function(x, tol = .Machine$double.eps^0.5)  {
  return(abs(x - round(x)) < tol)
}

#' Check whether \code{test_names} are columns in the \code{\link{data.frame}}
#' df
#' @param test_names a vector of column names to test
#' @param df the \code{\link{data.frame}} to test against
#' @param throw_error boolean indicating whether to throw an error if
#'   any \code{test_names} are not found in \code{df}
#' @return boolean indicating whether or not all \code{test_names} are
#'   columns of \code{df}
#' @examples 
#' check_colnames(c("pert_id", "pert_iname"), cdesc_char) # TRUE
#' check_colnames(c("pert_id", "foobar"),
#'   cdesc_char, throw_error=FALSE)# FALSE, suppress error
#' @export
check_colnames <- function(test_names, df, throw_error=TRUE) {
  # check whether test_names are valid names in df
  # throw error if specified
  diffs <- setdiff(test_names, names(df))
  if (length(diffs) > 0) {
    if (throw_error) {
      stop("the following column names are not found in ",
                 deparse(substitute(df)), ":\n",
                 paste(diffs, collapse=" "))
    } else {
      return(FALSE)
    }
  } else {
    return(TRUE)
  }
}

#' Do a robust \code{\link{data.frame}} subset to a set of ids
#' @param df \code{\link{data.frame}} to subset
#' @param ids the ids to subset to
#' @return a subset version of \code{df}
#' @keywords internal
subset_to_ids <- function(df, ids) {
  # helper function to do a robust df subset
  check_colnames("id", df)
  newdf <- data.frame(df[match(ids, df$id), ])
  names(newdf) <- names(df)
  return(newdf)
}


#' Subset a gct object using the provided row and column ids
#'
#' @param g a gct object
#' @param rid a vector of character ids or integer indices for ROWS
#' @param cid a vector of character ids or integer indices for COLUMNS
#' @return a GCT object
#' @examples
#' # first 10 rows and columns by index
#' (a <- subset_gct(ds, rid=1:10, cid=1:10))
#' 
#' # first 10 rows and columns using character ids
#' # use \code{ids} to extract the ids
#' rid <- ids(ds)
#' cid <- ids(ds, dimension="col")
#' (b <- subset_gct(ds, rid=rid[1:10], cid=cid[1:10]))
#' 
#' identical(a, b) # TRUE
#' 
#' @family GCT utilities
#' @export
setGeneric("subset_gct", function(g, rid=NULL, cid=NULL) {
  standardGeneric("subset_gct")
})
#' @rdname subset_gct
setMethod("subset_gct", signature("GCT"),
          function(g, rid, cid) {
          # ids can either be a vector of character strings corresponding
          # to row / column ids in the gct object, or integer vectors
          # corresponding to row / column indices
          if (is.null(rid)) rid <- ids(g)
          if (is.null(cid)) cid <- ids(g, dimension="col")
          ref_rid <- ids(g)
          ref_cid <- ids(g, dimension="col")
          # see whether we were given characters or integers
          # and handle accordingly
          process_ids <- function(ids, ref_ids, param) {
            # simple helper function to handle id/idx conversion
            # for character or integer ids
            if (is.character(ids)) {
              idx <- match(ids, ref_ids)
            } else if (all(is.wholenumber(ids))) {
              idx <- ids
            } else {
              stop(param, " must be character or integer")
            }
            idx <- idx[!is.na(idx)]
            ids <- ref_ids[idx]
            return(list(ids=ids, idx=idx))
          }
          processed_rid <- process_ids(rid, ref_rid, "rid")
          processed_cid <- process_ids(cid, ref_cid, "cid")
          rid <- processed_rid$ids
          ridx <- processed_rid$idx
          cid <- processed_cid$ids
          cidx <- processed_cid$idx
          sdrow <- setdiff(rid, ref_rid)
          sdcol <- setdiff(cid, ref_cid)
          if (length(sdrow) > 0) {
            warning("the following rids were not found:\n",
                    paste(sdrow, collapse="\n"))
          }
          if (length(sdcol) > 0) {
            warning("the following cids were not found:\n",
                    paste(sdcol, collapse="\n"))
          }
          # make sure ordering is right
          rid <- ref_rid[ridx]
          cid <- ref_cid[cidx]
          m <- mat(g)
          newm <- matrix(m[ridx, cidx], nrow=length(rid),
                         ncol=length(cid))
          # make sure annotations row ordering matches
          # matrix, rid, and cid
          rdesc <- meta(g)
          cdesc <- meta(g, dimension="col")
          newrdesc <- subset_to_ids(rdesc, rid)
          newcdesc <- subset_to_ids(cdesc, cid)
          newg <- GCT(mat=newm, rid=rid, cid=cid,
                      rdesc=newrdesc, cdesc=newcdesc)
          if (any(dim(newm) == 0)) {
            warning("one or more returned dimension is length 0 ",
                    "check that at least some of the provided rid and/or ",
                    "cid values have matches in the GCT object supplied")
          }
          return(newg)
})

#' Merge two GCT objects together
#'
#' @param g1 the first GCT object
#' @param g2 the second GCT object
#' @param dim the dimension on which to merge (row or column)
#' @param matrix_only boolean idicating whether to keep only the
#'   data matrices from \code{g1} and \code{g2} and ignore their
#'   row and column meta data
#' @return a GCT object
#' @examples
#' # take the first 10 and last 10 rows of an object
#' # and merge them back together
#' (a <- subset_gct(ds, rid=1:10))
#' (b <- subset_gct(ds, rid=969:978))
#' (merged <- merge_gct(a, b, dim="row"))
#' 
#' @family GCT utilities
#' @export
setGeneric("merge_gct", function(g1, g2, dim="row", matrix_only=FALSE) {
  standardGeneric("merge_gct")
})
#' @rdname merge_gct
setMethod("merge_gct", signature("GCT", "GCT"),
          function(g1, g2, dim, matrix_only) {
          # helper function to add new rows to a data.table
          add_new_records <- function(df1, df2, id_col="id") {
            df1 <- data.table::data.table(df1)
            df2 <- data.table::data.table(df2)
            data.frame(rbind(df1, df2[ !df2[[id_col]] %in% df1[[id_col]], ],
                             use.names=TRUE, fill=TRUE))
          }
          # given two gcts objects g1 and g2, merge them
          # on the specified dimension
          if (dim == "column") dim <- "col"
          if (dim == "row") {
            message("appending rows...")
            # need figure out the index for how to sort the columns of
            # g2@mat so that they are in sync with g1@mat
            # first na pad the matrices
            col_universe <- union(ids(g1, dimension="col"),
                                  ids(g2, dimension="col"))
            m1 <- na_pad_matrix(mat(g1), col_universe = col_universe)
            m2 <- na_pad_matrix(mat(g2), col_universe = col_universe)
            idx <- match(colnames(m1), colnames(m2))
            m <- rbind(m1, m2[, idx])
            if (!matrix_only) {
              # we're just appending rows so don't need to do anything
              # special with the rid or rdesc. just cat them
              rdesc <- data.frame(rbind(data.table::data.table(meta(g1)),
                                        data.table::data.table(meta(g2)),
                                        fill=TRUE))
              # update cdesc to include any new records
              cdesc <- add_new_records(meta(g1, dimension="col"),
                                       meta(g2, dimension="col"))
              idx <- match(colnames(m), cdesc$id)
              cdesc <- cdesc[idx, ]
              newg <- methods::new("GCT", mat=m, rdesc=rdesc, cdesc=cdesc)
            } else {
              newg <- methods::new("GCT", mat=m)
            }
          }
          else if (dim == "col") {
            message("appending columns...")
            # need figure out the index for how to sort the rows of
            # g2@mat so that they are in sync with g1@mat
            # first na pad the matrices
            row_universe <- union(ids(g1), ids(g2))
            m1 <- na_pad_matrix(mat(g1), row_universe = row_universe)
            m2 <- na_pad_matrix(mat(g2), row_universe = row_universe)
            idx <- match(rownames(m1), rownames(m2))
            m <- cbind(m1, m2[idx, ])
            if (!matrix_only) {
              # we're just appending rows so don't need to do anything
              # special with the rid or rdesc. just cat them
              cdesc <- data.frame(rbind(
                data.table::data.table(meta(g1, dimension="col")),
                data.table::data.table(meta(g2, dimension="col")),
                fill=TRUE))
              # update rdesc to include any new records
              rdesc <- add_new_records(meta(g1), meta(g2))
              idx <- match(rownames(m), rdesc$id)
              rdesc <- rdesc[idx, ]
              newg <- methods::new("GCT", mat=m, rdesc=rdesc, cdesc=cdesc)
            } else {
              newg <- methods::new("GCT", mat=m)
            }
          } else {
            stop("dimension must be either row or col")
          }
          return(newg)
})


#' Merge two \code{\link{data.frame}}s, but where there are common fields
#' those in \code{x} are retained and those in \code{y} are dropped.
#' 
#' @param x the \code{\link{data.frame}} whose columns take precedence
#' @param y another \code{\link{data.frame}}
#' @param by a vector of column names to merge on
#' @param allow.cartesian boolean indicating whether it's ok
#'   for repeated values in either table to merge with each other
#'   over and over again.
#' @param as_data_frame boolean indicating whether to ensure
#'   the returned object is a \code{\link{data.frame}} instead of a
#'   \code{\link{data.table}}.
#'   This ensures compatibility with GCT object conventions,
#'   that is, the \code{rdesc} and \code{cdesc} slots must be strictly
#'   \code{\link{data.frame}} objects.
#'   
#' @return a \code{\link{data.frame}} or \code{\link{data.table}} object
#' 
#' @examples 
#' (x <- data.table::data.table(foo=letters[1:10], bar=1:10))
#' (y <- data.table::data.table(foo=letters[1:10], bar=11:20,
#'   baz=LETTERS[1:10]))
#' # the 'bar' column from y will be dropped on merge
#' cmapR:::merge_with_precedence(x, y, by="foo")
#'
#' @keywords internal
#' @seealso data.table::merge
merge_with_precedence <- function(x, y, by, allow.cartesian=TRUE,
                                  as_data_frame = TRUE) {
  trash <- check_colnames(by, x)
  trash <- check_colnames(by, y)
  # cast as data.tables
  x <- data.table::data.table(x)
  y <- data.table::data.table(y)
  # get rid of row names
  data.table::setattr(x, "rownames", NULL)
  data.table::setattr(y, "rownames", NULL)
  common_cols <- intersect(names(x), names(y))
  y_keepcols <- unique(c(by, setdiff(names(y), common_cols)))
  y <- y[, y_keepcols, with=FALSE]
  # if not all ids match, issue a warning
  if (!all(x[[by]] %in% y[[by]])) {
    warning("not all rows of x had a match in y. some columns may contain NA")
  }
  # merge keeping all the values in x, making sure that the
  # resulting data.table is sorted in the same order as the 
  # original object x
  merged <- merge(x, y, by=by, allow.cartesian=allow.cartesian, all.x=TRUE)
  if (as_data_frame) {
    # cast back to a data.frame if requested
    merged <- data.frame(merged)
  }
  return(merged)
}


#' Add annotations to a GCT object
#' 
#' @description Given a GCT object and either a \code{\link{data.frame}} or
#' a path to an annotation table, apply the annotations to the
#' gct using the given \code{keyfield}.
#' 
#' @param g a GCT object
#' @param annot a \code{\link{data.frame}} or path to text table of annotations
#' @param dim either 'row' or 'column' indicating which dimension
#'   of \code{g} to annotate
#' @param keyfield the character name of the column in \code{annot} that 
#'   matches the row or column identifiers in \code{g}
#'   
#' @return a GCT object with annotations applied to the specified
#'   dimension
#'   
#' @examples 
#' gct_path <- system.file("extdata", "modzs_n25x50.gctx", package="cmapR")
#' # read the GCT file, getting the matrix only
#' g <- parse_gctx(gct_path, matrix_only=TRUE)
#' # separately, read the column annotations and then apply them using
#' # annotate_gct
#' cdesc <- read_gctx_meta(gct_path, dim="col")
#' g <- annotate_gct(g, cdesc, dim="col", keyfield="id")
#' 
#' 
#' @family GCT utilities
#' @export
setGeneric("annotate_gct", function(g, annot, dim="row", keyfield="id") {
  standardGeneric("annotate_gct")
})
#' @rdname annotate_gct
setMethod("annotate_gct", signature("GCT"),
          function(g, annot, dim, keyfield) {
          if (is.character(annot)) {
            # given a file path, try to read it in
            annot <- data.table::fread(annot)
          } else {
            # convert to data.table
            annot <- data.table::data.table(annot)
          }
          # convert the keyfield column to id for merging
          # assumes the gct object has an id field in its existing annotations
          if (!(keyfield %in% names(annot))) {
            stop("column ", keyfield, " not found in annotations")
          } 
          # rename the column to id so we can do the merge
          annot$id <- annot[[keyfield]]
          if (dim == "column") dim <- "col"
          if (dim == "row") {
            orig_id <- ids(g)
            rdesc <- meta(g)
            rdesc$id <- orig_id
            merged <- merge_with_precedence(rdesc, annot, by="id",
                                            allow.cartesian=T,
                                            as_data_frame=T)
            idx <- match(orig_id, merged$id)
            merged <- merged[idx, ]
            meta(g) <- merged
          } else if (dim == "col") {
            orig_id <- ids(g, dimension="col")
            cdesc <- meta(g, dimension="col")
            merged <- merge_with_precedence(cdesc, annot, by="id",
                                            allow.cartesian=T,
                                            as_data_frame=T)
            idx <- match(orig_id, merged$id)
            merged <- merged[idx, ]
            meta(g, dimension="col") <- merged
          } else {
            stop("dim must be either row or column")
          }
          return(g)
})


#' Transpose a GCT object
#' 
#' @param g the \code{GCT} object
#' 
#' @return a modified verion of the input \code{GCT} object
#'   where the matrix has been transposed and the row and column
#'   ids and annotations have been swapped.
#'   
#' @examples 
#' transpose_gct(ds)
#' 
#' @family GCT utilties
#' @export
setGeneric("transpose_gct", function(g) {
  standardGeneric("transpose_gct")
})
#' @rdname transpose_gct
setMethod("transpose_gct", signature("GCT"), function(g) {
  return(new("GCT", mat=t(mat(g)), rid=ids(g, dimension="col"), cid=ids(g),
              rdesc=meta(g, dimension="col"), cdesc=meta(g)))
})


#' Convert a GCT object's matrix to ranks
#' 
#' @param g the \code{GCT} object to rank
#' @param dim the dimension along which to rank
#'   (row or column)
#' @param decreasing boolean indicating whether
#'    higher values should get lower ranks
#' 
#' @return a modified version of \code{g}, with the
#'   values in the matrix converted to ranks
#'   
#' @examples 
#' (ranked <- rank_gct(ds, dim="column"))
#' # scatter rank vs. score for a few columns
#' m <- mat(ds)
#' m_ranked <- mat(ranked)
#' plot(m[, 1:3], m_ranked[, 1:3],
#'   xlab="score", ylab="rank")
#' 
#' @family GCT utilities
#' @importFrom matrixStats rowRanks colRanks
#' @export
setGeneric("rank_gct", function(g, dim="col", decreasing=TRUE) {
  standardGeneric("rank_gct")
})
#' @rdname rank_gct
setMethod("rank_gct", signature("GCT"), function(g, dim, decreasing=TRUE) {
  # check to make sure dim is allowed
  if (dim=="column") dim <- "col"
  if (!(dim %in% c("row","col"))){
    stop('Dim must be one of row, col')
  }
  # rank along the specified axis. transpose if ranking rows so that the data 
  # comes back in the correct format
  m <- mat(g)
  if (decreasing) m <- -1 * m
  if (dim == 'row'){
    m_ranked <- matrixStats::rowRanks(m, ties.method="average",
                                   preserveShape=TRUE)
  } else {
    m_ranked <- matrixStats::colRanks(m, ties.method="average",
                                   preserveShape=TRUE)
  }
  # done
  mat(g) <- m_ranked
  return(g)
})

#' Check for duplicates in a vector
#' @param x the vector
#' @param name the name of the object to print
#'   in an error message if duplicates are found
#' @return silently returns NULL
#' @examples 
#' # this will throw an erorr, let's catch it
#' tryCatch(
#'   check_dups(c("a", "b", "c", "a", "d")),
#'   error=function(e) print(e)
#'   )
#' @export
check_dups <- function(x, name="") {
  if (anyDuplicated(x)) {
    stop(name, " has duplicated values:",
               paste(x[duplicated(x)], collaps="\n"))
  }
}

#' Pad a matrix with additional rows/columns of NA values
#' 
#' @param m a matrix with unique row and column names
#' @param row_universe a vector with the universe of possible
#'   row names
#' @param col_universe a vector with the universe of possible
#'   column names
#' 
#' @return a matrix
#' 
#' @examples 
#' m <- matrix(rnorm(10), nrow=2)
#' rownames(m) <- c("A", "B")
#' colnames(m) <- letters[1:5]
#' na_pad_matrix(m, row_universe=LETTERS, col_universe=letters)
#' 
#' @export
na_pad_matrix <- function(m, row_universe=NULL, col_universe=NULL) {
  # make sure row/col names are assigned and unique
  if (is.null(colnames(m)) || is.null(rownames(m))) {
    stop("m must have unique row and column names assigned")
  }
  check_dups(rownames(m), name="m rownames")
  check_dups(colnames(m), name="m colnames")
  # get original row and col names
  orig_rows <- rownames(m)
  orig_cols <- colnames(m)
  # figure out which new rows to add
  if (is.null(row_universe)) {
    rows_to_add <- c()
  } else {
    rows_to_add <- setdiff(row_universe, orig_rows)
  }
  # figure out which new columns to add
  if (is.null(col_universe)) {
    cols_to_add <- c()
  } else {
    cols_to_add <- setdiff(col_universe, orig_cols)
  }
  # add new rows
  new_rows <- matrix(NA, ncol=ncol(m), nrow=length(rows_to_add))
  m <- rbind(m, new_rows)
  rownames(m) <- c(orig_rows, rows_to_add)
  # add new columns
  new_cols <- matrix(NA, ncol=length(cols_to_add), nrow=nrow(m))
  m <- cbind(m, new_cols)
  colnames(m) <- c(orig_cols, cols_to_add)
  return(m)
}

#' Align the rows and columns of two (or more) matrices
#' 
#' @param m1 a matrix with unique row and column names
#' @param m2 a matrix with unique row and column names
#' @param ... additional matrices with unique row and
#'   column names
#' @param L a list of matrix objects. If this is given,
#'   m1, m2, and ... are ignored
#' @param na.pad boolean indicating whether to pad the
#'   combined matrix with NAs for rows/columns that are
#'   not shared by m1 and m2.
#' @param as.3D boolean indicating whether to return the
#'   result as a 3D array. If FALSE, will return a list.
#'   
#' @return an object containing the aligned matrices. Will
#'   either be a list or a 3D array
#' 
#' @examples 
#' # construct some example matrices
#' m1 <- matrix(rnorm(20), nrow=4)
#' rownames(m1) <- letters[1:4]
#' colnames(m1) <- LETTERS[1:5]
#' m2 <- matrix(rnorm(20), nrow=5)
#' rownames(m2) <- letters[1:5]
#' colnames(m2) <- LETTERS[1:4]
#' m1
#' m2
#' 
#' # align them, padding with NA and returning a 3D array
#' align_matrices(m1, m2)
#' 
#' # align them, not padding and retuning a list
#' align_matrices(m1, m2, na.pad=FALSE, as.3D=FALSE)
#' 
#' @export
align_matrices <- function(m1, m2, ..., L=NULL, na.pad=TRUE, as.3D=TRUE) {
  # get the additional matrices if given
  if (!is.null(L)) {
    if (is.list(L) && all(unlist(lapply(L, is.matrix)))) {
      matrices <- L
    } else {
      stop("L must be a list of matrices")
    }
  } else {
    matrices <- list(m1, m2, ...) 
  }
  n_matrices <- length(matrices)
  # make sure row/col names are assigned and unique
  lapply(seq_len(n_matrices), function(i) {
    if (is.null(colnames(matrices[[i]])) ||
        is.null(rownames(matrices[[i]]))) {
      stop("matrix ", i, " must have unique row and column names")
    }
    check_dups(rownames(matrices[[i]]), name=paste("matrix", i, "rownames"))
    check_dups(colnames(matrices[[i]]), name=paste("matrix", i, "colnames"))
  })
  # figure out the common rows and columns
  common_rows <- sort(Reduce(intersect, lapply(matrices, rownames)))
  common_cols <- sort(Reduce(intersect, lapply(matrices, colnames)))
  # if we're not NA padding, this is all we need to do
  if (!na.pad) {
    matrices <- lapply(matrices, function(m) {
      m[common_rows, common_cols]
    })
  } else {
    # transform the matrices so that they contain the
    # union of rows/cols padded with NA where needed
    row_universe <- sort(Reduce(union, lapply(matrices, rownames)))
    col_universe <- sort(Reduce(union, lapply(matrices, colnames)))
    matrices <- lapply(matrices, function(m) {
      padded <- na_pad_matrix(m, row_universe=row_universe,
                    col_universe=col_universe)
      # rearrange the rows and columns so they're in a consistent order
      # for each matrix
      padded[row_universe, col_universe]
    })
  }
  # if we're not converting to 3D array, return a list
  if (!as.3D) {
    return(matrices)
  } else {
    # initialize an empty 3D array
    arr3d <-
      array(NA,
            dim=c(length(row_universe), length(col_universe), length(matrices)),
            # set the dimnames using the first matrix b/c we assume they're the
            # same for all matrices
            dimnames=list(rownames(matrices[[1]]), colnames(matrices[[1]]),
                              names(matrices)))
    # and fill with the aligned matrices
    for (i in seq_along(matrices)) {
      arr3d[, , i] <- matrices[[i]]
    }
    return(arr3d)
  }
}

# TODO: update to act as an S4 method for GCT class
#' Exract elements from a GCT matrix
#' 
#' @param g the GCT object
#' @param row_field the column name in rdesc to search on
#' @param col_field the column name in cdesc to search on
#' @param rdesc a \code{data.frame} of row annotations
#' @param cdesc a \code{data.frame} of column annotations
#' @param row_keyfield the column name of \code{rdesc} to use
#'    for annotating the rows of \code{g}
#' @param col_keyfield the column name of \code{cdesc} to use
#'    for annotating the rows of \code{g}
#' 
#' @description extract the elements from a \code{GCT} object
#'   where the values of \code{row_field} and \code{col_field}
#'   are the same. A concrete example is if \code{g} represents
#'   a matrix of signatures of genetic perturbations, and you wan
#'   to extract all the values of the targeted genes.
#'   
#' @return a list of the following elements
#' \describe{
#'   \item{mask}{a logical matrix of the same dimensions as
#'         \code{ds@mat} indicating which matrix elements have
#'         been extracted}
#'  \item{idx}{an array index into \code{ds@mat}
#'         representing which elements have been extracted}
#'  \item{vals}{a vector of the extracted values}
#'  }
#' 
#' @examples
#' # get the values for all targeted genes from a 
#' # dataset of knockdown experiments 
#' res <- extract_gct(kd_gct, row_field="pr_gene_symbol",
#'   col_field="pert_mfc_desc")
#' str(res)
#' stats::quantile(res$vals)
#' 
#' @export
extract_gct <- function(g, row_field, col_field,
                        rdesc=NULL, cdesc=NULL,
                        row_keyfield="id", col_keyfield="id") {
  # annotate the gct object if external annotations have been provided
  if (!is.null(rdesc)) {
    g <- annotate_gct(g, rdesc, dim="row", keyfield=row_keyfield)
  }
  if (!is.null(cdesc)) {
    g <- annotate_gct(g, cdesc, dim="col", keyfield=col_keyfield)
  }
  rdesc <- data.table::data.table(meta(g))
  cdesc <- data.table::data.table(meta(g, dimension="col"))
  # what are the common values
  common_vals <- intersect(rdesc[[row_field]], cdesc[[col_field]])
  m <- mat(g)
  mask <- matrix(FALSE, nrow=nrow(m), ncol=ncol(m))
  for (v in common_vals) {
    ridx <- which(rdesc[[row_field]] == v)
    cidx <- which(cdesc[[col_field]] == v)
    mask[ridx, cidx] <- TRUE
  }
  idx <- which(mask, arr.ind=TRUE)
  vals <- m[mask]
  # data.frame containing the extracted values
  # alongside their row and column annotations
  df <- cbind(
    {
      x <- rdesc[idx[, 1], ]
      data.table::setattr(x, "names", paste("row", names(x), sep="_"))
      x
    },
    {
      y <- cdesc[idx[, 2], ]
      data.table::setattr(y, "names", paste("col", names(y), sep="_"))
      y
    })
  df$value <- vals
  return(list(
    mask = mask,
    idx = idx,
    vals = vals,
    df = df 
  ))
}

#' Aggregate rows or columns of a GCT object that have the same value
#' for a given annotation field
#' 
#' @param g the GCT object
#' @param dimension which dimension to aggregate over (either "row" or "column")
#' @param agg_field the name of the field to aggregate
#' @param agg_fun the function to use for aggregating
#' 
#' @details If `dimension` is "row", `agg_field` should correspond to a field
#' in the `rdesc` `data.frame` of `g`. If `dimension` is "column", it should
#' correspond to a field in `cdesc`.
#' `agg_fun` can be any function that accepts a numeric vector and returns a
#' scalar value.
#' The returned GCT object will contain an additional field called `n_agg` that
#' indicates the number of rows or columns that were aggregated.
#' 
#' @return a GCT object
#' 
#' @examples 
#' # construct a simple GCT object with duplicated values in one of the row
#' # annotation fields
#' tmp <- GCT(mat=matrix(rnorm(100), nrow=20), cid=letters[1:5],
#'            rid=LETTERS[1:20],
#'            rdesc=data.frame(id=LETTERS[1:20],
#'                             field=sample(c("foo", "bar", "baz"), 20,
#'                             replace=T)),
#'            cdesc=data.frame(id=letters[1:5]))
aggregate_gct <- function(g, agg_field, dimension="row",
                          agg_fun=stats::median, overwrite_ids=TRUE) {
  # check arguments and fail if any issues
  stopifnot(class(g) == "GCT")
  stopifnot(is.logical(overwrite_ids))
  stopifnot(dimension %in% c("row", "column"))
  # convert to shorthand
  if (dimension == "column") dimension <- "col"
  # assume we're operating on the rows
  # if not, transpose the GCT object
  if (dimension == "col") {
    g <- transpose_gct(g)
  }
  # make sure the field to aggregate actually exists
  stopifnot(agg_field %in% names(g@rdesc))
  # figure out which rows have duplicate values and which don't
  # compute a frequency table of each value in the supplied field
  freq <- table(g@rdesc[[agg_field]])
  dup_vals <- names(freq[freq > 1])
  # create lists of the row indices corresponding to rows that do need to be 
  # aggregated (because of duplicates)
  g_dup <- subset_gct(g, rid=which(g@rdesc[[agg_field]] %in% dup_vals))
  grps <- split(seq_len(nrow(g_dup@mat)), g_dup@rdesc[[agg_field]])
  # pre-allocate a matrix to store the aggregated values
  agg_mat <- matrix(nrow=length(grps), ncol=ncol(g_dup@mat))
  # do the aggregation for each group
  for (i in seq_along(grps)) {
    idx <- grps[[i]]
    agg_mat[i, ] <- apply(g_dup@mat[idx, ], 2, agg_fun)
  }
  rownames(agg_mat) <- names(grps)
  colnames(agg_mat) <- g_dup@cid
  # and a data.table to store the aggregated metadata
  # cast as a data.table to take advantage of aggregation capability
  agg_meta <- data.table::data.table(g_dup@rdesc)
  agg_meta <- agg_meta[, lapply(.SD, paste, collapse="|"), by=agg_field]
  # add a field to track the number of rows that were aggregated
  agg_meta$n_agg <- lengths(grps)[match(agg_meta[[agg_field]], names(grps))]
  # reassemble into a GCT object
  g_agg <- GCT(agg_mat)
  g_agg@rdesc <- data.frame(id=names(grps))
  # apply annotations, overwriting the old id column
  agg_meta$id <- agg_meta[[agg_field]]
  g_agg <- annotate_gct(g_agg, agg_meta, dim="row", keyfield=agg_field)
  # handle those rows that didn't need to be aggregated (if any)
  nondup_vals <- names(freq[freq == 1])
  if (length(nondup_vals) > 0) {
    # slice out the rows that only have one value and don't need to be aggregated
    g_nondup <- subset_gct(g, rid=which(g@rdesc[[agg_field]] %in% nondup_vals))
    # merge together with the un-aggregated data and update the identifiers
    # to be the unique values of agg_field
    g_nondup@rdesc$n_agg <- 1
    g_nondup@rid <- rownames(g_nondup@mat) <- g_nondup@rdesc$id <- 
      g_nondup@rdesc[[agg_field]]
    g_agg <- merge_gct(g_nondup, g_agg, dim="row")
  }
  # if we had originally transposed, transpose back
  if (dimension == "col") {
    g_agg <- transpose_gct(g_agg)
  }
  return(g_agg)
}

