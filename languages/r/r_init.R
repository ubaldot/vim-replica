# r_init.R -- vim-replica TCP server for R
#
# Simple single-client JSON-RPC server.
#
# Requires:
#   install.packages("jsonlite")

message("interactive = ", interactive())

if (!requireNamespace("jsonlite", quietly = TRUE))
  stop(
    "[vim-replica] Package 'jsonlite' is required. ",
    "Install with install.packages('jsonlite')"
  )

library(jsonlite, quietly = TRUE)

.VIM_PORT <- 6969L

# ---------------------------------------------------------------------------
# Transport
# ---------------------------------------------------------------------------

.vim_send_response <- function(conn, data) {

  payload <- charToRaw(
    jsonlite::toJSON(
      data,
      auto_unbox = TRUE,
      null = "null"
    )
  )

  header <- charToRaw(
    sprintf(
      "Content-Length: %d\r\n\r\n",
      length(payload)
    )
  )

  writeBin(c(header, payload), conn)
  flush(conn)
}

.vim_error_response <- function(conn, id, code, msg) {

  .vim_send_response(conn, list(
    jsonrpc = "2.0",
    id = id,
    error = list(
      code = code,
      message = msg
    )
  ))
}

.vim_read_message <- function(conn) {

  tryCatch({

    hdr <- trimws(
      readLines(
        conn,
        n = 1L,
        warn = FALSE
      )
    )

    if (!nzchar(hdr))
      return(NULL)

    n <- as.integer(
      regmatches(
        hdr,
        regexpr("[0-9]+", hdr)
      )
    )

    if (is.na(n))
      return(NULL)

    readLines(
      conn,
      n = 1L,
      warn = FALSE
    )

    body <- readBin(
      conn,
      raw(),
      n = n
    )

    if (!length(body))
      return(NULL)

    jsonlite::fromJSON(
      rawToChar(body),
      simplifyVector = FALSE
    )

  }, error = function(e) {
    NULL
  })
}

# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

.vim_inspect <- function(conn, id, params) {

  expr <- params[["variable"]]

  lines <- tryCatch({

    obj <- eval(
      parse(text = expr),
      envir = .GlobalEnv
    )

    capture.output(print(obj))

  }, error = function(e) {

    conditionMessage(e)

  })

  .vim_send_response(conn, list(
    jsonrpc = "2.0",
    id = id,
    result = as.list(lines)
  ))
}

.vim_whos <- function(conn, id, params) {

  lines <- tryCatch({

    capture.output({

      nms <- setdiff(
        ls(envir = .GlobalEnv),
        c(
          ".__S3MethodsTable__.",
          ".Random.seed"
        )
      )

      nms <- nms[!startsWith(nms, ".")]

      if (!length(nms)) {
        cat("No user variables.\n")
        return()
      }

      info <- lapply(nms, function(nm) {

        obj <- get(
          nm,
          envir = .GlobalEnv
        )

        sz <- if (is.data.frame(obj) || is.matrix(obj)) {
          paste(dim(obj), collapse = "x")
        } else if (is.atomic(obj) && length(obj) > 1L) {
          paste0("len=", length(obj))
        } else {
          ""
        }

        c(
          nm,
          class(obj)[1],
          sz
        )
      })

      m <- do.call(rbind, info)

      widths <- apply(
        m,
        2,
        function(x) max(nchar(x))
      )

      for (i in seq_len(nrow(m))) {

        cat(sprintf(
          "%-*s  %-*s  %s\n",
          widths[1],
          m[i, 1],
          widths[2],
          m[i, 2],
          m[i, 3]
        ))
      }
    })

  }, error = function(e) {

    conditionMessage(e)

  })

  .vim_send_response(conn, list(
    jsonrpc = "2.0",
    id = id,
    result = as.list(lines)
  ))
}

.vim_variable_names <- function(conn, id, params) {

  vars <- tryCatch({

    objs <- setdiff(
      ls(envir = .GlobalEnv),
      c(
        ".__S3MethodsTable__.",
        ".Random.seed"
      )
    )

    sort(
      objs[!startsWith(objs, ".")]
    )

  }, error = function(e) {

    character(0)

  })

  .vim_send_response(conn, list(
    jsonrpc = "2.0",
    id = id,
    result = as.list(vars)
  ))
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

.VIM_METHODS <- list(
  "runtime/vim_inspect"        = .vim_inspect,
  "runtime/vim_whos"           = .vim_whos,
  "runtime/vim_variable_names" = .vim_variable_names
)

.vim_handle_request <- function(conn, msg) {

  id <- msg[["id"]]
  method <- msg[["method"]]

  handler <- .VIM_METHODS[[method]]

  if (is.null(handler)) {

    .vim_error_response(
      conn,
      id,
      -32601L,
      paste("Method not found:", method)
    )

    return(invisible(NULL))
  }

  params <- msg[["params"]]

  if (is.null(params))
    params <- list()

  tryCatch({

    handler(
      conn,
      id,
      params
    )

  }, error = function(e) {

    .vim_error_response(
      conn,
      id,
      -32603L,
      conditionMessage(e)
    )

  })
}

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

.vim_srv <- serverSocket(.VIM_PORT)

message(
  "R TCP server running on 127.0.0.1:",
  .VIM_PORT
)

repeat {

  message("Waiting for Vim connection...")

  conn <- socketAccept(
    .vim_srv,
    blocking = TRUE,
    open = "r+b"
  )

  message("Vim connected")

  repeat {

    msg <- .vim_read_message(conn)

    if (is.null(msg))
      break

    .vim_handle_request(
      conn,
      msg
    )
  }

  try(close(conn), silent = TRUE)

  message("Connection closed")
}
