## Copyright 2013 Stefan Widgren and Maria Noremark,
## National Veterinary Institute, Sweden
##
## Licensed under the EUPL, Version 1.1 or - as soon they
## will be approved by the European Commission - subsequent
## versions of the EUPL (the "Licence");
## You may not use this work except in compliance with the
## Licence.
## You may obtain a copy of the Licence at:
##
## http://ec.europa.eu/idabc/eupl
##
## Unless required by applicable law or agreed to in
## writing, software distributed under the Licence is
## distributed on an "AS IS" basis,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
## express or implied.
## See the Licence for the specific language governing
## permissions and limitations under the Licence.

##' Visualize and animate movements on a map.
##'
##' The argument movements in Animate is a \code{data.frame}
##' with the following columns:
##' \describe{
##'
##'   \item{source}{
##'     an integer or character identifier of the source holding.
##'   }
##'
##'   \item{destination}{
##'     an integer or character identifier of the destination holding.
##'   }
##'
##'   \item{t}{
##'     the Date of the transfer
##'   }
##' }
##'
##' The argument coords in Animate is a \code{data.frame}
##' with the following columns:
##' \describe{
##'
##'   \item{id}{
##'     an integer or character identifier of the holding.
##'   }
##'
##'   \item{lat}{
##'     the latitude of holding.
##'   }
##'
##'   \item{lon}{
##'     the longitude of the holding.
##'   }
##' }
##' @title Animate
##' @param movements a \code{data.frame} data.frame with movements, see
##' details.
##' @param coords a \code{data.frame} data.frame with coordinates, see
##' details.
##' @param map a ggmap object to use as background map, see
##' \code{\link[ggmap]{get_map}}.
##' @param interval the time interval to aggregate movements in the
##' animation. Can be any of 'day', 'week', 'month', 'quarter' or
##' 'year'. Defaults to 'day'.
##' @param outdir the output directory for the animation, see
##' \code{\link[animation]{ani.options}}. Defaults to \code{getwd()}.
##' @param title the title of the animation in the HTML, see
##' \code{\link[animation]{ani.options}}. Defaults to 'Animation of
##' contacts'.
##' @return invisible(NULL)
##' @references \itemize{
##'   \item Yihui Xie (2013). animation: An R Package for Creating Animations and
##'     Demonstrating Statistical Methods. Journal of Statistical Software,
##'     53(1), 1-27.
##'     URL http://www.jstatsoft.org/v53/i01/
##' 
##'   \item Kahle, D. and Wickham, H. Manual package 'ggmap' -
##'     A package for spatial visualization with Google Maps and OpenStreetMap.
##'     URL http://cran.r-project.org/web/packages/ggmap/ggmap.pdf
##' 
##'   \item Widgren, S. and Frossling, J., Spatio-temporal evaluation of cattle
##'     trade in Sweden: description of a grid network visualization technique.
##'     Geospatial Health 5(1), 2010, pp 119-130.
##'     URL http://www.geospatialhealth.unina.it/articles/v5i1/gh-v5i1-12-widgren.pdf
##' }
##' @import ggmap
##' @import animation
##' @export
##' @examples
##' \dontrun{
##' data(transfers)
##'
##' root <- unique(c(transfers$source, transfers$destination))
##' ngen <- length(root)
##' set.seed(123)
##' lon_min <- 13
##' lon_max <- 17
##' lat_min <- 56
##' lat_max <- 63
##' 
##' lon <- lon_min + runif(ngen) * (lon_max - lon_min)
##' lat <- lat_min + runif(ngen) * (lat_max - lat_min)
##' coords <- data.frame(id=root, lon, lat)
##'
##' i <- sample(seq_len(nrow(transfers)), 100, replace=FALSE)
##' Animate(transfers[i,], coords, get_map('Sweden', zoom=5), "week")
##' }
##' 
Animate <- function(movements,
                    coords,
                    map,
                    interval=c("day", "week", "month", "quarter", "year"),
                    outdir=getwd(),
                    title="Animation of contacts")
{
    ## Before doing any map check that arguments are ok
    ## from various perspectives.
    if(any(missing(movements),
           missing(coords),
           missing(map))) {
        stop('Missing parameters in call to Animate')
    }

    interval <- match.arg(interval)
    
    if(!is.data.frame(movements)) {
        stop('movements must be a data.frame')
    }

    if(!all(c('source', 'destination', 't') %in% names(movements))) {
        stop('movements must contain the columns source, destination and t.')
    }

    ##
    ## Check movements$source
    ##
    if(any(is.factor(movements$source), is.integer(movements$source))) {
        movements$source <- as.character(movements$source)
    } else if(!is.character(movements$source)) {
        stop('invalid class of column source in movements')
    }

    if(any(is.na(movements$source))) {
        stop('source in movements contains NA')
    }

    ##
    ## Check movements$destination
    ##
    if(any(is.factor(movements$destination), is.integer(movements$destination))) {
        movements$destination <- as.character(movements$destination)
    } else if(!is.character(movements$destination)) {
        stop('invalid class of column destination in movements')
    }

    if(any(is.na(movements$destination))) {
        stop('destination in movements contains NA')
    }

    ##
    ## Check movements$t
    ##
    if(any(is.character(movements$t), is.factor(movements$t))) {
        movements$t <- as.Date(movements$t)
    }
    if(!identical(class(movements$t), 'Date')) {
        stop('invalid class of column t in movements')
    }

    if(any(is.na(movements$t))) {
        stop('t in movements contains NA')
    }

    movements <- unique(movements[, c('source', 'destination', 't')])
    movements$t <- cut(movements$t, breaks=interval)

    ##
    ## Check coordinates
    ##
    i <- match(movements$source, coords$id)
    if(any(is.na(i))) {
        stop('Missing coordinates for source holdings')
    }
    movements$lon_from <- coords$lon[i]
    movements$lat_from <- coords$lat[i]

    i <- match(movements$destination, coords$id)
    if(any(is.na(i))) {
        stop('Missing coordinates for destination holdings')
    }
    movements$lon_to <- coords$lon[i]
    movements$lat_to <- coords$lat[i]

    ##
    ## Generate animation
    ##
    create_map <- function(contacts) {
        t <- unique(contacts$t)
        print(ggmap(map) +
              geom_segment(data=contacts,
                           aes_string(x='lon_from',
                                      y='lat_from',
                                      xend='lon_to',
                                      yend='lat_to')) + 
              labs(x = 'Longitude', y = 'Latitude') +
              ggtitle(t))
        ani.pause()
        invisible(NULL)
    }
   
    saveHTML({par(mar = c(4, 4, 0.5, 0.5))
              d_ply(movements, ~t, .fun=create_map)},
             outdir = outdir,
             title = title,
             verbose = FALSE)
    
    invisible(NULL)
}