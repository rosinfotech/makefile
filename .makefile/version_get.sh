getVersion() {

    if [ ! -f ".version" ]; then
        echo "Error: .version file not found"
        exit 1
    fi

    version=$(head -n 1 .version | tr -d '\n\r')

    if [ -z "$version" ]; then
        echo "Error: Failed to get version from .version file"
        exit 1
    fi

    echo "$version"

}
