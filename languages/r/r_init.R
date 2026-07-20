# r_init.R -- vim-replica TCP server for R
#
# Requires:
#   install.packages(c("jsonlite", "later"))

message("interactive = ", interactive())

for (.pkg in c("jsonlite", "later")) {
  if (!requireNamespace(.pkg, quietly = TRUE))
    stop(sprintf(
      "[vim-replica] Package '%s' is required. Install with install.packages('%s')",
      .pkg,
      .pkg
    ))
}
rm(.pkg)

library(jsonlite, quietly = TRUE)
library(later, quietly = TRUE)

.VIM_PORT <- 6969L

# ---------------------------------------------------------------------------
# Global state
# ---------------------------------------------------------------------------

.vim_srv <- serverSocket(.VIM_PORT)
.vim_conn <- NULL

message("R TCP server running on 127.0.0.1:", .VIM_PORT)

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

      ws <- apply(
        m,
        2,
        function(x) max(nchar(x))
      )

      for (i in seq_len(nrow(m))) {

        cat(sprintf(
          "%-*s  %-*s  %s\n",
          ws[1],
          m[i, 1],
          ws[2],
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

  params <- msg[["params"]]

  if (is.null(params))
    params <- list()

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
# Polling
# ---------------------------------------------------------------------------

.vim_poll <- function() {

  tryCatch({

    if (is.null(.vim_conn)) {

      ready <- socketSelect(
        list(.vim_srv),
        timeout = 0
      )[[1]]

      if (isTRUE(ready)) {

        .vim_conn <<- socketAccept(
          .vim_srv,
          blocking = FALSE,
          open = "r+b"
        )

        message("Vim connected")
      }

    } else {

      repeat {

        ready <- socketSelect(
          list(.vim_conn),
          timeout = 0
        )[[1]]

        if (!isTRUE(ready))
          break

        msg <- .vim_read_message(.vim_conn)

        if (is.null(msg)) {

          try(close(.vim_conn), silent = TRUE)

          .vim_conn <<- NULL

          message("Connection closed")
          break
        }

        .vim_handle_request(
          .vim_conn,
          msg
        )
      }
    }

  }, error = function(e) {

    message(
      "[vim-replica] ",
      conditionMessage(e)
    )

    if (!is.null(.vim_conn)) {

      try(close(.vim_conn), silent = TRUE)

      .vim_conn <<- NULL
    }
  })

  later::later(.vim_poll, 0.05)
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

later::later(function() {
  message("[vim-replica] later callback is running")
}, 1)

later::later(.vim_poll, 0.05)

message("[vim-replica] polling started")
