# R-map-api-data
Automating report generation by using data from an API to print a standardized (map) plot in Tidyverse.

Automating workflows can be a great way to save time for the important things in life. For example, monthly statistical reports containing a certain set of graphs, only updated with the latest data, could take a significant amount of time to prepare each time. Fortunately, many sources of statistical data these days have APIs that allow us to download the data we need through a script rather than having to click our way through their web interfaces. Below, I will use the open statistics database of the [Swedish Board of Health and Welfare](http://sdb.socialstyrelsen.se/sdbapi.aspx) (SBHW) as an example of how to automatically generate a gradient map of regional data on antibiotic prescriptions in Sweden. Also, to mix things up a bit from the [previous map exercise](https://github.com/jonas-raposinha/r-map-plotting), I will use the Tidyverse.

```R
library(tidyverse) #Multifunctional package, includes among other useful things “ggplot” for plotting and “dplyr” for data manipulation
library(httr) #Handles communication with the API
library(jsonlite) #Interprets the commonly used JSON format to R objects
library(rgdal) #Package for handling maps in the very useful shapefile format
```

To download data using the SBHW’s API, we need the API url and the data path. Depending on how well documented an API is, these things may be more or less easy to figure out. In the case of SBHW, the database actually consists of several databases for different areas, such as causes of death, obstetrics, dentistry or pharmaceuticals, antibiotics belonging to the latter one (coded as “lakemedel”). Then we need to define what data are needed to produce our desired graph and how those are coded in the database. As we wish to plot the total amount of antibiotics consumed in Sweden, we of course need to specify the pharmacuetial class (coded as "atc") and some appropriate measure of antibiotic consumption (coded as “matt” in the database) stratified by region (coded as "region"). Finally, we need to specify the year the data represents (coded as "ar"), the most recent being 2017. Incidentally, this is the only variable that we will need to change in order to remake the graph next year. We can thus define the url and path. Side note: the measure “matt 3” codes for the number of expedited antibiotic prescriptions.

```R
url <- "http://sdb.socialstyrelsen.se/api"
path <- "/api/v1/sv/lakemedel/resultat/matt/3/atc/J01/region/0,1,3,4,5,6,7,8,9,10,12,13,14,17,18,19,20,21,22,23,24,25/ar/2017" 
#database = ”lakemedel”, output = ”resultat”, measure = ”matt 3”, class = ”atc J01”, region = all regions by numbers, year = ”ar 2017”
```

Now we are ready to query the API. Downloading data is done by the GET() call.

```R
raw.search <- GET(url = url, path = path)
> raw.search
Response [http://sdb.socialstyrelsen.se/api/v1/sv/lakemedel/resultat/matt/3/atc/J01/region/0,1,3,4,5,6,7,8,9,10,12,13,14,17,18,19,20,21,22,23,24,25/ar/2017]
 	Date: 2019-04-12 11:30
  	Status: 200
  	Content-Type: application/json; charset=utf-8
  	Size: 457 kB
```
The result is a list of class “response”, the content of which tells us that the query was successful (status code “200”) and that it’s in JSON format. Further information on http status codes can be found [here](https://restfulapi.net/http-status-codes/). The data we are after are found in raw format in the “content” component, which can be turned into a character string using rawToChar().
