return {
    cmd = {
        "julia",
        "--startup-file=no",
        "--history-file=no",
        "-e",
        [[
        ls_install_path = joinpath(
            get(DEPOT_PATH, 1, joinpath(homedir(), ".julia")),
            "environments", "nvim-lspconfig"
        )
        pushfirst!(LOAD_PATH, ls_install_path)
        using LanguageServer
        popfirst!(LOAD_PATH)
        depot_path = get(ENV, "JULIA_DEPOT_PATH", "")
        project_path = let
            dirname(something(
                Base.load_path_expand((
                    p = get(ENV, "JULIA_PROJECT", nothing);
                    p === nothing ? nothing : isempty(p) ? nothing : p
                )),
                Base.current_project(),
                get(Base.load_path(), 1, nothing),
                Base.load_path_expand("@v#.#"),
            ))
        end
        @info "Running language server" VERSION pwd() project_path depot_path
        server = LanguageServer.LanguageServerInstance(stdin, stdout, project_path, depot_path)
        server.runlinter = true
        run(server)
        ]],
    },
    filetypes = { "julia" },
    settings = {
        julia = {
            usePlotPane = false,
            symbolCacheDownload = false,
            runtimeCompletions = true,
            singleFileSupport = true,
            useRevise = true,
            lint = {
                NumThreads = 16,
                missingrefs = "all",
                iter = true,
                lazy = true,
                modname = true,
            },
        },
    },
}

