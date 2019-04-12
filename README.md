# R-map-api-data
Automating report generation by using data from an API to print a standardized (map) plot in Tidyverse.

Automating workflows can be a great way to save time for the important things in life. For example, monthly statistical reports containing a certain set of graphs, only updated with the latest data, could take a significant amount of time to prepare each time. Fortunately, many sources of statistical data these days have APIs that allow us to download the data we need through a script rather than having to click our way through their web interfaces. Below, I will use the open statistics database of the Swedish Board of Health and Welfare (SBHW) as an example of how to automatically generate a gradient map of regional data on antibiotic prescriptions in Sweden. Also, to mix things up a bit from the [previous map exercise](https://github.com/jonas-raposinha/r-map-plotting), I will use the Tidyverse.

```R
library(tidyverse) #Multifunctional package, includes among other useful things “ggplot” for plotting and “dplyr” for data manipulation
library(httr) #Handles communication with the API
library(jsonlite) #Interprets the commonly used JSON format to R objects
library(rgdal) #Package for handling maps in the very useful shapefile format
```
