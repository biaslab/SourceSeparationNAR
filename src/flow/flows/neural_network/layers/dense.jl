using Octavian, LinearAlgebra

mutable struct DenseLayer{T <: Real, O1 <: AbstractOptimizer, O2 <: AbstractOptimizer} <: AbstractLayer
    W               :: Parameter{Matrix{T}, O1}
    b               :: Parameter{Vector{T}, O2}
    input           :: Vector{T}
    output          :: Vector{T}
    gradient_input  :: Vector{T}
    gradient_output :: Vector{T}
end
function DenseLayer(dim_in, dim_out)
    return DenseLayer(Parameter(randn(dim_out, dim_in)), Parameter(randn(dim_out)), zeros(dim_in), zeros(dim_out), zeros(dim_in), zeros(dim_out))
end

function forward!(layer::DenseLayer, x::Vector{T}) where { T <: Real }

    dim_in = length(x)
    W = layer.W.value
    b = layer.b.value
    dim_out = length(b)
    
    # set input in layer
    input = layer.input
    @inbounds for k = 1:dim_in
        input[k] = x[k]
    end

    # output in layer
    output = layer.output
    matmul!(output, W, x)
    @inbounds for k = 1:dim_out
        output[k] += b[k]
    end  

    # return output 
    return output
    
end

function propagate_error!(layer::DenseLayer, ∂L_∂y::Vector{<:Real})

    W       = layer.W
    b       = layer.b

    ∂L_∂x   = layer.gradient_input
    ∂L_∂W   = W.gradient
    ∂L_∂b   = b.gradient

    dim_out = length(∂L_∂y)
    dim_in  = length(∂L_∂x)

    input = layer.input

    # set gradients @inbounds for output and bias term
    gradient_output = layer.gradient_output
    @inbounds for k in 1:dim_out
        ∂L_∂yk = ∂L_∂y[k]
        gradient_output[k] = ∂L_∂yk
        ∂L_∂b[k] = ∂L_∂yk
    end

    # set gradient @inbounds for W
    @inbounds for k2 in 1:dim_out
        ∂L_∂yk2 = ∂L_∂y[k2]
        @inbounds for k1 in 1:dim_in
            ∂L_∂W[k1,k2] = ∂L_∂yk2 * input[k1]
        end
    end

    # set gradient at input
    matmul!(∂L_∂x, W.value', ∂L_∂y)

    # return gradient at input of layer
    return ∂L_∂x

end

function update!(layer::DenseLayer)
    update!(layer.W)
    update!(layer.b)
end