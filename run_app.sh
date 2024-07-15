
# Remove the target directory to start fresh
rm -rf target/

# Default build type
build_type="debug"
extra_args=""
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

if [[ "$build_type" == "debug" ]]; then
   extra_args=" --log "true""
fi



./build.sh -b "$build_type" || exit 1
sudo ./target/$build_type/tiiuae-fw $extra_args || exit 1