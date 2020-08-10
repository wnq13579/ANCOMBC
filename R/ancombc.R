#' @title Differential abundance (DA) analysis for
#' microbial absolute abundance data.
#'
#' @aliases ancom
#'
#' @description Determine taxa whose absolute abundances, per unit volume, of
#' the ecosystem (e.g. gut) are significantly different with changes in the
#' covariate of interest (e.g. the group effect). The current version of
#' \code{ancombc} function implements Analysis of Compositions of Microbiomes
#' with Bias Correction (ANCOM-BC) in cross-sectional data while allowing
#' the adjustment of covariates.
#'
#' @details The definition of structural zero can be found at
#' \href{https://doi.org/10.3389/fmicb.2017.02114}{ANCOM-II}.
#' Setting \code{neg_lb = TRUE} indicates that you are using both criteria
#' stated in section 3.2 of
#' \href{https://doi.org/10.3389/fmicb.2017.02114}{ANCOM-II}
#' to detect structural zeros; otherwise, the algorithm will only use the
#' equation 1 in section 3.2 for declaring structural zeros. Generally, it is
#' recommended to set \code{neg_lb = TRUE} when the sample size per group is
#' relatively large (e.g. > 30).
#'
#' @param feature_table a \code{data.frame} or \code{matrix} representing
#' observed microbial absolute abundance table with taxa in rows
#' (\code{rownames} are taxa id) and samples in columns (\code{colnames} are
#' sample id). Note that this is the absolute abundance table, transforming it
#' to relative abundance table (where the column totals are equal to 1)
#' is deprecated
#' @param meta_data a \code{data.frame} or \code{matrix} containing an ID column
#' and all other variables. The ID column of \code{meta_data} is the
#' \code{colnames} for \code{feature_table}
#' @param sample_id the name of the ID column in \code{meta_data}
#' @param formula the character string expresses how the microbial absolute
#' abundances for each taxon depend on the variables in \code{meta_data}.
#' @param p_adj_method method to adjust p-values by. Default is "holm".
#' Options include "holm", "hochberg", "hommel", "bonferroni", "BH", "BY",
#' "fdr", "none". See \code{\link[stats]{p.adjust}} for more details.
#' @param zero_cut a numerical fraction between 0 and 1. Taxa with proportion of
#' zeroes greater than \code{zero_cut} will be excluded in the analysis. Default
#' is 0.90
#' @param lib_cut a numerical threshold for filtering samples based on library
#' sizes. Samples with library sizes less than \code{lib_cut} will be
#' excluded in the analysis
#' @param group the name of the group variable in \code{meta_data}. Specifying
#' \code{group} is required for detecting structural zeros and
#' performing global test
#' @param struc_zero whether to detect structural zeros. Default is FALSE
#' @param neg_lb whether to classify a taxon as a structural zero in the
#' corresponding experimental group using its asymptotic lower bound.
#' Default is FALSE
#' @param tol the iteration convergence tolerance for the E-M algorithm.
#' Default is 1e-05
#' @param max_iter the maximum number of iterations for the E-M algorithm.
#' Default is 100
#' @param conserve whether to use a conservative variance estimate of
#' the test statistic. It is recommended if the sample size is small and/or
#' the number of differentially abundant taxa is believed to be large.
#' Default is FALSE.
#' @param alpha level of significance. Default is 0.05
#' @param global whether to perform global test. Default is FALSE
#'
#' @return a \code{list} with components:
#'         \itemize{
#'         \item{ \code{feature_table}, a \code{data.frame} of pre-processed
#'         (based on \code{zero_cut} and \code{lib_cut}) microbial absolute
#'         abundance table. }
#'         \item{ \code{zero_ind}, a logical \code{matrix} with TRUE indicating
#'         the taxon is identified as a structural zero for the specified
#'         \code{group} variable.}
#'         \item{ \code{samp_frac}, a numeric vector of estimated sampling
#'         fractions in log scale. }
#'         \item{ \code{delta_em}, estimated bias terms through E-M algorithm. }
#'         \item{ \code{delta_wls}, estimated bias terms through weighted
#'         least squares (WLS) algorithm.}
#'         \item{ \code{res},  a \code{list} containing ANCOM-BC primary result,
#'         which consists of:}
#'         \itemize{
#'         \item{ \code{beta}, a \code{data.frame} of coefficients obtained
#'         from the ANCOM-BC log-linear model. }
#'         \item{ \code{se}, a \code{data.frame} of standard errors (SEs) of
#'         \code{beta}. }
#'         \item{ \code{W}, a \code{data.frame} of test statistics.
#'         \code{W = beta/se}. }
#'         \item{ \code{p_val}, a \code{data.frame} of p-values. P-values are
#'         obtained from two-sided Z-test using the test statistic \code{W}. }
#'         \item{ \code{q_val}, a \code{data.frame} of adjusted p-values.
#'         Adjusted p-values are obtained by applying \code{p_adj_method}
#'         to \code{p_val}.}
#'         \item{ \code{diff_abn}, a logical \code{data.frame}. TRUE if the
#'         taxon has \code{q_val} less than \code{alpha}.}
#'         }
#'         \item{ \code{res_global},  a \code{data.frame} containing ANCOM-BC
#'         global test result for the variable specified in \code{group},
#'         each column is:}
#'         \itemize{
#'         \item{ \code{W}, test statistics.}
#'         \item{ \code{p_val}, p-values, which are obtained from two-sided
#'         Chi-square test using \code{W}.}
#'         \item{ \code{q_val}, adjusted p-values. Adjusted p-values are
#'         obtained by applying \code{p_adj_method} to \code{p_val}.}
#'         \item{ \code{diff_abn}, A logical vector. TRUE if the taxon has
#'         \code{q_val} less than \code{alpha}.}
#'         }
#'         }
#'
#' @examples
#' library(microbiome); library(tidyverse)
#' data(atlas1006)
#' # Subset to baseline
#' pseq = subset_samples(atlas1006, time == 0)
#' # Re-code the bmi group
#' sample_data(pseq)$bmi_group = recode(sample_data(pseq)$bmi_group,
#'                                      `underweight` = "lean",
#'                                      `lean` = "lean",
#'                                      `overweight` = "overweight",
#'                                      `obese` = "obese",
#'                                      `severeobese` = "obese",
#'                                      `morbidobese` = "obese")
#' # Re-code the nationality group
#' sample_data(pseq)$nation = recode(sample_data(pseq)$nationality,
#'                                   `Scandinavia` = "NE",
#'                                   `UKIE` = "NE",
#'                                   `SouthEurope` = "SE",
#'                                   `CentralEurope` = "CE",
#'                                   `EasternEurope` = "EE")
#'
#' # Aggregate to phylum level
#' phylum_data = aggregate_taxa(pseq, "Phylum")
#'
#' # Run ancombc
#' feature_table = abundances(phylum_data); meta_data = meta(phylum_data)
#' # ancombc requires an id column for metadata
#' meta_data = meta_data %>% rownames_to_column("sample_id")
#' sample_id = "sample_id"; formula = "age + nation + bmi_group"
#' p_adj_method = "holm"; zero_cut = 0.90; lib_cut = 1000; group = "nation"
#' struc_zero = TRUE; neg_lb = TRUE; tol = 1e-05; max_iter = 100
#' conserve = TRUE; alpha = 0.05; global = TRUE
#'
#' out = ancombc(feature_table, meta_data, sample_id, formula,
#'               p_adj_method, zero_cut, lib_cut, group, struc_zero,
#'               neg_lb, tol, max_iter, conserve, alpha, global)
#'
#' res = out$res
#' res_global = out$res_global
#'
#' @author Huang Lin
#'
#' @references
#' \insertRef{kaul2017analysis}{ANCOMBC}
#'
#' \insertRef{lin2020analysis}{ANCOMBC}
#'
#' @import stats
#' @importFrom MASS ginv
#' @importFrom nloptr neldermead
#' @importFrom Rdpack reprompt
#'
#' @export
ancombc = function(feature_table, meta_data, sample_id, formula,
                   p_adj_method = "holm", zero_cut = 0.90, lib_cut,
                   group = NULL, struc_zero = FALSE, neg_lb = FALSE,
                   tol = 1e-05, max_iter = 100, conserve = FALSE,
                   alpha = 0.05, global = FALSE){
  # 1. Data pre-processing
  fiuo_prep = data_prep(feature_table, meta_data, sample_id,
                        group, zero_cut, lib_cut, global = global)
  feature_table = fiuo_prep$feature_table; meta_data = fiuo_prep$meta_data
  global = fiuo_prep$global
  taxa_id = rownames(feature_table); n_taxa = nrow(feature_table)
  samp_id = colnames(feature_table); n_samp = ncol(feature_table)
  # Add pseudocount (1) and take logarithm.
  y = log(feature_table + 1)
  options(na.action = "na.pass") # Keep NA's in rows of x
  x = model.matrix(formula(paste0("~", formula)), data = meta_data)
  options(na.action = "na.omit") # Switch it back
  covariates = colnames(x); n_covariates = length(covariates)

  # 2. Identify taxa with structural zeros
  if (struc_zero) {
    if (is.null(group)) {
      stop("Please specify the group variable for detecting structural zeros.")
    }
    zero_ind = get_struc_zero(feature_table, meta_data, group, neg_lb)
  }else{ zero_ind = NULL }

  # 3. Estimation of parameters
  fiuo_para = para_est(y, meta_data, formula, tol, max_iter)
  beta = fiuo_para$beta; d = fiuo_para$d; e = fiuo_para$e
  var_cov_hat = fiuo_para$var_cov_hat; var_hat = fiuo_para$var_hat

  # 4. Estimation of the between-sample bias
  fiuo_bias = bias_est(beta, var_hat, tol, max_iter, n_taxa)
  delta_em = fiuo_bias$delta_em; delta_wls = fiuo_bias$delta_wls
  var_delta = fiuo_bias$var_delta

  # 5. Coefficients, standard error, and sampling fractions
  fiuo_fit = fit_summary(y, x, beta, var_hat, delta_em, var_delta, conserve)
  beta_hat = fiuo_fit$beta_hat; se_hat = fiuo_fit$se_hat; d_hat = fiuo_fit$d_hat

  # 6. Primary results
  W = beta_hat/se_hat
  p = 2 * pnorm(abs(W), mean = 0, sd = 1, lower.tail = FALSE)
  q = apply(p, 2, function(x) p.adjust(x, method = p_adj_method))
  diff_abn = ifelse(q < alpha, TRUE, FALSE)
  res = list(beta = data.frame(beta_hat, check.names = FALSE),
             se = data.frame(se_hat, check.names = FALSE),
             W = data.frame(W, check.names = FALSE),
             p_val = data.frame(p, check.names = FALSE),
             q_val = data.frame(q, check.names = FALSE),
             diff_abn = data.frame(diff_abn, check.names = FALSE))

  # 7. Global test results
  if (global) {
    res_global = global_test(y, x, group, beta_hat, var_cov_hat,
                             p_adj_method, alpha)
  } else { res_global = NULL }

  # 8. Combine the information of structural zeros
  fiuo_out = res_combine_zero(x, group, struc_zero, zero_ind, alpha,
                              global, res, res_global)
  res = fiuo_out$res; res_global = fiuo_out$res_global

  # 9. Outputs
  out = list(feature_table = feature_table, zero_ind = zero_ind,
             samp_frac = d_hat, delta_em = delta_em, delta_wls = delta_wls,
             res = res, res_global = res_global)
  return(out)
}


