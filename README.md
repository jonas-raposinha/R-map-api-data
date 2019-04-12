# R-map-api-data
Automating report generation by using data from an API to print a standardized (map) plot in Tidyverse.

Automating workflows can be a great way to save time for the important things in life. For example, monthly statistical reports containing a certain set of graphs, only updated with the latest data, could take a significant amount of time to prepare each time. Fortunately, many sources of statistical data these days have APIs that allow us to download the data we need through a script rather than having to click our way through their web interfaces. Below, I will use the open statistics database of the [Swedish Board of Health and Welfare](http://sdb.socialstyrelsen.se/sdbapi.aspx) (SBHW) as an example of how to automatically generate a gradient map of regional data on antibiotic prescriptions in Sweden. Also, to mix things up a bit from the [previous map exercise](https://github.com/jonas-raposinha/r-map-plotting), I will use the Tidyverse.

```R
library(tidyverse) #Multifunctional package, includes among other useful things “ggplot” for plotting and “dplyr” for data manipulation
library(httr) #Handles communication with the API
library(jsonlite) #Interprets the commonly used JSON format to R objects
library(rgdal) #Package for handling maps in the very useful shapefile format
```

To download data using the SBHW’s API, we need the API url and the data path. Depending on how well documented an API is, these things may be more or less easy to figure out. In the case of SBHW, the database actually consists of several databases for different areas, such as causes of death, obstetrics, dentistry or pharmaceuticals, antibiotics belonging to the latter one (coded as “lakemedel”). Then we need to define what data are needed to produce our desired graph and how those are coded in the database. As we wish to plot the total amount of antibiotics consumed in Sweden, we of course need to specify the pharmacuetial class (coded as "atc") and some appropriate measure of antibiotic consumption (coded as "matt" in the database) stratified by region (coded as "region"). Finally, we need to specify the year the data represents (coded as "ar"), the most recent being 2017. Incidentally, this is the only variable that we will need to change in order to remake the graph next year. We can thus define the url and path. Side note: the measure "matt 3" codes for the number of expedited antibiotic prescriptions.

```R
url <- "http://sdb.socialstyrelsen.se/api"
path <- "/api/v1/sv/lakemedel/resultat/matt/3/atc/J01/region/0,1,3,4,5,6,7,8,9,10,12,13,14,17,18,19,20,21,22,23,24,25/ar/2017" 
#database = ”lakemedel”, output = ”resultat”, measure = ”matt 3”, class = ”atc J01”, region = all regions by numbers, year = ”ar 2017”
```

Now we are ready to query the API. Downloading data is done by the GET() call.

```R
raw.search <- GET(url = url, path = path)
raw.search
> Response
> [http://sdb.socialstyrelsen.se/api/v1/sv/lakemedel/resultat/matt/3/atc/J01/region/0,1,3,4,5,6,7,8,9,10,12,13,14,17,18,19,20,21,22,23,24,25/ar/2017]
> 	Date: 2019-04-12 11:30
>  	Status: 200
>  	Content-Type: application/json; charset=utf-8
>  	Size: 457 kB
```
The result is a list of class "response", the content of which tells us that the query was successful (status code "200") and that it’s in JSON format. Further information on http status codes can be found [here](https://restfulapi.net/http-status-codes/). The data we are after are found in raw format in the “content” component, which can be turned into a character string using rawToChar().

```R
raw.search$content %>%
rawToChar() %>% 
substr(start = 1, stop = 50) 
[1] "{\"data\":[{\"atcId\":\"J01\",\"regionId\":0,\"alderId\":1,\""
```

Interpreting the JSON format gives us a list, from which we can extract the data.

```R
  read.content <- 
    raw.search$content %>%
    rawToChar() %>%
    fromJSON()
names(read.content)
> [1] "data"            "amne"            "nasta_sida"      "foregaende_sida" "sida"            "per_sida"       
> [7] "sidor"          
use_raw <-
  read.content$data %>%
  data.frame()
head(use_raw)
>  atcId regionId alderId konId   ar  varde
> 1   J01        0       1     1 2017 107894
> 2   J01        0       1     2 2017  93992
> 3   J01        0       1     3 2017 201886
> 4   J01        0       2     1 2017  73754
> 5   J01        0       2     2 2017  81052
> 6   J01        0       2     3 2017 154806
```

Let's fix it up a bit by dropping unnecessary variables, changing our measure to 'numeric' and renaming the columns to something easy to understand.

```R
use_raw <-  
  use_raw %>% 
  select(-c(mattId, ar))
use_raw$varde <- as.numeric(use_raw$varde)
colnames(use_raw) <- c("ATC", "regionId", "ageId","sexId", "exp")
```

Next, I’ll give two specific examples of the usefulness of process automation. The first relates to data access, as SBHW’s database limits output to 5000 rows per query and making repeated queries manually can be very tedious. When using the API though, we can simply create a loop that checks the number of rows returned, and if it’s 5000, makes another query until we get the entire chunk of data. The query order is indicated at the end of ‘path’, kind of like a page number.

```R
iter <- 2 #Iter variable to indicate the query number
while(nrow(read.content$data) == 5000){
  path <- sprintf("/api/v1/sv/lakemedel/resultat/matt/3/atc/J01 /region/ar/2017?sida=%i", iter) #In this case not needed since that query yields < 5000 rows
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
```

The second example concerns data processing. Say that we would like to report the total consumption with a denominator of per 1000 inhabitants. To do this, we first need to download the relevant population sizes. These happen to be included as a measure in the SBHW database, but unfortunately we can only download one measure per query (due to some unknown peculiarity). No worries, we will simply get them the same way we got the current measure.
```R
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
```

Next, we summarize using group_by() to lock all variables except ageId.

```R
use_plot <-
 use_raw %>%
 group_by(regionId, sexId, ATC) %>%
 summarise(exp = sum(exp))
```

This is repeated for the population data, followed by matching the two data sets by right_join(), calculating the ratio using mutate() and then filtering to only include data for “both sexes”. Note that we need to ungroup() before we can remove grouped variables.

```R
use_plot <-
  pop_raw %>%
  group_by(regionId, sexId, ATC) %>%
  summarise(pop = sum(pop)) %>%
  right_join(use_plot, by = c("regionId", "sexId")) %>%
  mutate(exp_per_1000 = exp/pop*1000) %>%
  filter(sexId == 3) %>% #’3’ codes for “both sexes”
  ungroup() %>%
  select(regionId, exp_per_1000) 
```

Next, we need a map of Sweden map, eg the one assembled by [ESRI Sweden](https://www.arcgis.com/home/item.html?id=912b806e3b864b5f83596575a2f7cb01). All packages within the Tidyverse (including ggplot2) like data to be ["tidy"](https://cran.r-project.org/web/packages/tidyr/vignettes/tidy-data.html), which shapefile data are not. Fortunately, they have made the conversion easy for us. We should not forget to change the class of the region Id’s to ‘integer’ in order to match them later.

```R
shp.sweden <- readOGR(dsn = "Lan_SCB", layer = "Länsgränser_SCB_07") 
class(shp.sweden)
> [1] "SpatialPolygonsDataFrame"
> attr(,"package")
> [1] "sp"
shapefile_df <- broom::tidy(shp.sweden)
class(shapefile_df)
> [1] "tbl_df"     "tbl"        "data.frame"
shapefile_df$id <- as.integer(shapefile_df$id)
```

Then we can go ahead and plot it using ggplot() and geom_polygon(), which draws regions connected by lines. The 'x' and 'y' are provided by longitudes and latitudes from the map file.
```R
ggplot() + geom_polygon(data=shapefile_df, aes(x=long, y=lat, group = group))
```
![plot 1](https://github.com/jonas-raposinha/R-map-api-data/blob/master/images/Rplot1.png)

The regional codes are different in the shapefile and our data, so we need to match them.

```R
lan_map <- #Create a LUT for the regional codes
  data.frame(regionId = unique(use_raw$regionId))
lan_map$region <- 0:20
use_plot <- #Change the regional codes to fit the shapefile format
  use_plot %>%
  right_join(lan_map, by = c("regionId")) %>%
  select(-regionId)
```

That came out ok, so let’s go ahead and match the data to the correct region (coded as “id” in the shapefile).

```R
shapefile_df <- 
  shapefile_df %>%
  right_join(use_plot, by = c("id" = "region")) #Match data to shapefile codes
```

Time to plot the data, indicated by 'fill', while 'colour' refers to the map borders.

```R
gg <- ggplot() + geom_polygon(data=shapefile_df, aes(x=long, y=lat, group = group, fill = shapefile_df$exp_per_1000), size = 0.1, colour="black")
```
![plot 2](https://github.com/jonas-raposinha/R-map-api-data/blob/master/images/Rplot2.png)


```R
---under construction---
```
