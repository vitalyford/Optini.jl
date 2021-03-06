"""
    StrongWolfeLineSearch{I<:AbstractInitial, C, S, T} <: AbstractLineSearch

`StrongWolfeLineSearch` computes a step length that satifies both the Armijo sufficient 
decrease and the curvature conditions.

# Fields
- `init::I`: initial step length method
- `c_1::C`: Armijo condition constant
- `c_2::C`: curvature condition constant
- `scale::S`: scale factor to expand step length bracket
- `α_max::T`: maximum step length
"""
struct StrongWolfeLineSearch{I<:AbstractInitial, C, S, T} <: AbstractLineSearch
    init::I
    c_1::C
    c_2::C
    scale::S
    α_max::T

    function StrongWolfeLineSearch(init, c_1, c_2, scale, α_max)
        0 < c_1 < c_2 < 1 || error("Constants must satisfy 0 < `c_1` < `c_2` < 1")
        scale > 1 || error("`scale` factor must be larger than 1")
        I = typeof(init)
        C = typeof(c_1)
        S = typeof(scale)
        T = typeof(α_max)
        return new{I, C, S, T}(init, c_1, c_2, scale, α_max)
    end
end

"""
    StrongWolfeLineSearch(; kwargs...)

Initiate `StrongWolfeLineSearch`.

# Keywords
- `init=StaticInitial()`: initial step length method
- `c_1=1e-4`: Armijo condition constant
- `c_2=0.9: curvature condition constant
- `scale=2.0`: scale factor to expand step length bracket
- `α_max=100_000`: maximum step length
"""
function StrongWolfeLineSearch(;
        init=StaticInitial(),
        c_1=1e-4, 
        c_2=0.9,
        scale=2.0,
        α_max=100_000)
    return StrongWolfeLineSearch(init, c_1, c_2, scale, α_max)
end

function (sw::StrongWolfeLineSearch{<:AbstractInitial{T}})(f, state, p) where {T}
    x = state.x
    ϕ₀ = state.f
    dϕ₀ = state.∇f ⋅ p
    c₁ = sw.c_1
    c₂ = sw.c_2
    ρ = T(sw.scale)
    αₘₐₓ = T(sw.α_max)
    αₖ = zero(T)
    ϕαₖ = ϕ₀
    αₖ₊₁ = sw.init(state, p)
    ϕ(α) = f(x + α*p)
    iter = 0
    while αₖ₊₁ < αₘₐₓ
        ϕαₖ₊₁ = ϕ(αₖ₊₁)
        if ϕαₖ₊₁ > ϕ₀ + c₁*αₖ₊₁*dϕ₀ || (ϕαₖ₊₁ ≥ ϕαₖ && iter > 1)
            return zoom(ϕ, αₖ, αₖ₊₁, ϕ₀, dϕ₀, ϕαₖ, c₁, c₂)
        end
        dϕαₖ₊₁ = Zygote.gradient(ϕ, αₖ₊₁)[1]
        abs(dϕαₖ₊₁) ≤ -c₂*dϕ₀ && return αₖ₊₁
        if dϕαₖ₊₁ ≥ 0
            return zoom(ϕ, αₖ₊₁, αₖ, ϕ₀, dϕ₀, ϕαₖ₊₁, c₁, c₂)
        end
        αₖ = αₖ₊₁
        ϕαₖ = ϕαₖ₊₁
        αₖ₊₁ *= ρ
        iter += 1
    end
    return αₘₐₓ
end

function zoom(ϕ, αₗₒ, αₕᵢ, ϕ₀, dϕ₀, ϕαₗₒ, c₁, c₂)
    while true
        α = (αₗₒ + αₕᵢ) / 2
        ϕα = ϕ(α)
        if ϕα > ϕ₀ + c₁*α*dϕ₀ || ϕα ≥ ϕαₗₒ
            αₕᵢ = α
        else
            dϕα = Zygote.gradient(ϕ, α)[1]
            abs(dϕα) ≤ -c₂*dϕ₀ && return α
            if dϕα*(αₕᵢ - αₗₒ) ≥ 0
                αₕᵢ = αₗₒ
            end
            αₗₒ = α
            ϕαₗₒ = ϕα
        end 
    end
end