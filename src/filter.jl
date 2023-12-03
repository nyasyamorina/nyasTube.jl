export Filter

import ..nyasTube

"""
    Filter(filter_function)

Filtering function that support arbitrarily combination.
    
# Examples

```julia
julia> streams = streams(Video(...)); length(streams)
20

julia> filter!(has_audio & ~is_webm, streams); length(streams)
5
```"""
struct Filter{F} <: Function
    f::F    # f: Stream -> Bool
end

(f::Filter)(s) = f.f(s)::Bool

const inverse_boolean_operators = (:~, :!)
for op ∈ inverse_boolean_operators
    @eval Base.$op(f::Filter) = Filter(s -> Base.$op(f.f(s)))
end

"note that Julia cannot overload short circuit operators `&&` and `||`"
const binary_boolean_operators = (:&, :|, :⊻, :⊼, :⊽)
for op ∈ binary_boolean_operators
    @eval Base.$op(f::Filter, g::Filter) = Filter(s -> Base.$op(f.f(s), g.f(s)))
end