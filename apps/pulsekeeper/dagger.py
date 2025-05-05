from dagger import function, container

@function
def container():
    return (
        container()
        .from_("ghcr.io/gleam-lang/gleam:v1.0.0")
        .with_directory("/app", ".")
        .with_workdir("/app")
        .with_exec(["gleam", "build"])
    )
