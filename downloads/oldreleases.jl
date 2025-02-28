using HTTP, JSON3, GitHub

function currentversions()
    out = Dict{VersionNumber,String}()
    for line in eachline("../config.md")
        if startswith(line, '+') || startswith(line, '#')
            continue
        end
        m = match(r"^(stable|lts|upcoming)_release = \"([^\"]+)\"", line)
        m === nothing && continue
        out[VersionNumber(m.captures[2])] = m.captures[1]
    end
    return out
end

response = HTTP.get("https://julialang-s3.julialang.org/bin/versions.json")
releases = [VersionNumber(String(k)) => v.files for (k, v) in JSON3.read(response.body)]

# Note, we may get rate limited here
github_repo = Repo("JuliaLang/julia")
releases_info = GitHub.releases(github_repo)
release_dict = Dict()

# Loop through the releases and get the publish date and version
for release in releases_info[1]
    release_dict[VersionNumber(release.tag_name)] = release.published_at
end

current = currentversions()
filter!(release -> !haskey(current, first(release)), releases)
sort!(releases; by=first, rev=true)

function osname(os, ismusl)
    if os == "winnt"
        return "Windows"
    elseif os == "mac"
        return "macOS"
    elseif os == "freebsd"
        return "FreeBSD"
    else  # linux
        libc = ismusl ? "musl" : "glibc"
        return "Linux (" * libc * ")"
    end
end

function downloadlink(url, asc)
    ext = endswith(url, ".tar.gz") ? "tar.gz" : chop(last(splitext(url)); head=1, tail=0)
    html = "<a href=\"$url\">$ext</a>"
    if asc
        html *= " (<a href=\"$url.asc\">asc</a>)"
    end
    return html
end

open("./oldreleases.md", "w") do io
    println(io, """
            @def title = "Julia Downloads (Old releases)"

            <!-- NOTE: This file was automatically generated by oldreleases.jl -->

            # Older Unmaintained Releases

            Binaries for old releases are available should you need to use them to run Julia
            code written for those releases. Note that these are not actively developed
            nor maintained anymore.

            All releases and pre-releases are [tagged in git](https://github.com/JuliaLang/julia/tags).

            @@row @@col-12
            ~~~
            <table class="downloads table table-hover table-bordered">
              <thead>
                <tr>
                  <th scope="col">Version</th>
                  <th scope="col">Operating System</th>
                  <th scope="col">Architecture</th>
                  <th scope="col">File Type</th>
                  <th scope="col">Download Link</th>
                  <th scope="col">File SHA-256</th>
                </tr>
              </thead>
              <tbody>
            """)
    for (version, files) in releases
        n = length(files)

        release_date = get(release_dict, version, "Unknown")

        println(io, """
                  <tr>
                    <th scope="row" rowspan=$n>v$version, on $release_date</th>
                """)
        isfirst = true
        for file in files
            if !isfirst
                println(io, "  <tr>")
            end
            os = osname(file["os"], file["os"] == "linux" && occursin("musl", file["url"]))
            link = downloadlink(file["url"], haskey(file, "asc"))
            println(io, """
                        <td>$os</td>
                        <td>$(file["arch"])</td>
                        <td>$(file["kind"])</td>
                        <td>$link</td>
                        <td>$(file["sha256"])</td>
                      </tr>
                    """)
            isfirst = false
        end
    end
    println(io, """
              </tbody>
            </table>
            ~~~
            @@ @@
            """)
end
