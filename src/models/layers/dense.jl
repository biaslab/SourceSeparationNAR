using LinearAlgebra, Random

mutable struct DenseLayer{M <: Union{Nothing, AbstractMemory}, W <: Union{Matrix, Parameter}, B <: Union{Vector, Parameter}} <: AbstractLayer
    dim_in          :: Int64
    dim_out         :: Int64
    W               :: W
    b               :: B
    memory          :: M
end
function DenseLayer(dim_in, dim_out; batch_size::Int64=128, initializer::Tuple=(GlorotUniform(dim_in, dim_out), Zeros()), optimizer::Type{<:AbstractOptimizer}=Adam)
    return  DenseLayer(
                dim_in, 
                dim_out, 
                Parameter(rand(initializer[1], (dim_out, dim_in)), optimizer), 
                Parameter(rand(initializer[2], dim_out), optimizer), 
                TrainMemory(dim_in, dim_out, batch_size)
            )
end

function forward(layer::DenseLayer, input) 
    
    # calculate and return output
    return custom_mulp(getvalue(layer.W), input, getvalue(layer.b))

end

function forward!(layer::DenseLayer{<:AbstractMemory,WT,BT}, input) where { WT, BT }

    # set input
    copytoinput!(layer, input)

    # calculate and return output 
    return forward!(layer)
    
end

function forward!(layer::DenseLayer{<:AbstractMemory,WT,BT}) where { WT, BT }

    # calculate and return output
    return custom_mulp!(getmatoutput(layer), getvalue(layer.W), getmatinput(layer), getvalue(layer.b))

end

function forward_jacobian!(layer::DenseLayer{<:DeployMemory,WT,BT}) where { WT, BT }
    return forward!(layer), custom_mul!(getmatjacobianoutput(layer), getmat(layer.W), getmatjacobianinput(layer))
end


function jacobian(layer::DenseLayer, ::Vector{<:Real})
    return getvalue(layer.W)
end


function propagate_error!(layer::DenseLayer{<:TrainMemory,WT,BT}) where { WT, BT }

    # fetch from layer
    dim_in  = layer.dim_in
    dim_out = layer.dim_out
    W       = layer.W
    b       = layer.b

    ∂L_∂x   = getmatgradientinput(layer)
    ∂L_∂y   = getmatgradientoutput(layer)
    ∂L_∂W   = W.gradient
    ∂L_∂b   = b.gradient
    input   = getmatinput(layer)
    batch_size = size(input, 2)
    ibatch_size = 1 / batch_size

    # set gradients for b
    @turbo for k1 in 1:dim_out
        tmp = zero(T)
        for k2 in 1:batch_size
            tmp += ∂L_∂y[k1,k2]
        end
        ∂L_∂b[k1] = tmp * ibatch_size
    end

    # set gradient for W #todo
    custom_mul!(∂L_∂W, ∂L_∂y, input')
    @turbo for k1 in 1:dim_out
        for k2 in 1:dim_in
            ∂L_∂W[k1,k2] *= ibatch_size
        end
    end

    # set gradient at input
    custom_mul!(∂L_∂x, W.value', ∂L_∂y)

    # return gradient at input of layer
    return ∂L_∂x

end

function update!(layer::DenseLayer{<:TrainMemory,WT,BT}) where { WT, BT }

    # update parameters in layer
    update!(layer.W)
    update!(layer.b)
    
end

function setlr!(layer::DenseLayer{<:TrainMemory,WT,BT}, lr) where { WT, BT }

    # update parameters in layer
    setlr!(layer.W, lr)
    setlr!(layer.b, lr)
    
end

isinvertible(layer::DenseLayer) = false

nr_params(layer::DenseLayer) = length(layer.W) + length(layer.b)

function deploy(layer::DenseLayer; jacobian_start=IdentityMatrix())

    jacobian_layer = jacobian(layer, randn(layer.dim_in))
    jacobian_layer_output = jacobian_layer * jacobian_start


    return DenseLayer(
        layer.dim_in,
        layer.dim_out,
        getvalue(layer.W),
        getvalue(layer.b),
        DeployMemory(
            randn(layer.dim_in),
            randn(layer.dim_out),
            jacobian_layer,
            jacobian_start,
            jacobian_layer_output
        )
    )
end

function print_info(layer::DenseLayer, level::Int, io)

    # print layer
    write(io, string(["--" for _=1:level]..., " Dense(", layer.dim_in, ", ", layer.dim_out, ")\n"))

end