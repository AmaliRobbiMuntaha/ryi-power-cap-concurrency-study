# run from repository root
suppressPackageStartupMessages({library(emmeans); library(DescTools)})

d <- read.csv("data/processed/publication_ready_dataset_v2.csv",
              stringsAsFactors = FALSE)

d$cap  <- factor(d$configured_power_limit_w, levels = c(15, 25, 45),
                 labels = c("15W", "25W", "45W"))
d$mode <- factor(d$sched_mode, levels = c("baseline", "randomized_yield"),
                 labels = c("baseline", "RYI"))

## --- sanity checks ---
stopifnot(nrow(d) == 300, all(d$any_fault %in% 0:1), sum(d$any_fault) == 208)
stopifnot(!anyNA(d$cap), !anyNA(d$mode))
print(table(d$cap, d$mode))
print(with(d, tapply(any_fault, list(cap, mode), sum)))   # 29,27 / 29,43 / 35,45

## --- 1. models and interaction test ---
m_add <- glm(any_fault ~ cap + mode, binomial, d)
m_int <- glm(any_fault ~ cap * mode, binomial, d)
print(anova(m_add, m_int, test = "LRT"))                  # expected chi2(2)=8.69, p=0.013

## --- 2. OR RYI vs baseline within each cap (Holm) ---
emm <- emmeans(m_int, ~ mode | cap)
or  <- contrast(emm, "revpairwise")                      # RYI / baseline
print(summary(or, type = "response", infer = TRUE, adjust = "holm"))   # OR, CI, Holm p
print(summary(or, type = "response", infer = TRUE, adjust = "none"))   # unadjusted CI

## --- 3. ratio of ORs (how much the RYI effect differs between caps) ---
print(summary(contrast(or, "revpairwise", by = NULL),
              type = "response", infer = TRUE, adjust = "holm"))

## --- 4. cap effect within each mode (RQ1) ---
cap_or <- contrast(emmeans(m_int, ~ cap | mode), "revpairwise")
print(summary(cap_or, type = "response", infer = TRUE, adjust = "holm"))

## --- 5. risk difference + 95% CI (Newcombe score) ---
for (cp in levels(d$cap)) {
  x <- subset(d, cap == cp)
  r1 <- sum(x$any_fault[x$mode == "RYI"]);      n1 <- sum(x$mode == "RYI")
  r0 <- sum(x$any_fault[x$mode == "baseline"]); n0 <- sum(x$mode == "baseline")
  cat(cp, "\n"); print(round(BinomDiffCI(r1, n1, r0, n0, method = "score") * 100, 1))
}

## --- 6. cross-check: exact conditional OR (Fisher) ---
for (cp in levels(d$cap)) {
  f <- fisher.test(table(subset(d, cap == cp)[, c("mode", "any_fault")]))
  cat(cp, "OR =", round(f$estimate, 2), "CI", round(f$conf.int, 2), "p =", signif(f$p.value, 3), "\n")
}


res <- do.call(rbind, lapply(levels(d$cap), function(cp) {
  x  <- subset(d, cap == cp)
  r1 <- sum(x$any_fault[x$mode == "RYI"]);      n1 <- sum(x$mode == "RYI")
  r0 <- sum(x$any_fault[x$mode == "baseline"]); n0 <- sum(x$mode == "baseline")

  rd <- BinomDiffCI(r1, n1, r0, n0, method = "score") * 100      # risk difference, percentage points
  m  <- glm(any_fault ~ mode, binomial, x)                       # = contrast in a saturated model
  or <- exp(c(coef(m)[2], confint(m)[2, ]))                      # OR + profile-likelihood CI
  p  <- fisher.test(table(x$mode, x$any_fault))$p.value

  data.frame(cap = cp,
             baseline = sprintf("%d/%d", r0, n0),
             RYI      = sprintf("%d/%d", r1, n1),
             RD_pp    = sprintf("%+.0f [%.0f, %.0f]", rd[1], rd[2], rd[3]),
             OR       = sprintf("%.2f [%.2f, %.2f]", or[1], or[2], or[3]),
             p_raw    = p)
}))
res$p_holm <- p.adjust(res$p_raw, method = "holm")
print(res)
write.csv(res, "analysis/table_ryi_effects.csv", row.names = FALSE)

pairs <- list(c("25W","15W"), c("45W","15W"), c("45W","25W"))   # When vs. Ref

rq1 <- do.call(rbind, lapply(levels(d$mode), function(md) {
  x <- subset(d, mode == md)
  # omnibus
  om <- chisq.test(table(x$cap, x$any_fault))
  out <- do.call(rbind, lapply(pairs, function(p) {
    y <- subset(x, cap %in% p); y$cap <- factor(y$cap, levels = rev(p))   # ref = p[2]
    m  <- glm(any_fault ~ cap, binomial, y)
    or <- exp(c(coef(m)[2], confint(m)[2, ]))
    r1 <- mean(y$any_fault[y$cap == p[1]]); r0 <- mean(y$any_fault[y$cap == p[2]])
    pf <- fisher.test(table(y$cap, y$any_fault))$p.value
    data.frame(mode = md, contrast = paste(p[1], "vs", p[2]),
               RD_pp = round(100 * (r1 - r0)),
               OR = sprintf("%.2f [%.2f, %.2f]", or[1], or[2], or[3]), p_raw = pf)
  }))
  out$p_holm <- p.adjust(out$p_raw, "holm")
  out$omnibus <- sprintf("chi2(2)=%.2f, p=%.3g", om$statistic, om$p.value)
  out
}))
print(rq1)
write.csv(rq1, "analysis/table_cap_effects.csv", row.names = FALSE)

# pooled (descriptive)
print(chisq.test(table(d$cap, d$any_fault)))

# Interaction metrics for text
a <- anova(m_add, m_int, test = "LRT"); print(a)

ci <- exp(cbind(OR = coef(m_int), confint(m_int)))
print(round(ci[c("cap25W:modeRYI", "cap45W:modeRYI"), ], 2))

writeLines(capture.output(sessionInfo()), "analysis/sessionInfo.txt")
