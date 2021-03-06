% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/matrix_factorization.R
\name{fit_factorization}
\alias{fit_factorization}
\title{Fit the factorization}
\usage{
fit_factorization(dat, u_mat, v_mat, max_val = NA,
  family = "exponential", reparameterize = T, scalar = 2,
  tol = 0.001, max_iter = 100, verbose = F, return_path = F,
  cores = NA)
}
\arguments{
\item{dat}{dataset where the \code{n} rows represent cells and \code{d} columns represent genes}

\item{u_mat}{initial factorization, of size \code{n} by \code{k}}

\item{v_mat}{initial factorization, of size \code{d} by \code{k}}

\item{max_val}{maximum value of the inner product (with the correct sign)}

\item{family}{either \code{"gaussian"} or \code{"exponential"}}

\item{reparameterize}{boolean}

\item{scalar}{positive numeric for the Gaussian family}

\item{tol}{small positive number to dictate the convergence of the objective function}

\item{max_iter}{maximum number of iterations for the algorithm}

\item{verbose}{boolean}

\item{return_path}{boolean}

\item{cores}{positive integer}
}
\value{
list
}
\description{
Fit the factorization
}
