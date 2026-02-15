
.VIM_SENTINEL_START <- "__VIM_PAYLOAD__"
.VIM_SENTINEL_END   <- "__END__"

.vim_change_prompt <- function(expr) {
  options(prompt = expr)
}

.vim_inspect <- function(expr) {
  buf <- NULL

  out <- tryCatch({
    capture.output({
      obj <- eval(parse(text = expr), envir = .GlobalEnv)

      # Data frame
      if (is.data.frame(obj)) {
        print(obj)

      # Matrix / array
      } else if (is.matrix(obj) || is.array(obj)) {
        print(obj)

      # Vector
      } else if (is.atomic(obj)) {
        print(obj)

      # List
      } else if (is.list(obj)) {
        str(obj)

      # Function
      } else if (is.function(obj)) {
        print(obj)

      } else {
        print(obj)
      }
    })
  }, error = function(e) {
    paste0("[vim_inspect error] ", conditionMessage(e))
  })

  # Ensure trailing newline
  text_payload <- paste(out, collapse = "\n")
  if (!grepl("\n$", text_payload)) {
    text_payload <- paste0(text_payload, "\n")
  }

  payload <- base64enc::base64encode(charToRaw(text_payload))

  cat(sprintf("%s%s%s",
              .VIM_SENTINEL_START,
              payload,
              .VIM_SENTINEL_END))
}


.vim_whos <- function(max_preview = 5) {
  out <- tryCatch({
    capture.output({
      objs <- ls(envir = .GlobalEnv)
      if (length(objs) == 0) {
        cat("No user variables.\n")
        return()
      }

      info <- lapply(objs, function(name) {
        obj <- get(name, envir = .GlobalEnv)
        cls <- class(obj)[1]
        dim_info <- ""
        preview <- ""

        # Scalars / atomic vectors
        if (is.atomic(obj) && !is.matrix(obj) && !is.data.frame(obj)) {
          if (length(obj) > 1) dim_info <- paste0("len=", length(obj))
          preview <- paste(head(obj, max_preview), collapse = ", ")
          if (length(obj) > max_preview) preview <- paste0(preview, ", ...")

        # Factors
        } else if (is.factor(obj)) {
          dim_info <- paste0("levels=", length(levels(obj)))
          preview <- paste(head(as.character(obj), max_preview), collapse = ", ")
          if (length(obj) > max_preview) preview <- paste0(preview, ", ...")

        # Lists
        } else if (is.list(obj)) {
          dim_info <- paste0("len=", length(obj))
          preview <- paste(sapply(head(obj, max_preview), function(x) {
            if (is.atomic(x)) {
              paste(x, collapse = ",")
            } else {
              class(x)[1]
            }
          }), collapse = ", ")
          if (length(obj) > max_preview) preview <- paste0(preview, ", ...")

        # Matrices / arrays
        } else if (is.matrix(obj) || is.array(obj)) {
          dim_info <- paste(dim(obj), collapse = "x")
          preview <- paste(head(obj[1, , drop = TRUE], max_preview), collapse = ", ")
          if (ncol(obj) > max_preview) preview <- paste0(preview, ", ...")

        # Data frames
        } else if (is.data.frame(obj)) {
          dim_info <- paste(dim(obj), collapse = "x")
          preview <- paste(head(obj[1, , drop = TRUE]), collapse = ", ")
          if (ncol(obj) > max_preview) preview <- paste0(preview, ", ...")

        # Functions
        } else if (is.function(obj)) {
          dim_info <- ""
          preview <- ""

        # Anything else
        } else {
          dim_info <- ""
          preview <- ""
        }

        c(name, cls, dim_info, preview)
      })

      # Convert to matrix
      info_mat <- do.call(rbind, info)

      # Compute column widths
      col_widths <- apply(info_mat, 2, function(x) max(nchar(x, type = "width"), na.rm = TRUE))

      # Print table nicely
      for (i in seq_len(nrow(info_mat))) {
        cat(sprintf("%-*s  %-*s  %-*s  %s\n",
                    col_widths[1], info_mat[i,1],
                    col_widths[2], info_mat[i,2],
                    col_widths[3], info_mat[i,3],
                    info_mat[i,4]))
      }
    })
  }, error = function(e) {
    paste0("[vim_whos error] ", conditionMessage(e))
  })

  # Base64 encode payload
  text_payload <- paste(out, collapse = "\n")
  if (!grepl("\n$", text_payload)) text_payload <- paste0(text_payload, "\n")
  payload <- base64enc::base64encode(charToRaw(text_payload))

  cat(sprintf("%s%s%s", .VIM_SENTINEL_START, payload, .VIM_SENTINEL_END))
}


.vim_variable_names <- function() {
  out <- tryCatch({
    capture.output({
      objs <- ls(envir = .GlobalEnv)

      EXCLUDE_NAMES <- c(
        ".__S3MethodsTable__.",
        ".Random.seed"
      )

      names <- objs[
        !startsWith(objs, "_") &
        !(objs %in% EXCLUDE_NAMES)
      ]

      cat(paste(names, collapse = "\n"), "\n")
    })
  }, error = function(e) {
    paste0("[vim_get_variables error] ", conditionMessage(e))
  })

  text_payload <- paste(out, collapse = "\n")
  if (!grepl("\n$", text_payload)) {
    text_payload <- paste0(text_payload, "\n")
  }

  payload <- base64enc::base64encode(charToRaw(text_payload))

  cat(sprintf("%s%s%s",
              .VIM_SENTINEL_START,
              payload,
              .VIM_SENTINEL_END))
}
