## Everything in this file gets sourced during `simInit()`,
## and all functions and objects are put into the `simList`.
## To use objects, use `sim$xxx` (they are globally available to all modules).
## Functions can be used without `sim$` as they are namespaced to the module,
## just like functions in R packages.
## If exact location is required, functions will be: `sim$<moduleName>$FunctionName`.
defineModule(sim, list(
  name = "establishment",
  description = "insert module description here",
  keywords = c("insert key words here"),
  authors = c(person(c("First", "Middle"), "Last", email="email@example.com", role=c("aut", "cre"))),
  childModules = character(0),
  version = numeric_version("0.1.0"),
  spatialExtent = raster::extent(rep(NA_real_, 4)),
  timeunit = "year",
  reqdPkgs = list("SpaDES", "raster", "grid", "sp"),
  parameters = rbind(
    defineParameter("establishThresh", "numeric", 0.3, 0, 1, "This describes the threshold above which establishment will occur"),
    defineParameter("Nsource", "integer", 40, 1, 200, "This describes the number of 'source' locations"),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA, "This describes the simulation time at which the first plot event should occur")
  ),
  inputObjects = bind_rows(
    expectsInput(objectName = "quality", objectClass = "RasterLayer", desc = c("A 'quality' layer, used with establishThresh to determine whether something establishes"), sourceURL = NA)
  ),
  outputObjects = bind_rows(
    createsOutput(objectName = "establish", objectClass = "RasterLayer", desc = NA)
  )
))

## event types
#   - type `init` is required for initialization

doEvent.establishment = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      sim <- scheduleEvent(sim, start(sim), "establishment", "annualEstablish")
      sim <- scheduleEvent(sim, P(sim)$.plotInitialTime, "establishment", "plot")
    },
    annualEstablish = {
      sim$sourceLocation <- initiateAgents(sim$quality, P(sim)$Nsource) # SpaDES function

      dist <- distanceFromPoints(sim$quality, sim$sourceLocation)
      # Create random establishment probability map
      # Actual establishment is a function of inverse distance and establishment
      #  probability maps with a threshold parameter
      sim$establish <- (1/dist * sim$quality) > P(sim)$establishThresh

      # schedule new event
      sim <- scheduleEvent(sim, time(sim) + 1, "establishment", "annualEstablish")
    },
    plot = {
      Plot(sim$establish, title = "", new=TRUE)

      # make the source locations into a SpatialPoints object, for plotting
      Plot(sim$sourceLocation, addTo="sim$establish")
      # annotate with parameter values, wiping first with a white rectangle
      grid.rect(x=0.8, y=0.9, width = 0.4, height=0.05, gp=gpar(fill="white", col="white"))
      grid.text(paste("Nsource:",P(sim)$Nsource, ", establishThresh:", P(sim)$establishThresh),
                x= 0.8, y = 0.9)
      sim <- scheduleEvent(sim, time(sim) + 1, "establishment", "plot")
    },
    warning(paste("Undefined event type: \'", current(sim)[1, "eventType", with = FALSE],
                  "\' in module \'", current(sim)[1, "moduleName", with = FALSE], "\'", sep = ""))
  )
  return(invisible(sim))
}


.inputObjects = function(sim) {
  if(is.null(sim$quality)) {
    sim$quality <- raster(extent(0,100,0,100), res = c(1,1))
    sim$quality <- gaussMap(sim$quality, speedup=1)
    sim$quality <- (sim$quality-maxValue(sim$quality))/
      (minValue(sim$quality)- maxValue(sim$quality))
  }
  return(invisible(sim))
}
