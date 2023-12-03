export Sorter, SortingOrder

"""
    Sorter(function...)

A sorting system that support combination.

For example, `f` and `g` are both `Sorter`, and `h = f >> g`, then
`sort(h, elements)` means sort all elements by `f` first, then sort the
elements that `f` is the same by `g`.

For the combination of more than 2 `Soter`s, the sorting order always
follow the direction of arrows, ie, `f << g << h` means sort by `h` first, then
`g`, finally `f`. Also, not recommend mixing `<<` and `>>`.
"""
struct Sorter{N} <: Function
    fs::NTuple{N, Function}
end

Sorter(fs::Function...) = Sorter{length(fs)}(fs)
Sorter(s::Sorter) = s
Sorter(s1::Sorter, s2::Sorter, ss::Sorter...) = Sorter(Sorter{length(s1) + length(s2)}((s1.fs..., s2.fs...)), ss...)

(s::Sorter{N})(x) where {N} = SortingOrder{N}(tuple((f(x) for f ∈ s.fs)...))

Base.length(::Sorter{N}) where {N} = N

Base.:<<(f::Sorter, g::Sorter) = Sorter(g, f)
Base.:>>(f::Sorter, g::Sorter) = Sorter(f, g)
Base.:-(f::Sorter{N}) where {N} = Sorter{N}(tuple((s -> -ff(s) for ff ∈ f.fs)...))

struct SortingOrder{N}
    tuple::NTuple{N, Any}
end

function Base.isless(x::SortingOrder{N}, y::SortingOrder{N}) where {N}
    for (xx, yy) ∈ zip(x.tuple, y.tuple)
        isless(xx, yy) && return true
        isless(yy, xx) && return false
    end
    return false
end