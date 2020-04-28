#' Making the search form for the function "getTableInfo"
#'
#' https://mort.soa.org/ search page has the various options for search
#'
#' @param keywords Search Key words
#' @param nation Choose nation options: United States of America, Argentia, Australia etc.
#' @param tableUsage Table usage options: ADB, AD&D, Annuitant Mortality, Claim Cost etc.
#' @param tableType Table layout options: Aggregate, Attained Age, Continuance etc.
#' @param maxRow maxRow controls the maximum number of result you will get.
#' @param sortIndex sort the result using the preferred variable
#' @param sortDirection Choose "asc" or "desc" for sorting direction of the search result
#' 
#' @return A list contains search information you want to attain
#' @export
makeSearchInfo <- function(keywords = "",
                     nation = "-1", 
                     tableUsage = "-1",
                     tableType = "-1",
                     maxRow = 100,
                     sortIndex = "TableIdentity",
                     sortDirection = "asc"){
    body <- list(
        "keyWords"= keywords,
        "nation"= nation,
        "page"= 1,
        "rows"= maxRow,
        "sidx"= sortIndex,
        "sord"= sortDirection,
        "type"= tableType,
        "usage"= tableUsage,
        "_search"= "false"
    )
    return(body)
}

#' Getting search result from Mortality Tables hosted on http://mort.soa.org
#'
#' mortalitytable access to the website that contains mortality table and grab the information for you.
#'
#' @param searchInfo Search information which is the result of function makeSearchInfo
#' @param shortTname Set this value as TRUE will make the short table name, otherwise it will give you the table name and the other description too.
#' @return A list or dataframe contains various information in the table you have asked
#' @export
getTableInfo <- function(searchInfo, shortTname = TRUE){
    result <- httr::POST("https://mort.soa.org/WebService.asmx/GetListOfTables",
                         body = searchInfo, encode ="json")
    result <- httr::content(result)$d$rows
    result <- Map(purrr::transpose(result), f = unlist)
    result <- do.call(result, what = cbind.data.frame)
    
    if (shortTname == TRUE){
        nresult <- unlist(gregexpr(pattern = "&nbsp;",
                                   as.character(result$TableName))) - 1
        result$TableName <- as.character(result$TableName)
        result$TableName <- unlist(Map(result$TableName, f = substr, start = 1, stop = nresult),
                                   use.names = FALSE)
    }
    return(result)
}

#' Getting Data from Mortality Tables hosted on http://mort.soa.org
#'
#' mortalitytable access to the website that contains mortality table and grab the information for you.
#'
#' @param num The number of the table you want to access in the website
#' @return A list or dataframe contains various information in the table you have asked
#' @export
getTable <- function(num){
    url <- paste0("https://mort.soa.org/ViewTable.aspx?&TableIdentity=", num)
    twebsite <- httr::GET(url)
    Sys.sleep(3)
    tbls <- rvest::html_nodes(httr::content(twebsite), "table")
    ntbls <- length(tbls)
    check <- rep(0, ntbls)
    for(k in 1:ntbls){
        check[k] <- ifelse(colnames(rvest::html_table(tbls[[k]], fill = T))[1] == "Row\\Column", 1, 0)
    }
    
    if (sum(check) == 1){
        tinfo <- rvest::html_table(tbls[[1]], fill=T)
        mortTbl <- rvest::html_table(tbls[[4]], fill=T)
        
        mtable <- data.frame(age = mortTbl[,1])
        for (i in 2:dim(mortTbl)[2]){
            mtable <- cbind.data.frame(mtable, mortTbl[,i])
        }
        names(mtable)[-1] <- paste("Column", 1:(dim(mortTbl)[2]-1))
        
        # assign attribute
        for (i in 1:length(tinfo$X1)){
            attr(mtable, tinfo$X1[i]) <- tinfo$X2[i]    
        }
        result <- mtable
    } else { # case where sum(check) != 1
        mtlist <- vector(mode = "list", length = sum(check))
        geninfo <- rvest::html_table(tbls[[1]], fill=T)
        
        for (j in 1:sum(check)){
            mortTbl <- rvest::html_table(tbls[[which(check == 1)[j]]], fill=T)
            
            mtable <- data.frame(age = mortTbl[,1])
            for (i in 2:dim(mortTbl)[2]){
                mtable <- cbind.data.frame(mtable, mortTbl[,i])
            }
            names(mtable)[-1] <- paste("Column", 1:(dim(mortTbl)[2]-1))
            
            # assign attribute
            for (i in 1:length(geninfo$X1)){
                attr(mtable, geninfo$X1[i]) <- geninfo$X2[i]    
            }
            
            tinfo <- rvest::html_table(tbls[[(which(check == 1)[j]-1)]], fill=T)
            for (i in 1:4){
                attr(mtable, tinfo$X1[i]) <- tinfo$X2[i]    
            }
            
            mtlist[[j]] <- mtable
            
        }

        result <- mtlist
    }
    result
}

