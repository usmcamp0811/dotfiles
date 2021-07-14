# to automate adding OhMyREPL package to REPL on startup
atreplinit() do repl
    try
        @eval using OhMyREPL
    catch e
        @warn "error while importing OhMyREPL" e
    end

    @async begin
    # reinstall keybindings to work around https://github.com/KristofferC/OhMyREPL.jl/issues/166
    sleep(1)
    OhMyREPL.Prompt.insert_keybindings()
    enable_autocomplete_brackets(true)
    end
end
# using DataFrames
# OhMyREPL.input_prompt!(">>> ")
# OhMyREPL.output_prompt!("\n")
# head(df::DataFrame) = first(df, 5)
function template()
    @eval begin
        using PkgTemplates
        Template(;
           user="mcamp",
           dir="/home/mcamp/code-home/",
           authors="Matthew Camp",
           julia=v"1.6.1",
           plugins=[
               License(; name="MIT"),
               Git(; manifest=true, ssh=true),
               GitLabCI(),
               Codecov(),
               Documenter{GitLabCI}(),
               Develop(),
           ],
       )
    end
end
