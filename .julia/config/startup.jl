using OhMyREPL
# using DataFrames
enable_autocomplete_brackets(true)
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
