## LIBRARY PREPARATION
# install.packages(c("ggplot2", "dplyr", "readr", "stringr", "tidyr"))

library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)

## PATH CONFIGURATION
study_dir <- "../data/processed"
data_file <- file.path(study_dir, "publication_ready_dataset_v2.csv")
plot_dir <- "result"

if (!dir.exists(plot_dir)) {
  dir.create(plot_dir, recursive = TRUE)
}

# Reading data
df <- read_csv(data_file, show_col_types = FALSE) %>%
  mutate(
    sched_mode = str_to_upper(sched_mode),
    sched_mode = ifelse(sched_mode == "RANDOMIZED_YIELD", "RYI", sched_mode),
    # Ubah limit daya menjadi Factor agar dipisahkan sebagai kategori batas, bukan angka linear
    power_cap_factor = factor(configured_power_limit_w, levels = c(15, 25, 45))
  )

theme_journal <- function() {
  theme_bw(base_size = 14, base_family = "serif") +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5, margin = margin(b = 15), size=15),
      strip.background = element_rect(fill = "gray95"),
      strip.text = element_text(face = "bold", size = 13),
      legend.position = "bottom",
      legend.title = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )
}

print("[*] Starting...")

## PLOT 1: Fault Rate with a 95% Binomial Confidence Interval
# Calculating the probability, numerator/denominator, and Binomial Confidence Interval (Exact/Clopper-Pearson)
df_binom <- df %>%
  group_by(power_cap_factor, sched_mode) %>%
  summarise(
    trials = n(),
    successes = sum(any_fault),
    rate_RYI = (successes / trials) * 100,
    # Menghitung 95% CI menggunakan uji binomial
    ci_lower = binom.test(successes, trials)$conf.int[1] * 100,
    ci_upper = binom.test(successes, trials)$conf.int[2] * 100,
    label_text = sprintf("%d/%d\n(%.0f%%)", successes, trials, rate_RYI),
    .groups = 'drop'
  )

p1 <- ggplot(df_binom, aes(x = power_cap_factor, y = rate_RYI, color = sched_mode, group = sched_mode)) +
  geom_line(size = 1.2, position = position_dodge(width = 0.2)) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2, size = 1, position = position_dodge(width = 0.2)) +
  geom_point(aes(shape = sched_mode), size = 4, fill = "white", position = position_dodge(width = 0.2)) +
  geom_text(aes(label = label_text, y = ci_upper + 5), 
            position = position_dodge(width = 0.2), size = 4, family = "serif", color = "black", vjust = 0) +
  scale_color_manual(values = c("BASELINE" = "#4C72B0", "RYI" = "#C44E52")) +
  scale_y_continuous(limits = c(0, 115), breaks = seq(0, 100, by = 20)) +
  labs(
    # title = "Figure 1: Concurrency Fault Manifestation Rate\n(with 95% Binomial Confidence Intervals)",
    x = "Configured Power-Cap Condition (Watts)",
    y = "Fault Probability (%)",
    color = "Scheduling Mode",
    shape = "Scheduling Mode"
  ) +
  theme_journal()

ggsave(file.path(plot_dir, "fig1_fault_rate_binomial.png"), plot = p1, width = 9, height = 7, dpi = 300)
ggsave(file.path(plot_dir, "fig1_fault_rate_binomial.pdf"), plot = p1, width = 9, height = 7)
print("[+] Plot 1 selesai (Binomial CI + Fraction Labels).")

## PLOT 2: Two-Panel Hardware Validation (Jitter + Boxplot)
# Reshape the data from wide to long to facilitate Facet Wrap (Two Panels)
df_long_hardware <- df %>%
  select(power_cap_factor, sched_mode, mean_watt, post_run_temp_c) %>%
  pivot_longer(cols = c(mean_watt, post_run_temp_c), names_to = "metric", values_to = "value") %>%
  mutate(
    metric_label = ifelse(metric == "mean_watt", "Mean Measured Power (W)", "Post-run temperature (°C)")
  )

p2 <- ggplot(df_long_hardware, aes(x = power_cap_factor, y = value, fill = sched_mode)) +
  # Transparent boxplots for range and median
  geom_boxplot(outlier.shape = NA, alpha = 0.5, position = position_dodge(0.8), color = "black") +
  # Jittered points for each run
  geom_point(aes(color = sched_mode), position = position_jitterdodge(jitter.width = 0.2, dodge.width = 0.8), 
             size = 1.5, alpha = 0.7) +
  facet_wrap(~ metric_label, scales = "free_y") +
  scale_fill_manual(values = c("BASELINE" = "#4C72B0", "RYI" = "#C44E52")) +
  scale_color_manual(values = c("BASELINE" = "#2c4369", "RYI" = "#7a2e31")) +
  labs(
    # title = "Figure 2: Thermal and Measured-Power Validation",
    x = "Configured Power-Cap Condition (Watts)",
    y = "Measured Value",
    fill = "Scheduling Mode",
    color = "Scheduling Mode"
  ) +
  theme_journal() +
  theme(panel.spacing = unit(2, "lines")) # Leave extra space between panels

ggsave(file.path(plot_dir, "fig2_hardware_validation_panels.png"), plot = p2, width = 10, height = 6, dpi = 300)
ggsave(file.path(plot_dir, "fig2_hardware_validation_panels.pdf"), plot = p2, width = 10, height = 6)
print("[+] Plot 2 is complete (Two-Panel Boxplot + Jitter).")

## PLOT 3: Context Switches (Jitter + Boxplot)
p3 <- ggplot(df, aes(x = power_cap_factor, y = cswitches, fill = sched_mode)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5, position = position_dodge(0.8), color = "black") +
  geom_point(aes(color = sched_mode), position = position_jitterdodge(jitter.width = 0.2, dodge.width = 0.8), 
             size = 1.5, alpha = 0.7) +
  scale_fill_manual(values = c("BASELINE" = "#55A868", "RYI" = "#DD8452")) +
  scale_color_manual(values = c("BASELINE" = "#31663e", "RYI" = "#8c4d2c")) +
  labs(
    # title = "Figure 3: Aggregate Scheduler Events Distribution\n(Total Context Switches per Run)",
    x = "Configured Power-Cap Condition (Watts)",
    y = "Total Context Switches",
    fill = "Scheduling Mode",
    color = "Scheduling Mode"
  ) +
  theme_journal()

ggsave(file.path(plot_dir, "fig3_context_switches_distribution.png"), plot = p3, width = 8, height = 6, dpi = 300)
ggsave(file.path(plot_dir, "fig3_context_switches_distribution.pdf"), plot = p3, width = 8, height = 6)
print("[+] Plot 3 is complete (Boxplot + Jitter).")
