## Plots map of Sweden with regions coloured by consumption of antibiotics, downloaded from the API of the Swedish Board of Health and Welfare, latest update 2019-04-12

library(tidyverse) #Multifunctional package, includes among other useful things "ggplot" for plotting and "dplyr" for data manipulation
library(httr) #Handles communication with the API
library(jsonlite) #Interprets the commonly used JSON format to R objects
library(rgdal) #Package for handling maps in the very useful shapefile format

#The API URL
url <- "http://sdb.socialstyrelsen.se/api"

#Looping through the API query to capture data larger than 5000 rows
read.content$data <- 0
iter <- 1 #Iter variable to indicate the query number
while(nrow(read.content$data) == 5000){
  path <- "/api/v1/sv/lakemedel/resultat/matt/3/atc/J01/region/0,1,3,4,5,6,7,8,9,10,12,13,14,17,18,19,20,21,22,23,24,25/ar/2017"#database = "lakemedel", output = "resultat", measure = "matt 3", class = "atc J01", region = all regions by numbers, year = "ar 2017"
  raw.search <- GET(url = url, path = path)
  read.content <- 
    raw.search$content %>%
    rawToChar() %>%
    fromJSON()
  use_temp <-
    read.content$data %>%
    data.frame() 
  use_raw <-
    use_raw %>%
    rbind(use_temp)
  iter <- iter + 1
}
#Formatting the data and updating column names
use_raw <- 
  read.content$data %>%
  data.frame() %>%
  select(-c(mattId, ar))
use_raw$varde <- as.numeric(use_raw$varde)
colnames(use_raw) <- c("ATC", "regionId", "ageId", "sexId", "exp")

#Query the API for the denominator data (population size)
path <- "/api/v1/sv/lakemedel/resultat/matt/9/atc/J01/region/0,1,3,4,5,6,7,8,9,10,12,13,14,17,18,19,20,21,22,23,24,25/ar/2017" #Measure "9" is population size
raw.search <- GET(url = url, path = path)
read.content <- 
  raw.search$content %>%
  rawToChar() %>%
  fromJSON()
pop_raw <-
  read.content$data %>%
  data.frame() %>%
  select(-c(mattId, ar))
pop_raw$varde <- as.numeric(pop_raw$varde)
colnames(pop_raw) <- c("ATC", "regionId", "ageId", "sexId", "pop")

#Summing the age groups and calculating the exp/pop ratio, then all unneccesary variables are dropped
use_plot <-
  use_raw %>%
  group_by(regionId, sexId, ATC) %>%
  summarise(exp = sum(exp))
use_plot <-
  pop_raw %>%
  group_by(regionId, sexId, ATC) %>%
  summarise(pop = sum(pop)) %>%
  right_join(use_plot, by = c("regionId", "sexId")) %>%
  mutate(exp_per_1000 = exp/pop*1000) %>%
  filter(sexId == 3) %>% #'3' codes for "both sexes"
  ungroup() %>%
  select(regionId, exp_per_1000) 

shp.sweden <- readOGR(dsn = "Lan_SCB", layer = "Länsgränser_SCB_07") 
shapefile_df <- broom::tidy(shp.sweden)
shapefile_df$id <- as.integer(shapefile_df$id)

lan_map <- #Create a LUT for the regional codes
  data.frame(regionId = unique(use_raw$regionId))
lan_map$region <- 0:20
use_plot <- #Change the regional codes to fit the shapefile format
  use_plot %>%
  right_join(lan_map, by = c("regionId")) %>%
  select(-regionId)
shapefile_df <- 
  shapefile_df %>%
  right_join(use_plot, by = c("id" = "region"))
  
caption_text <- sprintf("Source: Swedish Board of Health and Welfare, %s", Sys.Date())

gg <- ggplot() + geom_polygon(data=shapefile_df, aes(x=long, y=lat, group = group, fill = shapefile_df$exp_per_1000), size = 0.1, colour="black")
gg
gg <- gg + scale_fill_gradient(name = str_wrap("Prescriptions/1000 inhabitants", 20), low = "steelblue1", high = "midnightblue", guide = "colourbar") 
gg <- gg + labs(title=str_wrap("Regional antibiotics consumption in Sweden, all ages, both sexes for 2017", 45), y="", x="", caption = caption_text) 
gg <- gg + theme(panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(), 
          panel.background = element_blank(),
          axis.text.x = element_blank(),
          axis.text.y = element_blank(),
          axis.ticks = element_blank()) 
gg <- gg + theme(plot.title=element_text(size=24, face="bold", lineheight=1.2),
          plot.caption=element_text(size=20, hjust=-0.1),
          legend.title=element_text(size=20, face="bold"),
          legend.text=element_text(size=20),
          legend.key.size = unit(2, "cm"))

pdf("swemap.pdf", w=10, h=15, pointsize = 1) #Sets an aspect ratio that fits the plot
gg
dev.off()
