rm(list=ls())
library(simulation)
library(eSVD)
library(NMF)
source("../simulation/factorization_generator.R")

paramMat <- cbind(50, 120, 0.05, 150, 2, 2, -2000, 4)
colnames(paramMat) <- c("n_each", "d_each", "sigma", "total", "k", "scalar", "max_val",
                        "generation_type")
trials <- 200

################

cell_pop <- matrix(c(4,10, 25,100, 60,80, 25,100,
                     40,10, 60,80, 60,80, 100, 25)/10,
                   nrow = 4, ncol = 4, byrow = T)
gene_pop <- matrix(c(20,90, 25,100,
                     90,20, 100,25)/100, nrow = 2, ncol = 4, byrow = T)

rule <- function(vec){
  n_each <- vec["n_each"]
  d_each <- vec["d_each"]
  sigma <- vec["sigma"]
  total <- vec["total"]

  res <- generate_natural_mat(cell_pop, gene_pop, n_each, d_each, sigma)
  nat_mat <- res$nat_mat

  if(vec["generation_type"] == 1){
    obs_mat <- round(100*generator_gaussian(nat_mat))
  } else if(vec["generation_type"] == 2){
    obs_mat <- round(100*generator_curved_gaussian(nat_mat, alpha = 2))
  } else if(vec["generation_type"] == 3 ){
    obs_mat <- generator_zinb_nb(nat_mat)
  } else {
    obs_mat <- generator_pcmf_poisson(nat_mat)
  }

  list(dat = obs_mat, truth = res$cell_mat)
}

criterion <- function(dat, vec, y){
  print(y)
  cluster_labels <- rep(1:4, each = vec["n_each"])

  # SVD
  tmp <- svd(dat$dat)
  res_svd <- tmp$u[,1:vec["k"]] %*% diag(sqrt(tmp$d[1:vec["k"]]))
  curves_svd <- eSVD::slingshot(res_svd[,1:vec["k"]], cluster_labels,
                                      starting_cluster = 1,
                                      verbose = F)

  # print("fin1")

  # ICA
  tmp <- ica::icafast(dat$dat, nc = vec["k"])
  res_ica <- tmp$S
  curves_ica <- eSVD::slingshot(res_ica[,1:vec["k"]], cluster_labels,
                                      starting_cluster = 1,
                                      verbose = F)

  # print("fin2")

  # tsne
  tmp <- Rtsne::Rtsne(dat$dat, perplexity = 30)
  res_tsne <- tmp$Y
  curves_tsne <- eSVD::slingshot(res_tsne[,1:vec["k"]], cluster_labels,
                                       starting_cluster = 1,
                                       verbose = F)

  # print("fin3")

  # # Our method
  set.seed(10)
  init <- eSVD::initialization(dat$dat, family = "gaussian", k = vec["k"], max_val = vec["max_val"])
  tmp <- eSVD::fit_factorization(dat$dat, u_mat = init$u_mat, v_mat = init$v_mat,
                                       family = "gaussian",  reparameterize = T,
                                       max_iter = 100, max_val = vec["max_val"],
                                       scalar = vec["scalar"],
                                       return_path = F, cores = NA,
                                       verbose = F)

  res_our <- tmp$u_mat
  curves_our <- eSVD::slingshot(res_our[,1:vec["k"]], cluster_labels,
                                      starting_cluster = 1,
                                      verbose = F)

  # print("fin4")

  # zinb-wave
  set.seed(10)
  dat_se <- SummarizedExperiment::SummarizedExperiment(assays = list(counts = t(dat$dat)))
  tmp <- zinbwave::zinbwave(dat_se, K = vec["k"], maxiter.optimize = 100)
  res_zinb <- tmp@reducedDims$zinbwave
  curves_zinb <- eSVD::slingshot(res_zinb[,1:vec["k"]], cluster_labels,
                                       starting_cluster = 1,
                                       verbose = F)

  # print("fin5")

  # pcmf
  set.seed(10)
  tmp <- pCMF::pCMF(dat$dat, K = vec["k"], sparsity = F, verbose = F)
  res_pcmf <- tmp$factor$U
  curves_pcmf <- eSVD::slingshot(res_pcmf[,1:2], cluster_labels,
                                       starting_cluster = 1,
                                       verbose = F)

  # print("fin6")

  curves_truth <- eSVD::slingshot(dat$truth, cluster_labels,
                                        starting_cluster = 1,
                                        verbose = F)

  # print("fin7")

  list(res_svd = res_svd, curves_svd = curves_svd,
       res_ica = res_ica, curves_ica = curves_ica,
       res_tsne = res_tsne, curves_tsne = curves_tsne,
       res_our = res_our, curves_our = curves_our,
       res_zinb = res_zinb, curves_zinb = curves_zinb,
       res_pcmf = res_pcmf, curves_pcmf = curves_pcmf,
       curves_truth = curves_truth,
       dat = dat)
}

# set.seed(1); zz <- criterion(rule(paramMat[1,]), paramMat[1,], 1)
# plot(zz$res_our[,1], zz$res_our[,2], asp = T, pch = 16, col = c(1:4)[rep(1:4, each = paramMat[1,"n_each"])])
# for(i in 1:2){ord <- zz$curves_our$curves[[i]]$ord; lines(zz$curves_our$curves[[i]]$s[ord,1], zz$curves_our$curves[[i]]$s[ord,2], lwd = 2)}
# i <- 1; idx <- which(zz$curves_truth$curves[[i]]$lambda_long != 0); cor(zz$curves_truth$curves[[i]]$lambda_long[idx], zz$curves_our$curves[[i]]$lambda_long[idx])

############

res <- simulation::simulation_generator(rule = rule, criterion = criterion,
                                        paramMat = paramMat, trials = trials,
                                        cores = NA, as_list = T,
                                        filepath = "../results/factorization_results_others_tmp_gen4.RData",
                                        verbose = T)

save.image("../results/factorization_results_others_gen4.RData")
