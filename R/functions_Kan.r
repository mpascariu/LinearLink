
#---------------------------------------
#' Data preparation function
#' @keywords internal
fun_data_prep <- function(mx, x, n_parameters){
     # Format input data
     mx <- as.matrix(mx)
     x  <- as.numeric(x)
     c_names <- if(is.null(ncol(mx)) | ncol(mx) == 1) 'mx' else colnames(mx)
     dimnames(mx) <- list(x, c_names)
     c_no    <- ncol(mx)
     mx <- mx + (mx == 0)*1e-04 # If death rate is 0 we assign a very small value
     # Scale the age vectors in order to obtain meaningful parameter estimates
     x_scaled <- x - min(x)
     # Create storage objects for parametes and fitted mx's
     pars <- matrix(NA, c_no, n_parameters)
     dimnames(pars) <- list(c_names, letters[1:n_parameters] )
     fitted.values <- mx*0
     # Output
     return(list(mx = mx, x = x, x_scaled = x_scaled,
                 pars = pars, fitted.values = fitted.values,
                 n_parameters = n_parameters))
}

# --------------------------------------------
#' Select the mortality model
#' 
#' This function calls the mortality model that will be 
#' used in all the calculations
#' @keywords internal
#' 
Fun_ux <- function(model){
     switch (model,
             kannisto = function(par, x) with(as.list(par), a*exp(b*x) / (1 + a*exp(b*x)) ),
             gompertz = function(par, x) with(as.list(par), a*exp(b*x))
     )
}

# --------------------------------------------
#' Fit Kannisto model
#' @keywords internal
#' 
kannisto <- function(mx, x, parS = NULL, ...){
     all_data <- fun_data_prep(mx, x, n_parameters = 2)
     with(all_data,
          {
               if(min(x) < 80 | max(x) > 100) {
                    cat('The Kannisto model is usually fitted in the 80-100 age-range\n')
               }
               model_name <- "Kannisto (1992): u(x) = a*exp(b*x) / [1 + a*exp(b*x)]"
               parS_default <- c(a = 0.5, b = 0.13)
               parS <- if(is.null(parS)) parS_default else parS 
               if(is.null(names(parS))) names(parS) <- letters[1:length(parS)]
               # Model ------------------------------------------
               fun_ux <- Fun_ux('kannisto')
               # Find parameters / Optimization -----------------
               fun_resid <- function(par, x, ux) {
                    sum(ux*log(fun_ux(par, x)) - fun_ux(par, x), na.rm = TRUE)
               }
               for(i in 1:nrow(pars)){
                    opt_i <- optim(par = parS, fn = fun_resid, x = x_scaled,
                                   ux = mx[, i], method = 'L-BFGS-B',
                                   lower = 1e-15, control = list(fnscale = -1))
                    pars[i, ] <- opt_i$par
               }
               # Compute death rates ---------------------------
               for(i in 1:nrow(pars)) fitted.values[, i] = fun_ux(pars[i, ], x_scaled)
               residuals <- mx - fitted.values
               # Retun results ----------------------------------
               return(list(x = x, mx.input = mx, fitted.values = fitted.values,
                           residuals = residuals,
                           model_name = model_name, coefficients = pars))
          })
}


# ==========================================================================
# Kannisto S functions

#' Fit Kannisto model for old age mortality
#'
#' This is a description
#' @param mx Matrix containing age-specific death rates (ages x years).
#' Can be also a vector or a data.frame with 1 column containing
#' rates in a single year
#' @param x Corresponding ages in the input matrix
#' @param parS Starting parameters used in optimization process
#' @param ... Some more stuff
#' @return Results
#' @examples 
#' library(LinearLink)
#' 
#' head(HMD_mx$SWE) # check data for Sweden
#' ages <- 80:100
#' dta  <- HMD_mx$SWE[paste(ages),] # filter Sweden mx between age 80 and 100
#' fit_kan <- Kannisto(mx = dta, x = ages) # fit Kannisto model
#' summary(fit_kan)
#' 
#' pred_kan  <- predict(fit_kan, 80:120) # extend mortality curve up to 120
#' 
#' @export
Kannisto <- function(mx, x, parS = NULL) UseMethod("Kannisto")

#' @keywords internal
#' @export
Kannisto.default <- function(mx, x, parS = NULL) {
     mx <- as.matrix(mx)
     x  <- as.numeric(x)
     mdl <- kannisto(mx, x, parS)
     mdl$call   <- match.call()
     class(mdl) <- "Kannisto"
     mdl
}

#' @keywords internal
#' @export
summary.Kannisto <- function(object, ...) {
     cat('Model:\n')
     cat(object$model_name,'\n-----')
     cat("\nCall:\n")
     print(object$call)
     cat("\nCoefficients:\n")
     print(headTail(coef(object), digits = 4))
}

#' @keywords internal
#' @export
predict.Kannisto <- function(object, newdata=NULL, ...) {
     if(is.null(newdata)){pred.values <- fitted(object)
     }else{
          x <- newdata
          x_scaled <- x - min(object$x) 
          pars <- coef(object)
          pred.values <- matrix(NA, nrow = length(x), ncol = nrow(pars))
          dimnames(pred.values) <- list(x, rownames(pars))
          fun_ux <- Fun_ux('kannisto')
          for(i in 1:nrow(pars)) pred.values[,i] = fun_ux(pars[i,], x_scaled)
     }
     pred.values
}





