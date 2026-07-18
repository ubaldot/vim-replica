# r_init.R — vim-replica TCP server for R
#
# Starts a JSON-RPC TCP server on port 6969, mirroring the Python/Julia
# servers. The server runs non-blockingly via the 'later' package, which
# fires callbacks in R's event loop while R is idle at the interactive prompt.
#
# Requires: jsonlite, later

for (.pkg in c("jsonlite", "later")) {
  if (!requireNamespace(.pkg, quietly = TRUE))
    stop(sprintf("[vim-replica] Package '%s' is required. Install with: install.packages('%s')",
                 .pkg, .pkg))
}
rm(.pkg)

library(jsonlite, quietly = TRUE)
library(later,    quietly = TRUE)

.VIM_PORT <- 6969L
.vim_srv  <- serverSocket(.VIM_PORT)
.vim_conn <- NULL

# --- JSON-RPC transport -----------------------------------------------------

.vim_send_response <- function(conn, data) {
  payload <- charToRaw(jsonlite::toJSON(data, auto_unbox = TRUE))
  header  <- charToRaw(sprintf("Content-Length: %d\r\n\r\n", length(payload)))
  writeBin(c(header, payload), conn)
  flush(conn)
}

.vim_error_response <- function(conn, id, code, msg) {
  .vim_send_response(conn, list(
    jsonrpc = "2.0", id = id,
    error = list(code = code, message = msg)
  ))
}

.vim_read_message <- function(conn) {
  tryCatch({
    hdr <- trimws(readLines(conn, n = 1L, warn = FALSE))
    if (!nzchar(hdr)) return(NULL)
    n <- as.integer(regmatches(hdr, regexpr("[0-9]+", hdr)))
    if (is.na(n)) return(NULL)
    readLines(conn, n = 1L, warn = FALSE)        # blank separator line
    body <- readBin(conn, raw(), n = n)
    if (!length(body)) return(NULL)
    jsonlite::fromJSON(rawToChar(body), simplifyVector = FALSE)
  }, error = function(e) NULL)
}

# --- Handlers ---------------------------------------------------------------

.vim_inspect <- function(conn, id, params) {
  expr  <- params[["variable"]]
  lines <- tryCatch({
    obj <- eval(parse(text = expr), envir = .GlobalEnv)
    capture.output(print(obj))
  }, error = function(e) conditionMessage(e))
  .vim_send_response(conn, list(jsonrpc = "2.0", id = id, result = as.list(lines)))
}

.vim_whos <- function(conn, id, params) {
  lines <- tryCatch({
    capture.output({
      nms <- setdiff(ls(envir = .GlobalEnv),
                     c(".__S3MethodsTable__.", ".Random.seed"))
      nms <- nms[!startsWith(nms, ".")]
      if (!length(nms)) { cat("No user variables.\n"); return() }
      info <- lapply(nms, function(nm) {
        obj <- get(nm, envir = .GlobalEnv)
        sz  <- if (is.data.frame(obj) || is.matrix(obj))
                 paste(dim(obj), collapse = "x")
               else if (length(obj) > 1L && is.atomic(obj))
                 paste0("len=", length(obj))
               else ""
        c(nm, class(obj)[[1L]], sz)
      })
      m  <- do.call(rbind, info)
      ws <- apply(m, 2L, function(x) max(nchar(x, "width")))
      for (i in seq_len(nrow(m)))
        cat(sprintf("%-*s  %-*s  %s\n",
                    ws[1L], m[i, 1L], ws[2L], m[i, 2L], m[i, 3L]))
    })
  }, error = function(e) conditionMessage(e))
  .vim_send_response(conn, list(jsonrpc = "2.0", id = id, result = as.list(lines)))
}

.vim_variable_names <- function(conn, id, params) {
  nms <- tryCatch({
    objs <- setdiff(ls(envir = .GlobalEnv),
                    c(".__S3MethodsTable__.", ".Random.seed"))
    sort(objs[!startsWith(objs, ".")])
  }, error = function(e) character(0L))
  .vim_send_response(conn, list(jsonrpc = "2.0", id = id, result = as.list(nms)))
}

.VIM_METHODS <- list(
  "runtime/vim_inspect"        = .vim_inspect,
  "runtime/vim_whos"           = .vim_whos,
  "runtime/vim_variable_names" = .vim_variable_names
)

.vim_handle_request <- function(conn, msg) {
  id      <- msg[["id"]]
  method  <- msg[["method"]]
  params  <- if (!is.null(msg[["params"]])) msg[["params"]] else list()
  handler <- .VIM_METHODS[[method]]
  if (is.null(handler)) {
    .vim_error_response(conn, id, -32601L, paste0("Method not found: ", method))
    return(invisible(NULL))
  }
  tryCatch(
    handler(conn, id, params),
    error = function(e) .vim_error_response(conn, id, -32603L, conditionMessage(e))
  )
}

# --- Non-blocking poll loop (via 'later') -----------------------------------
#
# later::later() schedules callbacks in R's event loop, which fires even
# while R is idle at the interactive prompt — unlike addTaskCallback(), which
# only fires between top-level expressions.

.vim_poll <- function() {
  tryCatch({
    if (is.null(.vim_conn)) {
      # Check for an incoming connection on the server socket
      if (isTRUE(socketSelect(list(.vim_srv), timeout = 0)[[1L]])) {
        .vim_conn <<- socketAccept(.vim_srv, open = "r+b")
        message("Vim connected from localhost")
      }
    } else {
      # Check if data is available on the existing connection
      if (isTRUE(socketSelect(list(.vim_conn), timeout = 0)[[1L]])) {
        msg <- .vim_read_message(.vim_conn)
        if (!is.null(msg)) {
          .vim_handle_request(.vim_conn, msg)
        } else {
          # Client closed the connection
          close(.vim_conn)
          .vim_conn <<- NULL
        }
      }
    }
  }, error = function(e) {
    if (!is.null(.vim_conn))
      tryCatch({ close(.vim_conn); .vim_conn <<- NULL }, error = function(e) NULL)
  })
  later::later(.vim_poll, delay = 0.05)   # reschedule every 50 ms
}

message("R TCP server running on 127.0.0.1:", .VIM_PORT)
later::later(.vim_poll, delay = 0.1)
