export AbstractOptimizer
export Adam, GradientDescent

abstract type AbstractOptimizer end

include("adam.jl")
include("gradient_descent.jl")