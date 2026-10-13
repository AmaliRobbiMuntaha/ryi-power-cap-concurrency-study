# run from repository root
d <- read.csv("data/processed/publication_ready_dataset_v2.csv")
tel <- read.csv("analysis/telemetry_per_run.csv")            # from extract_telemetry.py
d <- merge(d, tel, by = "run_id")
d$cap  <- factor(d$configured_power_limit_w, levels = c(15, 25, 45), labels = c("15W", "25W", "45W"))
d$mode <- factor(d$sched_mode, levels = c("baseline", "randomized_yield"), labels = c("baseline", "RYI"))
d$tel    <- as.POSIXct(d$start_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

## (a) cell time windows
print(aggregate(tel ~ cap + mode, d, function(x) paste(format(min(x), "%H:%M"), "-", format(max(x), "%H:%M"))))

## (b) within-cell drift (Spearman) of fault status and post-run temperature
for (k in split(d, list(d$cap, d$mode))) {
  f <- cor.test(k$replicate, k$any_fault,      method = "spearman", exact = FALSE)
  ct <- cor.test(k$replicate, k$post_run_temp_c, method = "spearman", exact = FALSE)
  p_fault_formatted <- format.pval(f$p.value, digits = 3, eps = 0.001)
  p_temp_formatted  <- format.pval(ct$p.value, digits = 3, eps = 0.001)
  cat(as.character(k$cap[1]), as.character(k$mode[1]),
      "fault rho =", round(f$estimate, 2), "(p =", round(f$p.value, 3), ")",
      "temp rho =",  round(ct$estimate, 2), "(p =", round(ct$p.value, 3), ")\n")
}

## (b2) first- vs second-half fault proportions within each cell
d$half <- ifelse(d$replicate <= 25, "first", "second")
print(aggregate(any_fault ~ cap + mode + half, d, mean))

## (c) lost updates per run, quasi-Poisson with log(expected_updates) offset
q0 <- glm(lost_updates ~ cap + mode + offset(log(expected_updates)), quasipoisson, d)
q1 <- glm(lost_updates ~ cap * mode + offset(log(expected_updates)), quasipoisson, d)
print(anova(q0, q1, test = "F"))
print(exp(cbind(RR = coef(q1), confint.default(q1))))      # Wald CI; coefficients are rate-ratio ratios

## (d) 45 W without the hot cluster (mean_watt > 15)
s <- subset(d, !(cap == "45W" & mean_watt > 15))
print(with(subset(s, cap == "45W"), table(mode, any_fault)))

## (e) ratio of odds ratios between caps: profile-likelihood CI and LRT p (Holm over 3 pairs)
m_int <- glm(any_fault ~ cap * mode, binomial, d)
print(round(exp(cbind(OR = coef(m_int), confint(m_int)))[c("cap25W:modeRYI", "cap45W:modeRYI"), ], 2))
d$i25 <- as.numeric(d$cap == "25W" & d$mode == "RYI")
d$i45 <- as.numeric(d$cap == "45W" & d$mode == "RYI")
mf    <- glm(any_fault ~ cap + mode + i25 + i45, binomial, d)
p25   <- anova(update(mf, . ~ . - i25), mf, test = "LRT")[2, "Pr(>Chi)"]
p45   <- anova(update(mf, . ~ . - i45), mf, test = "LRT")[2, "Pr(>Chi)"]
p4525 <- anova(update(mf, . ~ . - i25 - i45 + I(i25 + i45)), mf, test = "LRT")[2, "Pr(>Chi)"]
pp <- c(p25, p45, p4525)
tab <- data.frame(contrast = c("25W vs 15W", "45W vs 15W", "45W vs 25W"),
                  p_raw  = round(pp, 4),
                  p_holm = round(p.adjust(pp, "holm"), 4))
print(tab)
