using Documenter
using FinnishBuildingStockData

makedocs(
    sitename = "FinnishBuildingStockData",
    format = Documenter.HTML(),
    modules = [FinnishBuildingStockData],
    pages = ["index.md", "input.md", "main_program.md", "output.md", "library.md"],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
