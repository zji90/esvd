#' Initialization for matrix factorization
#'
#' @param dat dataset where the \code{n} rows represent cells and \code{d} columns represent genes
#' @param k positive integer
#' @param family either \code{"gaussian"} or \code{"exponential"}
#' @param max_val maximum value of the inner product (with the correct sign)
#' @param max_iter numeric
#' @param tol numeric
#' @param verbose boolean
#' @param ... extra arguments
#'
#' @return list
#' @export
initialization <- function(dat, k = 2, family = "exponential",
                           max_val = NA,
                           max_iter = 10, tol = 1e-3,
                           verbose = F, ...){
  direction <- .dictate_direction(family)

  # initialize
  dat <- .matrix_completion(dat, k = k)
  if(length(class(dat)) == 1) class(dat) <- c(family, class(dat)[length(class(dat))])

  # projected gradient descent
  pred_mat <- .projected_gradient_descent(dat, k = k, max_val = max_val,
                                          direction = direction,
                                          max_iter = max_iter,
                                          tol = tol, ...)

  res <- .svd_projection(pred_mat, k = k, factors = T)
  u_mat <- res$u_mat; v_mat <- res$v_mat

  if(direction == "<=") {
    stopifnot(all(pred_mat[which(!is.na(dat))] < 0))
  } else {
    stopifnot(all(pred_mat[which(!is.na(dat))] > 0))
  }

  list(u_mat = u_mat, v_mat = v_mat)
}

##################################

# enforces all the resulting entries to be non-negative
.matrix_completion <- function(dat, k){
  if(any(is.na(dat))){
    lambda0_val <- softImpute::lambda0(dat)
    res <- softImpute::softImpute(dat, rank.max = k, lambda = min(30, lambda0_val/100))
    pred_naive <- res$u %*% diag(res$d) %*% t(res$v)
    dat[which(is.na(dat))] <- pred_naive[which(is.na(dat))]
  }

  abs(dat)
}

.determine_initial_matrix <- function(dat, family, k, max_val = NA){
  min_val <- min(dat[which(dat > 0)])
  dat[which(dat <= 0)] <- min_val/2
  pred_mat <- .mean_transformation(dat, family)
  direction <- .dictate_direction(family)

  class(pred_mat) <- "matrix" #bookeeping purposes
  .nonnegative_matrix_factorization(pred_mat, k = k, direction = direction,
                                    max_val = max_val)
}

.projected_gradient_descent <- function(dat, k = 2,
                                        max_val = NA, direction = "<=",
                                        max_iter = 50, tol = 1e-3,
                                        ...){
  n <- nrow(dat); d <- ncol(dat)
  pred_mat <- .determine_initial_matrix(dat, class(dat)[1], k = k, max_val = max_val)
  iter <- 1
  new_obj <- .evaluate_objective_mat(dat, pred_mat, ...)
  old_obj <- Inf

  while(abs(new_obj - old_obj) > tol & iter < max_iter){
    old_obj <- new_obj
    gradient_mat <- .gradient_mat(dat, pred_mat, ...)
    new_mat <- .adaptive_gradient_step(dat, pred_mat, gradient_mat, k = k,
                                       max_val = max_val, direction = direction,
                                       ...)

    new_obj <- .evaluate_objective_mat(dat, new_mat, ...)
    pred_mat <- new_mat
    iter <- iter + 1
  }

  pred_mat
}

.svd_projection <- function(mat, k, factors = F,
                            u_alone = F, v_alone = F){
  res <- svd(mat)

  if(k == 1){
    diag_mat <- matrix(res$d[1], 1, 1)
  } else {
    diag_mat <- diag(res$d[1:k])
  }

  if(factors){
    if(u_alone){
      list(u_mat = res$u[,1:k,drop = F],
           v_mat = res$v[,1:k,drop = F]%*%diag_mat)
    } else if(v_alone) {
      list(u_mat = res$u[,1:k,drop = F]%*%diag_mat,
           v_mat = res$v[,1:k,drop = F])
    } else {
      list(u_mat = res$u[,1:k,drop = F]%*%sqrt(diag_mat),
           v_mat = res$v[,1:k,drop = F]%*%sqrt(diag_mat))
    }
  } else {
    res$u[,1:k,drop = F] %*% diag_mat %*% t(res$v[,1:k,drop = F])
  }
}

