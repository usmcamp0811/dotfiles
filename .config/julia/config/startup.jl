# to automate adding OhMyREPL package to REPL on startup
# using DataFrames
# OhMyREPL.input_prompt!(">>> ")
# OhMyREPL.output_prompt!("\n")
# head(df::DataFrame) = first(df, 5)
function template()
    @eval begin
        using PkgTemplates
        Template(;
           user="mcamp",
           dir="/home/mcamp/.julia/dev/",
           authors="Matthew Camp",
           julia=v"1.8.1",
           plugins=[
               License(; name="GPL-3.0+"),
               Git(; manifest=true, ssh=true),
               GitLabCI(),
               Codecov(),
               Documenter{GitLabCI}(),
               Develop(),
           ],
       )
    end
end

viminit() = include("/home/mcamp/.julia/config/vi-repl.jl")
atreplinit() do repl
    try
        @async viminit()
    catch
        @warn "vim mode is not enabled due to an error"
    end
    try
        @eval using OhMyREPL
    catch e
        @warn "error while importing OhMyREPL" e
    end
    try
        @eval using RemoteREPL
    catch
        @warn "error while importing RemoteREPL"
    end

    @async begin
        # reinstall keybindings to work around https://github.com/KristofferC/OhMyREPL.jl/issues/166
        sleep(2)
        OhMyREPL.Prompt.insert_keybindings()
        OhMyREPL.enable_autocomplete_brackets(false)

    end

    function ends_with_semicolon(x)
        lines = split(x, '\n', keepempty=false)
        return length(lines) > 0 ?
            REPL.ends_with_semicolon(last(lines)) :
            false
    end
end

using Pkg
if isfile("Project.toml") && isfile("Manifest.toml")
    Pkg.activate(".")
end

try
    @eval using OhMyREPL
catch e
    @warn "error while importing OhMyREPL" e
end
try
    @eval using RemoteREPL
catch
    @warn "error while importing RemoteREPL"
end

# @async serve_repl()

schedule(@task begin
    sleep(0.1)
    OhMyREPL.__init__()
end)

if isinteractive()
    @eval using VimBindings
end
