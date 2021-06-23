---
title: "Systematic review in R. Part 1"
author: "Elena Shekhova"
output: 
  html_document: 
    toc: yes
    keep_md: yes
date: "`r format(Sys.time(), '%d %B %Y')`"
params:
  year_start: 1990-01-01
  year_end: 2021-02-12
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(fig.align = 'center', echo = TRUE)
```

### Load necessary R packages 
If libraries were not loaded before, it is necessary to install them first. 
`metagear` library depends on `EBImage`package, which is a part of the Bioconductor repository and which can be installed via `install.packages("BiocManager"); #BiocManager::install("EBImage")` commands.
```{r data, echo=TRUE, message = FALSE}
#install.packages("RISmed")
#install.packages("dplyr")
#install.packages("BiocManager"); 
#BiocManager::install("EBImage")
#install.packages("metagear")
library(RISmed)
library(dplyr)
library(metagear)
```

### Download content from NCBI Databases

At this stage, `RISmed` package will be used to extract information from databases including Abstract's text.
A great guideline on how to use `RISmed package` can be found [here]( http://amunategui.github.io/pubmed-query/).

1. Assign your query based on key words `invasive aspergillosis risk factors`, which are your search terms, to a variable `search_topic`. 

2. Create a variable `search_query` using `EUtilsSummary` function. The function sends the request to the database and gets all paper's IDs that match the query. You also can specify a time frame for the search using `mindate` and `maxdate` arguments. In this example, this period ends on 12th of February 2021. To keep the results consistent, each reviewer/collaborator should specify the same period. 

3. Check the number of papers available on this query with `summary` function.

4. When satisfied with the results of the search, download the actual data with `EUtilsGet` function and assign it to a new variable `records`.  

5. By using `class` function you can see the type of object that is created by `EUtilsGet`. In this case, it is `Medline`, and package `RISmed` provides a set of useful functions that allow to interact and extract needed set of information from any `Medline` object. 

```{r pressure, echo=TRUE}
search_topic <- 'invasive aspergillosis risk factors'
search_query <- EUtilsSummary(search_topic, mindate = '1990/01/01', maxdate = '2021/02/12')
summary(search_query)
records<- EUtilsGet(search_query)
class(records)
```
### Optional: create a new function to save Initials of each author 

When `RISmed`'s function called `Author` is used, it will save a list of all authors of a publication into a data.frame. It can be checked with following steps:

1. Assign all information about authors to `author_list`. 

2. Information about authors of a paper in the list can be viewed by providing an index of this paper in the list. For instance, `11`

```{r authors, echo=TRUE}
author_list <- Author(records)
author_list$`11`
```

To improve readability of the final table, it is better to only present first author's surname and their initials. Let's create a new function called `getFirstAuthor` that will extract only the Surname and Initials of the first author. 

In the printed data.frame, we can see that a surname can be found in the first column and initials are in the third. To access a specific place in the data.frame, we need to provide exact indexes of that place. Thus, the first author's (first row) surname is at `[1,1]` and initials at `[1,3]`.

3. A new function is created by providing its name (like any variable), here `getFirstAuthor`; then a keyword `function`; and in the brackets the list of arguments that the function will use within. Here, it is assumed that we will pass a data.frame like above and will name the argument `authors`. First, we extract the surname and initial from the first row, and then we merge them together into one string by using `paste` function and `return` the result.

```{r function, echo=TRUE}
getFirstAuthor <- function (authors)
{
  authorSurname <- authors[1,1]
  authorInitials <- authors[1,3]
  return (paste(authorSurname, authorInitials, sep = ", "))
}
```

4. Test the function by giving it only one data.frame first (for example, data.frame displaying 11th publication):
```{r testing, echo=TRUE}
getFirstAuthor(author_list$'11')
```

5. Apply a newly created `getFirstAuthor` function to each element of the list (`lapply`) and record it into a new variable `authors`, which we need to have as a character vector for future. As `lapply` returns a list with the same length as the inputted data, we need to transform it explicitly by using `as.character`.

```{r lapply, echo=TRUE}
authors <- as.character(lapply(author_list, getFirstAuthor))
head(authors, 5)
```
### Create a data frame containing meta-data

1. Create your data.frame called `data` using `data.frame` function and specify which tags it should include. By clicking on `records` in the `Global Environment` (your right upper window), you can see the meta-data that can be saved in your data frame as tags for each publication.

2. Make your data comma-free, so that it can be saved as comma delimited data sets later on. This is especially important for Abstract texts. First transform all objects of the text into characters with `as.charecter` function and then replace all commas with free space using `gsub` function.

3. Remove papers that are not in English and save it as a new data frame `data_eng`. To achieve this use `filter` function from `dplyr` package. Skip this step if you targeting all papers, regardless of the language.

4. Check what information `data_eng` object contains using `summary` function.

5. Save your file now in `csv` format. It can be opened in Excel.

```{r meta-data}
data <- data.frame('TITLE'=ArticleTitle(records), 'AUTHORS'=authors, 'PMID'=PMID(records),   
                          'YEAR'=YearPubmed(records), 'DOI'=DOI(records), 
                          'JOURNAL'=MedlineTA(records), 'LANGUAGE'=Language(records),
                          'COUNTRY'=Country(records), 'ABSTRACT'=AbstractText(records))
data$ABSTRACT <- as.character(data$ABSTRACT)
data$ABSTRACT <- gsub(",", " ", data$ABSTRACT, fixed = TRUE)
data_eng <- filter(data, LANGUAGE == "eng") 
summary(data_eng)
write.csv(data_eng, file = "data_eng.csv")
```

### Screen abstracts
Studies will be screened using `metagear` package. A very detailed and easy-to-follow guide on how to use this package can be found [here](http://lajeunesse.myweb.usf.edu/metagear/metagear_basic_vignette.html#how-to-cite).

The main aim of the screening is to include all epidemiological studies that focus on invasive aspergillosis.

The exclusion criteria are following:

* one case studies
* laboratory research
* reviews
* studies focusing on several fungal infections (invasive fungal infection)
* trial pre-results
* systematic reviews
* guidelines 
* therapeutic drug monitoring
* studies on various species like dogs or mice 
* clinical investigations focusing only on pediatric patients
* studies on aspergilloma
* studies describing clinical characteristics of invasive aspergillosis
* publications without abstracts


1. Initialize screening with `effort_distribute function` and by creating a new data.frame called `theRefs`. This table will add additional columns, such as `STUDY_ID`, `REVIEWER`, and `INCLUDE` to our data.frame.

2. Save new data.frame with `write.csv` function.

3. Start screening with `abstract_screener` function and specify which file needs to be screen, name of a reviewer, the name of columns that will indicate the status of each publication, and also key words that can be highlighted in each abstract.

```{r review}
#theTeam <- c("Tanmoy", "Fabian", "Alessandra")
#theRefs_unscreened <- effort_distribute(data_eng, reviewers = theTeam, save_split = TRUE)
#data_eng_Fab <- read.csv("effort_Fabian.csv", header = TRUE)
#theRefs_Fab <- effort_distribute(data_eng_Fab, reviewers = c("Fabian"), initialize = TRUE)
#write.csv(theRefs_Fab, file = "EvaRefs_Fab.csv")
#theRefs_unscreened_Fab <- abstract_screener("EvaRefs_Fab.csv", aReviewer = "Fabian", unscreenedColumnName = #"INCLUDE", unscreenedValue = "not vetted", highlightKeywords = "aspergillosis")
theRefs <- effort_distribute(data_eng, reviewers = c("Elena"), initialize = TRUE)
write.csv(theRefs, file = "ElenaRefs.csv")
theRefs_unscreened <- abstract_screener("ElenaRefs.csv", aReviewer = "Elena", unscreenedColumnName = "INCLUDE", unscreenedValue = "not vetted", highlightKeywords = "aspergillosis")
```

### Citations
Hadley Wickham, Romain François, Lionel Henry and Kirill Müller (2021). dplyr: A Grammar of Data
  Manipulation. R package version 1.0.6. [link](https://CRAN.R-project.org/package=dplyr)
  
Stephanie Kovalchik (2020). RISmed: Download Content from NCBI Databases. R package version 2.2.
  [link](https://CRAN.R-project.org/package=RISmed)

Lajeunesse, M.J. (2016) Facilitating systematic reviews, data extraction, and meta-analysis with the
  metagear package (Version: 0.7) for R.  Methods in Ecology and Evolution 7: 323-330
