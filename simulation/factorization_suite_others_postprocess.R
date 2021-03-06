rm(list=ls())
res_list <- vector("list", 4)
load("../results/factorization_results_others_gen1.RData")
res_list[[1]] <- res[[1]]
load("../results/factorization_results_others_gen23.RData")
res_list[[2]] <- res[[1]]
res_list[[3]] <- res[[2]]
load("../results/factorization_results_others_gen4.RData")
res_list[[4]] <- res[[1]]

res_list <- res_list[c(2,1,3,4)]
max_height <- 3
lab_vec <- c("(Curved Gaussian)", "(Constant-variance Gaussian)",
               "(Negative binomial)", "(Poisson)")

##################################

# plot the example embeddings. for each one, pick the median trial for the
#  exemplary estimator

col_func <- function(alpha){
  c( rgb(86/255, 180/255, 233/255, alpha), #skyblue
     rgb(240/255, 228/255, 66/255, alpha), #yellow
     rgb(0/255, 158/255, 115/255, alpha), #bluish green
     rgb(230/255, 159/255, 0/255,alpha)) #orange
}
col <- col_func(1)
exemplary_row <- c(1, 2, 5, 6)

for(kk in 1:length(lab_vec)){
  print(kk)
  res <- res_list[[kk]]

  res_mat <- matrix(NA, 6, trials)
  for(i in 1:trials){
    if(i %% floor(trials/10) == 0) cat('*')
    dist_mat_truth <- as.matrix(stats::dist(res[[i]]$dat$truth))

    for(k in 1:6){
      dist_mat_est <- as.matrix(stats::dist(res[[i]][[(k-1)*2+1]]))

      res_mat[k,i] <- mean(sapply(1:nrow(dist_mat_est), function(x){
        cor(dist_mat_truth[x,], dist_mat_est[x,], method = "kendall")
      }))
    }
  }
  res_mat <- res_mat[c(4,1,2,3,5,6),]

  idx <- which.min(abs(res_mat[exemplary_row[kk],] - median(res_mat[exemplary_row[kk],])))

  png(paste0("../figure/simulation/factorization_example_", kk, ".png"),
      height = 1500, width = 1500, res = 300, units = "px")
  label_vec <- c("eSVD", "SVD", "ICA", "t-SNE", "ZINB-WaVE", "pCMF")
  par(mfrow = c(2,3), mar = c(1, 1, 1.5, 1))
  order_vec <- c(4,1,2,3,5,6)
  for(i in 1:6){
    plot(res_list[[kk]][[idx]][[(order_vec[i]-1)*2+1]][,1], res_list[[kk]][[idx]][[(order_vec[i]-1)*2+1]][,2],
         asp = T, pch = 16, col = col[rep(1:4, each = paramMat[1,"n_each"])],
         xlab = "Latent dim. 1", ylab = "Latent dim. 2",
         main = paste0(label_vec[i], ": (", round(res_mat[i, idx], 2), ")"),
         xaxt = "n", yaxt = "n")
  }
  graphics.off()
}



#################################

for(kk in 1:length(lab_vec)){
  res <- res_list[[kk]]

  res_mat <- matrix(NA, 6, trials)
  for(i in 1:trials){
    if(i %% floor(trials/10) == 0) cat('*')

    dist_mat_truth <- as.matrix(stats::dist(res[[i]]$dat$truth))

    for(k in 1:6){
      dist_mat_est <- as.matrix(stats::dist(res[[i]][[(k-1)*2+1]]))

      res_mat[k,i] <- mean(sapply(1:nrow(dist_mat_est), function(x){
        cor(dist_mat_truth[x,], dist_mat_est[x,], method = "kendall")
      }))
    }
  }
  res_mat <- res_mat[c(4,1,2,3,5,6),]

  #############################

  color_func <- function(alpha = 0.2){
    c(rgb(240/255, 228/255, 66/255, alpha), #yellow
      rgb(86/255, 180/255, 233/255, alpha), #skyblue
      rgb(0/255, 158/255, 115/255, alpha), #bluish green
      rgb(0/255, 114/255, 178/255, alpha), #blue
      rgb(230/255, 159/255, 0/255, alpha), #orange
      rgb(150/255, 150/255, 150/255, alpha))
  }

  # start of intensive plotting function
  den_list <- lapply(1:nrow(res_mat), function(i){
    density(res_mat[i,])
  })

  #max_val <- max(sapply(den_list, function(x){max(x$y)}))
  scaling_factor <- quantile(sapply(den_list, function(x){max(x$y)}), probs = 0.3)

  col_vec <- color_func(1)[c(5,2,3,1,4,6)]
  text_vec <- c("eSVD", "SVD", "ICA", "t-SNE", "ZINB-WaVE", "pCMF")

  png(paste0("../figure/simulation/factorization_density_", kk, ".png"),
      height = 1800, width = 1000, res = 300, units = "px")
  par(mar = c(4,0.5,4,0.5))
  plot(NA, xlim = c(-0.2, 1), ylim = c(0, 6.25), ylab = "",
       yaxt = "n", bty = "n", xaxt = "n", xlab = "Kendall's tau",
       main = paste0("Relative embedding correlation\n", lab_vec[kk]))
  axis(side = 1, at = seq(0,1,length.out = 6))
  for(i in 1:nrow(res_mat)){
    lines(c(0,1), rep(nrow(res_mat) - i, 2))

    y_vec <- (c(0, den_list[[i]]$y, 0 , 0))/scaling_factor
    if(max(y_vec) > max_height) y_vec <- y_vec*max_height/max(y_vec)
    polygon(x = c(den_list[[i]]$x[1], den_list[[i]]$x, den_list[[i]]$x[length(den_list[[i]]$x)], den_list[[i]]$x[1]),
            y = y_vec + nrow(res_mat) - i,
            col = col_vec[i])

    med <- median(res_mat[i,])
    lines(rep(med, 2), y = c(nrow(res_mat) - i, 0), lwd = 1, lty = 2)
    points(med, y = nrow(res_mat) - i, col = "black", pch = 16, cex = 2)
    points(med, y = nrow(res_mat) - i, col = col_vec[i], pch = 16, cex = 1.5)
  }
  text(x = rep(0,6), y = seq(5.35,0.35,by=-1), labels = text_vec)
  graphics.off()
}

