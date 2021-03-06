# Copyright 2017 Province of British Columbia
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

# Simplification and aggregation for visualizations -----------------------

library(bcmaps)
library(rmapshaper)
library(feather)
library(dplyr)
library(sf)

source("fun.R")

dir.create("out", showWarnings = FALSE)
dir.create("out-shiny", showWarnings = FALSE)

## Create simplified versions of ecoregions for leaflet map
eco_leaflet_rds <- "out-shiny/ecoregions_t_leaflet.rds"
ecoregions_t_simp_leaflet <- tryCatch(readRDS(eco_leaflet_rds), error = function(e) {
  eco_t_simp_leaflet <- ms_simplify(ecoregions_t[,c("CRGNCD", "CRGNNM")], 0.001) %>%
    fix_geo_problems() %>%
    st_set_crs(3005) %>%
    st_transform(4326) %>%
    mutate(CRGNNM = tools::toTitleCase(tolower(as.character(CRGNNM)))) %>%
    group_by(CRGNCD, CRGNNM) %>%
    summarise()
  saveRDS(as(st_cast(eco_t_simp_leaflet), "Spatial"), eco_leaflet_rds)
  eco_t_simp_leaflet
})

## Create simplified versions of ecoregions for visualization
ecoregions_t_simp_rds <- "tmp/ecoregions_t_simp.rds"
ecoregions_t_simp <- tryCatch(readRDS(ecoregions_t_simp_rds), error = function(e) {
  eco_t_simp <- ms_simplify(ecoregions_t, 0.01) %>%
    fix_geo_problems()
  saveRDS(eco_t_simp, ecoregions_t_simp_rds)
  eco_t_simp
})

gg_ecoreg <- gg_fortify(as(ecoregions_t_simp, "Spatial")) %>%
  write_feather("out-shiny/gg_ecoreg.feather")

## Simplify BEC pologyons for use in display
bec_zone_rds <- "tmp/bec_zone.rds"
bec_zone <- tryCatch(readRDS(bec_zone_rds), error = function(e) {
  bec_zone <- group_by(bec_t, ZONE) %>%
    summarize() %>%
    fix_geo_problems()
  bec_zone$zone_area <- st_area(bec_zone)
  saveRDS(bec_zone, bec_zone_rds)
  bec_zone
})

bec_zone_simp_rds <- "tmp/bec_zone_simp.rds"
bec_zone_simp <- tryCatch(readRDS(bec_zone_simp_rds), error = function(e) {
  bec_zone$zone_area <- as.numeric(bec_zone$zone_area) ## Of class units, need as numeric
  bec_zone_simp <- bec_zone %>%
    ms_simplify(keep = 0.005) %>%
    fix_geo_problems()
  saveRDS(bec_zone_simp, bec_zone_simp_rds)
  bec_zone_simp
})

gg_bec <- as(bec_zone_simp, "Spatial") %>%
  gg_fortify() %>%
  write_feather("out-shiny/gg_bec.feather")

## Further simplification for BEC leaflet map
bec_zone_leaflet_rds <- "out-shiny/bec_leaflet.rds"
bec_zone_leaflet <- tryCatch(readRDS(bec_zone_leaflet_rds), error = function(e) {
  bec_zone_leaflet <- bec_zone_simp %>%
    ms_simplify(0.1) %>%
    fix_geo_problems() %>%
    st_transform(4326)
  bec_zone_leaflet$ZONE <- as.character(bec_zone_leaflet$ZONE)
  saveRDS(as(bec_zone_leaflet, "Spatial"), bec_zone_leaflet_rds)
  bec_zone_leaflet
})

## Simplify ld a bit more for shiny plotting
ld_simp_more <- ms_simplify(ld_simp, keep = 0.05, explode = TRUE, keep_shapes = TRUE) %>%
  fix_geo_problems() %>%
  group_by(category) %>%
  summarise()

## Intersect simplified ld with simplified bec to get viz object:
ld_bec_simp <- st_intersection(bec_zone_simp, ld_simp_more) %>%
  st_collectionextract("POLYGON") %>%
  select(ZONE, category) %>%
  fix_geo_problems()

gg_ld_bec <- as(ld_bec_simp, "Spatial") %>%
  gg_fortify() %>%
  write_feather("out-shiny/gg_ld_bec.feather")

## Intersect simplified ld with simplified ecoregions to get viz object:
ld_ecoreg_simp <- st_intersection(ecoregions_t_simp, ld_simp_more) %>%
  st_collectionextract("POLYGON") %>%
  select(CRGNCD, category) %>%
  fix_geo_problems()

gg_ld_ecoreg <- as(ld_ecoreg_simp, "Spatial") %>%
  fix_geo_problems() %>%
  gg_fortify() %>%
  write_feather("out-shiny/gg_ld_ecoreg.feather")

# Copy gg objects from tmp needed for shiny app
file.copy(from = file.path("tmp", c("gg_ld_simp.feather", "gg_bc_bound.feather")),
          to = "out-shiny")

# Copy all objects needed for shiny app to shiny app project folder
files_list <- list.files("out-shiny", pattern = "\\.feather$|\\.rds$", full.names = TRUE)
file.copy(from = files_list, to = "../land-designations-shinyapp/app/data", overwrite = TRUE)
