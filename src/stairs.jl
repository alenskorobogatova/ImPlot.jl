function PlotStairs(label_id, x::AbstractArray{<:Real}, y::AbstractArray{<:Real}, args...)
    return PlotStairs(label_id, promote(x, y)..., args...)
end

function PlotStairs(y::AbstractArray{T}; label_id::String="", count::Integer=length(y),
                    xscale::Real=1.0, x0::Real=0.0, offset::Integer=0,
                    stride::Integer=1) where {T<:ImPlotData}
    return PlotStairs(label_id, y, count, xscale, x0, offset, stride * sizeof(T))
end

function PlotStairs(x::AbstractArray{T}, y::AbstractArray{T};
                    count::Integer=min(length(x), length(y)), offset::Integer=0,
                    stride::Integer=1, label_id::String="") where {T<:ImPlotData}
    return PlotStairs(label_id, x, y, count, offset, stride * sizeof(T))
end

function PlotStairs(x::AbstractArray{<:Real}, y::AbstractArray{<:Real}; kwargs...)
    return PlotStairs(promote(x, y)..., kwargs...)
end
