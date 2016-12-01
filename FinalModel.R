library(ggplot2)
library(gganimate)
library(animation)

# Run all the functions in the file Functions.R before running this model

# A. Initializing parameters

# experimental variables
size <- 8 # number of Tadros in the group
goal.direct <- 1 # degree of goal-directedness, between 0 and 1
n.iteration <- 50 # numbers of iteration to run
Tadro <- c(1:size)

# basic parameters for each Tadro
v <- 0.5 # internal velocity of Tadro
Vmax <- 1.5 # maximum velocity of Tadro
Cd <- 1 # coefficient of drag; the greater this is, the more effect inertia has
a <- 1 # interaction range, repulsion grows exponentially when d is smaller than this
# also as this increases the function grows steeper

# position of the light source, set as (0,0)
light.x <- 0
light.y <- 0

# B. Main function

Run <- function(){
  
  # initialize data frame for data collection
  Time <- rep(0:n.iteration, each = size)
  tadro <- rep(c(1:size), n.iteration + 1)
  x <- numeric(length(Time))
  y <- numeric(length(Time))
  
  last.dx <- numeric(size)
  last.dy <- numeric(size)

  # initialize initial position (for iteration = 0)
  for(i in 1:size){
    x[i] <- runif(1, -5, 5)
    y[i] <- runif(1, -5, 5)
  }
  
  # x and y coordinate can be represent as a function of iteration and tadro number
  # the calculation is [size*iteration + tadro number]
  # or [size*t + i]
  # for example, data$x[5*3+2] the x coordinate for tadro 2 in iteration 3 when group size is 5
  
  # for each iteration
  for(t in 1:n.iteration){
    
    # for each individual Tadro
    for(i in Tadro){

      # Read the final coordinates of Tadro i after the last iteration
      current.x <- x[size*(t-1) + i]
      current.y <- y[size*(t-1) + i]
      
      # 1. Calculate attractive force
      distance.light <- light.distance(current.x, current.y) # calculate the distance between tadro and light
      # displacement due to attraction to light is a function of velocity and goal-directedness
      d.light <- calc.attract(distance.light, current.x, current.y)
      dx.light <- d.light[1]
      dy.light <- d.light[2]
      
      # if tadro is not goal directed, it moves randomly
      # alternatively, it moves d = v towards the light

      # 2. Calculate inertial force
      # a function of last final displacement, the drag coefficient, and the mass of tadro
      dx.inert = last.dx[i] * Cd # displacement on x-axis
      dy.inert = last.dy[i] * Cd # displacement on y-axis
      
      # 3. Calculate repulsive force
      dx.R <- numeric(size)
      dy.R <- numeric(size)
      
      # calculate the repulsive force from each tadro other than i
      for(j in Tadro[-i]){
     
        # read the coordinates of Tadro j
        other.x <- x[size * (t-1) + j]
        other.y <- y[size * (t-1) + j]
        
        # calculate the distance between the two tadro
        d <- distance(current.x, current.y, other.x, other.y)
        
        # the repulsion is a function of the distance and the repulsion coefficient a
        # when distance is far, repulsion is very small
        # as d decreases, repulsion increases exponentially
        repulsion <- exp(-d/a) * v
        
        # to get displacement on the x and y axes
        dx.R[j] <- (current.x - other.x) * (repulsion/d)
        dy.R[j] <- (current.y - other.y) * (repulsion/d)
        
      } # repulsion loop ends
  
      
      # sum to get total displacement due to repulsion
      dx.repulse <- sum(dx.R)
      dy.repulse <- sum(dy.R)

      # 4. Calculate final displacement
      # sum to get total displacement on x and y axes
      dx <- dx.light + dx.inert + dx.repulse
      dy <- dy.light + dy.inert + dy.repulse
      
      # calculate total displacement
      displacement <- sqrt(dx^2 + dy^2)
      
      # if displacement exceeds Vmax, then final displacement equals Vmax
      # calculate new final displacement on x and y axes
      # otherwise, final displacement = dx and dy
      d <- check.velocity(displacement)
      
      final.dx <- dx * d/displacement
      final.dy <- dy * d/displacement
      
      # 5. Update data
      # sum previous coordinate and displacement to get coordinates for new position
      x[size * t + i] <- current.x + final.dx
      y[size * t + i] <- current.y + final.dy
      
      # keep track of the displacement for inertial force calculation next time
      last.dx[i] <- final.dx
      last.dy[i] <- final.dy
      
    } # individual loop ends
    
  } # iteration loop ends
  
  data <- data.frame(Time, tadro, x, y)
  return(data)
} # main loop ends

