Plotting biomass projections for PICTs
================
Denisse Fierro Arcos
2023-12-13

- <a href="#loading-libraries" id="toc-loading-libraries">Loading
  libraries</a>
- <a href="#loading-data" id="toc-loading-data">Loading data</a>
- <a href="#cleaning-data" id="toc-cleaning-data">Cleaning data</a>
- <a href="#plotting-data" id="toc-plotting-data">Plotting data</a>
  - <a href="#saving-plots" id="toc-saving-plots">Saving plots</a>

## Loading libraries

``` r
library(readr)
library(dplyr)
library(ggplot2)
```

## Loading data

``` r
PICTS_keys <- read_csv("../Outputs/SouthPacific_EEZ-GBR_keys.csv") |> 
  select(!MRGID)
```

    ## Rows: 26 Columns: 3
    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr (1): name
    ## dbl (2): ID, MRGID
    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
bio_picts <- read_csv("../Outputs/average_yearly_means_picts_1985-2100.csv")|>
  #Removing GBR data
  filter(mask != 9999) |> 
   #Rename scenarios to match coral data
  mutate(scenario = case_when(scenario == "ssp126" ~ "SSP1-2.6",
                              scenario == "ssp585" ~ "SSP5-8.5",
                              T ~ scenario)) 
```

    ## Rows: 46460 Columns: 6
    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr (3): mem, esm, scenario
    ## dbl (3): year, mask, mean_annual_bio
    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

## Cleaning data

``` r
#Calculating reference mean for reference decade (1990-1999)
ref_90s <- bio_picts |>
  filter(year >= 1990 & year < 2000) |> 
  group_by(mem, mask) |> 
  summarise(ref = mean(mean_annual_bio))
```

    ## `summarise()` has grouped output by 'mem'. You can override using the `.groups`
    ## argument.

``` r
#Calculating proportion of biomass in relation to reference decade
bio_plots <- bio_picts |> 
  left_join(ref_90s, by = c("mem", "mask")) |> 
  mutate(prop = mean_annual_bio/ref) |> 
  #Calculations performed by year and EEZ
  group_by(mask, scenario, year) |> 
  #Apply calculations to biases only
  summarise(across(prop, 
                   #Listing statistics to be calculated
                   list(lower = min, mean = mean, max = max), 
                   #Setting column names
                   .names = "{.col}_{.fn}")) |> 
  left_join(PICTS_keys, by = c("mask"="ID")) 
```

    ## `summarise()` has grouped output by 'mask', 'scenario'. You can override using
    ## the `.groups` argument.

    ## Warning in left_join(summarise(group_by(mutate(left_join(bio_picts, ref_90s, : Detected an unexpected many-to-many relationship between `x` and `y`.
    ## ℹ Row 1415 of `x` matches multiple rows in `y`.
    ## ℹ Row 26 of `y` matches multiple rows in `x`.
    ## ℹ If a many-to-many relationship is expected, set `relationship =
    ##   "many-to-many"` to silence this warning.

## Plotting data

``` r
bio_plots |> 
  ggplot(aes(x = year, y = prop_mean, color = scenario))+
  geom_line(alpha = 0.75, linewidth = 0.5)+
  geom_hline(yintercept = 1, color = "#709fcc", linewidth = 0.65, linetype = 2)+
  geom_vline(xintercept = 2015, color = "#709fcc", linewidth = 0.65)+
  geom_ribbon(aes(ymin = prop_lower, ymax = prop_max, fill = scenario),
              alpha = 0.3, color = NA)+
  scale_x_continuous(minor_breaks = seq(1980, 2100, by = 10),
                     breaks = seq(1980, 2100, by = 40), limits = c(1980, 2100))+
  facet_wrap(~name, scales = "free_y")+
  scale_color_manual(values = c("historical" = "black", "SSP1-2.6" = "blue",
                                "SSP5-8.5" = "red"))+
  scale_fill_manual(values = c("historical" = "black", "SSP1-2.6" = "blue",
                                "SSP5-8.5" = "red"))+
  theme_bw()+
  theme(legend.position = "bottom", legend.justification = "right",
        legend.box.spacing = unit(-2, "cm"), panel.grid.minor.y = element_blank(),
        plot.margin = margin(b = 1.05, r = 0.5, l = 0.5, t = 0.2, unit = "cm"),
        legend.text = element_text(size = 11), axis.title.x = element_blank(),
        legend.title = element_blank(), axis.title.y = element_text(size = 12),
        axis.text.x = element_text(angle = 45, vjust = 0.765, hjust = 0.65))+
  ylab("Biomass relative to mean biomass in the 1990s")
```

![](05_Plots_biomass_projections_SouthPacific_files/figure-gfm/unnamed-chunk-4-1.png)<!-- -->

### Saving plots

``` r
ggsave("new_prop_calcs.pdf", device = "pdf", width = 14, height = 9)
```
