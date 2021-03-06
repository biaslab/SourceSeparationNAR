mutable struct LeakyReluLayer{M <: Union{Nothing, AbstractMemory}} <: AbstractLayer
    dim_in          :: Int64
    dim_out         :: Int64
    alpha           :: Float64
    memory          :: M
end
function LeakyReluLayer(dim; batch_size::Int64=128, alpha::Float64=0.1)
    return LeakyReluLayer(dim, dim, alpha, TrainMemory(dim, batch_size))
end

function forward(layer::LeakyReluLayer, input) 
    
    # fetch input and output in layer
    output = similar(input)

    # update output of layer
    return leakyrelu!(output, input, layer.alpha)
    
end

function forward!(layer::LeakyReluLayer{<:AbstractMemory}, input)

    # set input
    copytoinput!(layer, input)

    # call forward function and return output
    return forward!(layer)

end

function forward!(layer::LeakyReluLayer{<:AbstractMemory}) 

    # update and return output of layer
    return leakyrelu!(getmatoutput(layer), getmatinput(layer), layer.alpha)
    
end

function backward(layer::LeakyReluLayer, output)

    # fetch input and output in layer
    input = similar(output)
    alpha  = layer.alpha

    # update input of layer
    input = invleakyrelu!(input, output, alpha)

    # return input 
    return input

end

function forward_jacobian!(layer::LeakyReluLayer{<:DeployMemory})

    # compute output
    output = forward!(layer)
    
    # compute jacobian
    input = getinput(layer)
    jacobian_layer = getjacobian(layer)
    alpha = layer.alpha
    @turbo for k in 1:length(input)
        jacobian_layer.diag[k] = !signbit(input[k])*(1-alpha) + alpha
    end

    # compute jacobian at output 
    custom_mul!(getjacobianoutput(layer), jacobian_layer, getjacobianinput(layer))

    return output, getjacobianoutput(layer)

end

function jacobian(layer::LeakyReluLayer, input::Vector{T}) where { T <: Real }

    # create jacobian
    alpha = layer.alpha
    tmp = Vector{Float64}(undef, length(input))
    @turbo for k in 1:length(input)
        tmp[k] = !signbit(input[k])*(1-alpha) + alpha
    end
    J = Diagonal(tmp)

    # return jacobian
    return J
end

function propagate_error!(layer::LeakyReluLayer{<:TrainMemory}) 
    
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

update!(::LeakyReluLayer{<:TrainMemory}) = return

setlr!(::LeakyReluLayer{<:TrainMemory}, lr) = return

isinvertible(layer::LeakyReluLayer) = layer.alpha > 0

nr_params(::LeakyReluLayer) = 0

function deploy(layer::LeakyReluLayer; jacobian_start=IdentityMatrix())

    jacobian_layer = jacobian(layer, randn(layer.dim_in))
    jacobian_layer_output = jacobian_layer * jacobian_start

    return LeakyReluLayer(
        layer.dim_in,
        layer.dim_out,
        layer.alpha,
        DeployMemory(
            zeros(layer.dim_in), 
            zeros(layer.dim_out), 
            jacobian_layer,
            jacobian_start,
            jacobian_layer_output
        )
    )
end



function print_info(layer::LeakyReluLayer, level::Int, io)

    # print layer
    write(io, string(["--" for _=1:level]..., " LeakyReluLayer(", layer.dim_in, ", ", layer.alpha, ")\n"))

end

function leakyrelu!(output, input, alpha)
    @turbo for ind in CartesianIndices(input)
        output[ind] = (!signbit(input[ind])*(1-alpha) + alpha) * input[ind]
    end
    return output
end
function invleakyrelu!(input, output, alpha)
    ialpha = 1 / alpha
    @turbo for ind in CartesianIndices(input)
        input[ind] = (!signbit(output[ind])*(1-ialpha) + ialpha) * output[ind]
    end
    return input
end