# C. Iterations

# check parameters; if not set as desired values, adjust at top of file
size
goal.direct
n.iteration

results <- Run()

# * calculate the ideal group stability coeffcient and stuff

# D. Graphic Representation of Data

# a coordinate graph with gridlines, a circle in the center as light, and path of each
# tadro in different colors.
# 
# note the stability coefficient
# 
# generate for different group size, goal.direct and other parameters
# 

results$Prev.x <- prev.generate(x)
results$Prev.y <- prev.generate(y)
Direction.x <- direction.mark.generate(x)
Direction.y <- direction.mark.generate(y)

plot.result <- ggplot(results[109:208,], aes(x = x, y = y, color = factor(Tadro))) +
  geom_point(results[101:108,], aes(x = x, y = y, color = factor(Tadro))) +
  geom_segment(aes(xend = Prev.x, yend = Prev.y, color = factor(Tadro)), 
               arrow = arrow(length = unit(0.15,"cm"), ends = "first"))

plot.result


plot.result <- ggplot(results, aes(x = x, y = y, colour = factor(Tadro))) +
  geom_point(data = results[1:8,], aes(x = x, y = y, colour = factor(Tadro))) +
  # geom_path() +
  # geom_segment(aes(xend = directionX, yend = directionY, colour=factor(Tadro)),arrow = arrow(length = unit(0.2,"cm")))
  geom_segment(results,aes(xend = Prev.x, yend = Prev.y, colour=factor(Tadro)), arrow = arrow(length = unit(0.15,"cm"), ends = "first"))
  # xlim(-2, 2) +
  # ylim(-2, 2)
  #facet_wrap(~Time)

plot.result


# Calculate the group stability, Sg

calc.sg <- function(data){

  x <- data[,3]
  y <- data[,4]
  
  Io <- numeric(n.iteration)
  Ii <- numeric(n.iteration)
  Sg <- numeric(n.iteration)
  
  for (t in 1:n.iteration) {
    
    # Step 1: calculate observed instability (Io)
    # which is the sum of the differences in distances between each tadro
         # 1. calculate current distance between each tadro
    
    current.tadro.distance <- matrix(nrow = size, ncol = size)
    
    for(i in Tadro){
      A.x <- x[size*t + i]
      A.y <- y[size*t + i]
      for (j in Tadro) {
        B.x <- x[size*t + j]
        B.y <- y[size*t + j]
        current.tadro.distance[i,j] <- distance(A.x, A.y, B.x, B.y)
      }
    } # current distance calc loop ends
    
    
          # 2. calculate distance between each tadro at the last iteration
    last.tadro.distance <- matrix(nrow = size, ncol = size)
    
    for(i in Tadro){
      a.x <- x[size*(t-1) + i]
      a.y <- y[size*(t-1) + i]
      for (j in Tadro) {
        b.x <- x[size*(t-1) + j]
        b.y <- y[size*(t-1) + j]
        last.tadro.distance[i,j] <- distance(a.x, a.y, b.x, b.y)
      }
    } # last distance calc loop ends
    
          # 3. calculate their difference
    different.tadro.distance <- abs(current.tadro.distance - last.tadro.distance)
          # 4. sum the differences
    Io[t] <- sum(different.tadro.distance)/2 
    # divide by 2 because everything was counted twice in the matrix
    
    
    # Step 2: Calculate Ii
    # which is the maximum instability possible for this iteration, based on their speed
          # 1. compute the actual speed at which each robot traveled
          # this is basically the distance traveled from last position
    speed <- numeric(size)
    
    for (i in Tadro){
      current.x <- x[size*t + i]
      current.y <- y[size*t + i]
      last.x <- x[size*(t-1) + i]
      last.y <- y[size*(t-1) + i]
      speed[i] <- distance(current.x, current.y, last.x, last.y)
    }
    
          # 2. find the location that leads to the smallest Id
          # (need to ask Josh about this)
          #Ii[t] <- Io[t]
          # right now I'm just getting the total speed and using it to adjust the Io
    iteration.speed <- sum(speed)
    Ii[t] <- iteration.speed
    
    # Step 3: Calculate Sg
    # take the ratio between Io and Ii, and subtract it from 1
    Sg[t] <- 1/(Io[t]/Ii[t])
    
    
  } # iteration loop ends
  
  data.Sg <- data.frame(iteration = c(1:n.iteration), Io = Io, Ii = Ii, Sg = Sg)
  return(data.Sg)
  
} # Sg calculation function ends

Sg <- calc.sg(data)
plot(Sg$iteration, Sg$Sg)