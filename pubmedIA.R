
#1. Extract data from PubMed and organize it in a data frame
#install.packages("RISmed") to extract data from NCBI Databases
library(RISmed)
search_topic <- 'invasive aspergillosis risk factors'
search_query <- EUtilsSummary(search_topic)
summary(search_query)
records<- EUtilsGet(search_query)
class(records)

author_list <- Author(records)
# Each element of the list is a dataframe with the following structure
author_list$`11`
#     LastName ForeName Initials order
#   1 Bitterman     Roni        R     1
#   2 Marinelli     Tina        T     2
#   3    Husain   Shahid        S     3

# Given a dataframe with the structure as above the function returns
# the first author in a format 'Surname, Initials', aka 'Shekhova, E'
getFirstAuthor <- function (authors)
{
  authorSurname <- authors[1,1]
  authorInitials <- authors[1,3]
  return (paste(authorSurname, authorInitials, sep = ", "))
}

# Applying a newly created "GetFirstAuthor" function to each element of the list and transforming it  
# into the character vector
authors <- as.character(lapply(author_list, getFirstAuthor))

# This is the same as above, another alternative using basic loop
#a <- c()
#for (authors in author_list) {
#  first <- authors[1,1]
#  a <- append (a, first)
#}
#a <- lapply(author_list, Name == authors[1,1])

data <- data.frame('TITLE'=ArticleTitle(records), 'AUTHORS'=authors, 'PMID'=PMID(records),   
                          'YEAR'=YearPubmed(records), 'DOI'=DOI(records), 
                          'JOURNAL'=MedlineTA(records), 'LANGUAGE'=Language(records),
                          'COUNTRY'=Country(records), 'ABSTRACT'=AbstractText(records))

#Include only Reviews from the data frame
#type_list <- PublicationType(records)
#df <- data.frame(matrix(unlist(type_list), nrow=length(type_list), byrow=TRUE))
#isReview <- (df$X1 == "Review") | (df$X2 == "Review")
#my_data <- pubmed_data[isReview, ]

head(data,5)


data$ABSTRACT <- as.character(data$ABSTRACT)
data$ABSTRACT <- gsub(",", " ", data$ABSTRACT, fixed = TRUE)
#2.1. You can instead remove all semicolons (`;`) with the same method as above, and later write you final data
#on the csv file with `;` as separator.

library(dplyr)
data_eng <- filter(data, LANGUAGE == "eng") 
summary(data_eng)
write.csv(data_eng, file = "data_eng.csv")
#5.1. If you removed `;` instead of `,`, specify `sep=";"` as an argument. Later in Excel, you may need 
#to specify it as well.
# write.csv(data_eng, file = "data_eng.csv", sep=";")
#install.packages("BiocManager"); 
#BiocManager::install("EBImage")

library(metagear)

theRefs <- effort_distribute(data_eng, reviewers = c("Elena"), initialize = TRUE)
# Careful not to overwrite  write.csv(theRefs, file = "ElenaRefs.csv")
theRefs_unscreened <- abstract_screener("ElenaRefs.csv", aReviewer = "Elena", unscreenedColumnName = "INCLUDE", unscreenedValue = "not vetted", highlightKeywords = "aspergillosis")


theRefs_sorted<-read.csv("ElenaRefssorted.csv", header = TRUE)
head(theRefs_sorted) # Quick browse

library(dplyr)

data_YES <- filter(theRefs_sorted, INCLUDE == "YES") 
summary(data_YES)
write.csv(data_YES, file = "data_YES.csv")

#download PDFs and name them by STUDY_ID
collectionOutcomes <- PDFs_collect(data_YES, DOIcolumn = "DOI", FileNamecolumn = "STUDY_ID", quiet = TRUE)
table(collectionOutcomes$downloadOutcomes)

#download PDFs that were not loaded, evaluate the full text, and screen the studies,
#contact authors for missing information and exclude not relevant studies

data_YESed <- read.csv("data_YESed.csv", header = TRUE)

#create data set listing papers that were not included

data_NO <- filter(data_YESed, INCLUDE == "NO")
data_NO2 <- select (data_NO, STUDY_ID, TITLE, AUTHORS, YEAR)
data_NO2 <- add_column (data_NO2, EXCLUSION=NA)

#save the data set and manually define a reason for exclusion of each paper into "EXCLUSION" column
write.csv(data_NO2, file = "data_NO2.csv")
#categories: CC - case control study, R - review, T - treatment, IA - IA patients only, FI - reports on fungal infections
#NR - age not reported, M - studies on mortality, CO - age cut off, NO - no response from authors 
data_No2ed <- read.csv("data_No2ed.csv", header = TRUE)
#table(data_No2ed$EXCLUSION)

#to calculate the amount of papers in each group chosen for exclusion
library(gtsummary)
data_NO2ed2 <- select (data_No2ed, STUDY_ID, EXCLUSION)
data_NO2ed2 %>% tbl_summary()


#library(PRISMAstatement)
#prsm <-prisma(found = 800,
#       found_other = 200,
#       no_dupes = 1000,
#       screened = 860,
#       screen_exclusions = 776,
#       full_text = 84,
#       full_text_exclusions = 49,
#       qualitative = 35,
#       quantitative = 35,
#       width = 800, height = 800,
#       dpi=300)

#prisma_pdf(g, "test.pdf")
#knitr::include_graphics("test.pdf")
#tmp_pdf <- tempfile()

#PRISMAstatement:::prisma_pdf(prsm, tmp_pdf)
#knitr::include_graphics(path = tmp_pdf)
#unlink(tmp_pdf)

phases <- c("START_PHASE: 860 of studies identified through database searching",
            "860 of studies with title and abstract screened",
            "EXCLUDE_PHASE: 776 of studies excluded",
            "84 of full-text articles assessed for eligibility",
            "EXCLUDE_PHASE: 49 of full-text excluded, not fitting eligibility criteria",
            "35 of studies included in qualitative synthesis",
            "EXCLUDE_PHASE: # studies excluded, incomplete data reported",
            "final # of studies included in quantitative synthesis (meta-analysis)")

plot_PRISMA(phases,
  colWidth = 30,
  excludeDistance = 0.8,
  design = "classic",
  hide = FALSE)
plot_PRISMA(phases)

data_YES2 <- filter(data_YESed, INCLUDE == "YES") 
write.csv(data_YES, file = "data_YES2.csv")