#' Adaptive projective gradient descent
#'
#' The projective gradient descent is "adaptive" in the sense
#' that it will find an appropriate step size to ensure that after projection,
#' the objective value descreases. This is a heuristic to simply enable
#' reasonable results, not necessarily theoretically justified or computationally
#' efficient.
#'
#' @param dat dataset where the \code{n} rows represent cells and \code{d} columns represent genes
#' @param pred_mat \code{n} by \code{d} matrix
#' @param gradient_mat \code{n} by \code{d} matrix
#' @param k numeric
#' @param max_val numeric or \code{NA}
#' @param direction "<=" or ">="
#' @param stepsize_init numeric
#' @param stepdown_factor numeric
#' @param max_iter numeric
#' @param ... other parameters
#'
#' @return \code{n} by \code{d} matrix
.adaptive_gradient_step <- function(dat, pred_mat, gradient_mat, k,
                                    max_val = NA, direction = "<=",
                                    stepsize_init = 100, stepdown_factor = 2,
                                    max_iter = 20, ...){
  stepsize <- stepsize_init
  init_obj <- .evaluate_objective_mat(dat, pred_mat, ...)
  iter <- 1

  while(iter > max_iter){
    res <- pred_mat - stepsize*gradient_mat
    new_mat <- .project_rank_feasibility(res, direction = direction,
                               max_val = max_val)

    if(!any(is.na(new_mat))){
      new_obj <- .evaluate_objective_mat(dat, new_mat, ...)

      if(new_obj < init_obj) return(new_mat)
    }

    stepsize <- stepsize/stepdown_factor
    iter <- iter + 1
  }

  # was not able to project
  pred_mat
}

# alternating projection heuristic to find intersection of two sets
.project_rank_feasibility <- function(mat, k, direction, max_val = NA,
                                      max_iter = 50,
                                      give_warning = F){
  if(!is.na(max_val)) stopifnot((direction == "<=" & max_val < 0) | (direction == ">=" & max_val > 0))
  iter <- 1
  tol <- ifelse(direction == "<=", -1, 1)

  while(iter < max_iter){
    res <- .svd_projection(mat, k = k, factors = T)
    mat <- res$u_mat %*% t(res$v_mat)

    if(direction == "<=") {
      if(all(mat < 0) && (is.na(max_val) || all(mat > max_val))) return(mat)

      if(any(mat < 0)) tol <- min(tol, stats::quantile(mat[mat < 0], probs = 0.95))
      stopifnot(tol < 0)
      mat[mat > 0] <- tol
      if(!is.na(max_val)) mat[mat < max_val] <- max_val
    }
    if(direction == ">=") {
      if(all(mat > 0) && (is.na(max_val) || all(mat < max_val))) return(mat)

      if(any(mat > 0)) tol <- max(tol, stats::quantile(mat[mat > 0], probs = 0.05))
      stopifnot(tol > 0)
      mat[mat < 0] <- tol
      if(!is.na(max_val)) mat[mat > max_val] <- max_val
    }

    iter <- iter + 1
  }

  if(give_warning) warning(".project_rank_feasibility was not successful")
  NA
}

.nonnegative_matrix_factorization <- function(mat, k, direction, max_val = NA, tol = 1e-3){
  if(!is.na(max_val)) stopifnot((direction == "<=" & max_val < 0) | (direction == ">=" & max_val > 0))

  # corner cases
  if(direction == "<=" & all(mat > 0)) return(NA)
  if(direction == ">=" & all(mat < 0)) return(NA)

  # prepare the matrix
  if(direction == "<=") {
    mat <- -mat
    max_val <- -max_val
  }

  min_val <- stats::quantile(mat[mat > 0], probs = 0.01)
  stopifnot(min_val > 0)
  mat[mat < 0] <- min_val
  if(!is.na(max_val)) mat[mat > max_val] <- max_val

  # perform the nonnegative matrix factorization
  stopifnot(all(mat > 0))
  res <- NMF::nmf(mat, rank = k) #requires NMF package to be explicitly loaded

  w_mat <- res@fit@W
  h_mat <- res@fit@H
  new_mat <- w_mat %*% h_mat

  # enforce the max constraint by adjusting one matrix
  idx <- unique(which(new_mat > max_val, arr.ind = T)[,2])
  if(length(idx) > 0){
    for(j in idx){
      ratio <- max_val/max(new_mat[,j])
      stopifnot(ratio <= 1)
      h_mat[,j] <- h_mat[,j]*ratio
    }

    new_mat <- w_mat %*% h_mat
    stopifnot(all(new_mat <= max_val + 1e-3))
  }

  stopifnot(new_mat >= 0)
  new_mat[new_mat < tol] <- tol
  stopifnot(new_mat > 0)

  # return the matrix
  if(direction == "<=") new_mat <- -new_mat

  new_mat
}
