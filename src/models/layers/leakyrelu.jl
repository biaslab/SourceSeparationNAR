mutable struct LeakyReluLayer{T <: Real} <: AbstractLayer
    dim_in          :: Int64
    dim_out         :: Int64
    alpha           :: Float64
    input           :: Matrix{T}
    output          :: Matrix{T}
    gradient_input  :: Matrix{T}
    gradient_output :: Matrix{T}
end
function LeakyReluLayer(dim; batch_size::Int64=128, alpha::Float64=0.1)
    return LeakyReluLayer(dim, dim, alpha, zeros(dim,batch_size), zeros(dim,batch_size), zeros(dim,batch_size), zeros(dim,batch_size))
end

function forward!(layer::LeakyReluLayer) 
    
    # fetch input and output in layer
    input  = getmatinput(layer)
    output = getmatoutput(layer)
    alpha  = layer.alpha
    (ax1, ax2) = axes(input)

    # update output of layer
    @turbo for k1 in ax1
        for k2 in ax2
            output[k1,k2] = (!signbit(input[k1,k2])*(1-alpha) + alpha) * input[k1,k2]
        end
    end

    # return output 
    return output
    
end

function propagate_error!(layer::LeakyReluLayer) 
    
    # fetch input and output gradients in layer
    input           = getmatinput(layer)
    alpha           = layer.alpha
    gradient_input  = getmatgradientinput(layer)
    gradient_output = getmatgradientoutput(layer)
    (ax1, ax2) = axes(input)

    # update input gradient of layer
    @turbo for k1 in ax1
        for k2 in ax2
            gradient_input[k1,k2] = (!signbit(input[k1,k2])*(1-alpha) + alpha) * gradient_output[k1,k2]
        end
    end

    # return gradient input 
    return gradient_input
    
end

update!(::LeakyReluLayer) = return

setlr!(::LeakyReluLayer, lr) = return

isinvertible(::LeakyReluLayer) = true

nr_params(::LeakyReluLayer) = 0

function print_info(layer::LeakyReluLayer, level::Int, io)

    # print layer
    write(io, string(["--" for _=1:level]..., " LeakyReluLayer(", layer.dim_in, ", ", layer.alpha, ")\n"))

end