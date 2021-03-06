mutable struct GradientDescent{T} <: AbstractOptimizer
    λ    :: Float64
    it   :: Int64
    diff :: T
end
function GradientDescent(;λ::T=1e-2)  where { T <: Real }
    return  GradientDescent(λ, 1, zero(T))
end
function GradientDescent(len::Int; λ::T=1e-2)  where { T <: Real }
    return GradientDescent(λ, 1, zeros(T, len))
end
function GradientDescent(size::Tuple; λ::T=1e-2) where { T <: Real }
    return GradientDescent(λ, 1, zeros(T, size))
end

getall(optimizer::GradientDescent) = return optimizer.λ, optimizer.it, optimizer.diff


function update!(x::T, optimizer::GradientDescent{ T }, ∇::T) where { T <: Real }

    # fetch parameters
    λ, _, diff = getall(optimizer)

    # calculate gradient step
    diff = λ * ∇
    optimizer.diff = diff

    # update iteration count
    optimizer.it   += 1

    # update x and return
    x -= diff
    return x

end

function update!(x::T, optimizer::GradientDescent{ T }, ∇::T) where { T <: AbstractVector }

    # fetch parameters
    λ, _, diff = getall(optimizer)

    @turbo for k in 1:length(x)

        # perform accelerated gradient step
        diff[k] = λ*∇[k]

        # update x
        x[k] -= diff[k]

    end

    # update iteration count
    optimizer.it   += 1

    # return x
    return x

end

function update!(x::T, optimizer::GradientDescent{ T }, ∇::T) where { T <: AbstractMatrix }

    # fetch parameters
    λ, _, diff = getall(optimizer)

    (ax1,ax2) = axes(x)

    @turbo for k1 in ax1
        for k2 in ax2

            # perform accelerated gradient step
            diff[k1,k2] = λ*∇[k1,k2]

            # update x
            x[k1,k2] -= diff[k1,k2]

        end
    end

    # update iteration count
    optimizer.it += 1

    # return x
    return x

end