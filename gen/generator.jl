using Clang.Generators
using ExprTools, MacroTools
# using ImPlot.LibCImPlot.CImPlot_jll

using CImGui.CImGui_jll

include_dir = joinpath(CImGui_jll.artifact_dir, "include")

cd(@__DIR__)

const CIMPLOT_H = joinpath(@__DIR__, "cimplot_patched.h") |> normpath

options = load_options(joinpath(@__DIR__, "generator.toml"))

args = ["-I$include_dir", "-DCIMGUI_DEFINE_ENUMS_AND_STRUCTS"]

# add definitions
@add_def ImVec2
@add_def ImVec4
@add_def ImGuiMouseButton
@add_def ImGuiKeyModFlags
@add_def ImS8
@add_def ImU8
@add_def ImS16
@add_def ImU16
@add_def ImS32
@add_def ImU32
@add_def ImS64
@add_def ImU64
@add_def ImTextureID
@add_def ImGuiCond
@add_def ImGuiDragDropFlags
@add_def ImDrawList
@add_def ImGuiContext

# jltypes = [Float32, Float64, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64]
# typedict = Dict(zip(imtypes,jltypes))
#type_names = ["FloatPtr", "doublePtr", "S8Ptr", "U8Ptr", "S16Ptr", "U16Ptr", "S32Ptr", "U32Ptr", "S64Ptr", "U64Ptr"]  
imdatatypes = [:Cfloat, :Cdouble, :ImS8, :ImU8, :ImS16, :ImU16, :ImS32, :ImU32, :ImS64, :ImU64]
plot_types = ["Line", "Scatter", "Stairs", "Shaded", "BarsH", "Bars", "ErrorBarsH", "ErrorBars", "Stems", "VLines", "HLines", "PieChart", "Heatmap", "Histogram", "Histogram2D", "Digital"]

ctx = create_context(CIMPLOT_H, args, options)
build!(ctx, BUILDSTAGE_NO_PRINTING)

#json_string = read("my.json", String)
#JSON3.read(json_string)
# @capture(ex, ccall((funsymbol_, libcimplot), rettype_, (argtypes__,), argnames__))

function carg_modify(ex, fun_args)
    if @capture(ex, ccall((funsymbol_, libcimplot), rettype_, (argtypes__,), argnames__))
        for (i, argtype) in enumerate(argtypes)
            if @capture(argtype, Ptr{ptrtype_}) && ptrtype ∈ imdatatypes
                arg = fun_args[i]
                @show arg
                if @capture(fun_args[i], sym_::Ptr{sigptrtype_})
                    if sigptrtype == ptrtype
                    fun_args[i] = :($sym::Union{Ptr{$ptrtype},Ref{$ptrtype},AbstractArray{$ptrtype}})
                    println("Here")
                    end
                elseif @capture(argtype, sym_::Cint)
                    fun_args[i] = :($sym::Integer) 
                elseif @capture(argtype, sym_::Cdouble | sym_::Cfloat)
                    fun_args[i] = :($sym::Real)
                end
            end
        end
        return :(ccall(($funsymbol, libcimplot), $rettype, $(argtypes...,), $(argnames...)))
    else
        return ex
    end
end             

function revise_function(e::Expr)
    
    def = ExprTools.splitdef(e)
    # Skip if it's not a prefix added by cimplot
    fun_name = string(def[:name])
    startswith(fun_name,"ImPlot_") || return e

    # Strip off the prefix to match C++ (since we have a namespace)
    fun_name = fun_name[8:end] # remove first 7 characters == 'ImPlot_'

    # Plot functions are templated and have a regular structure
    if startswith(fun_name, "Plot")
        body = def[:body]
        fun_args= def[:args]
        new_body = MacroTools.postwalk(x -> carg_modify(x, fun_args), body)
        new_name = ""
        for ptype in plot_types
            fullname = "Plot" * ptype
            if startswith(fun_name, fullname)
                if length(fullname) > length(new_name)
                    new_name = fullname
                end
            end
        end
        def[:name] = Symbol(new_name)
        def[:args] = fun_args
        def[:body] = new_body
    end
    return ExprTools.combinedef(def)
end

function rewrite!(dag::ExprDAG)
    for node in get_nodes(dag)
        expressions = get_exprs(node)
        for (i, expr) in enumerate(expressions)
            if Meta.isexpr(expr, :function)
                expressions[i] = revise_function(expr)
            end
        end
    end
end

rewrite!(ctx.dag)
build!(ctx, BUILDSTAGE_PRINTING_ONLY)
