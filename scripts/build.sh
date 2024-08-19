
# Remove the target directory to start fresh
rm -rf target/

# Default build type
build_type="debug"

# Function to display usage information
usage() {
    echo "Usage: $0 [-h] [-b build_type]"
    echo "Options:"
    echo "  -h               Display this help message"
    echo "  -b build_type    Set the build type (debug/release) [default: debug]"
    exit 1
}

# Parse command-line options
while getopts ":hb:" opt; do
    case $opt in
        h) usage ;;
        b) build_type="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Shift to get rid of the parsed options
shift $((OPTIND -1))

# Verify build type
if [[ "$build_type" != "debug" && "$build_type" != "release" ]]; then
    echo "Invalid build type: $build_type" >&2
    usage
fi


# Run Cargo commands based on the build type
if [ "$build_type" == "release" ]; then
    cargo xtask build-ebpf --release || exit 1
    cargo build --release || exit 1
else
    cargo xtask build-ebpf || exit 1
    export RUSTFLAGS="-C link-arg=-lasan"
    cargo build || exit 1
fi

# Output build type
echo "Build type: $build_type"