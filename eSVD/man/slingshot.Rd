% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/slingshot_curves.R
\name{slingshot}
\alias{slingshot}
\title{Use slingshot to estimate the cell development trajectories}
\usage{
slingshot(dat, cluster_labels, starting_cluster, cluster_group_list = NA,
  use_initialization = F, reduction_percentage = 0.25, shrink = 1,
  thresh = 0.001, max_iter = 15, upscale_vec = NA, verbose = F)
}
\arguments{
\item{dat}{a \code{n} by \code{d} matrix}

\item{cluster_labels}{vector of cluster labels, where
the cluster labels are consecutive positive integers from 1 to
\code{max(cluster_labels)}}

\item{starting_cluster}{the "origin" cluster that all the lineages will start
from}

\item{cluster_group_list}{list denoting the hierarchy and order of the clusters}

\item{use_initialization}{use principal curves on each cluster to prune the
list of possible neighboring clusters}

\item{reduction_percentage}{numeric}

\item{shrink}{shrinkage factor}

\item{thresh}{parameter to determine convergence}

\item{max_iter}{maximum number of iterations}

\item{upscale_vec}{vector of positive numbers, one for each cluster}

\item{verbose}{boolean}
}
\value{
a list containing the lineages under \code{lineages},
the list of curves as \code{principal_curve} objects under
\code{curves} and the clustering matrix under \code{cluster_mat}
}
\description{
Use slingshot to estimate the cell development trajectories
}
