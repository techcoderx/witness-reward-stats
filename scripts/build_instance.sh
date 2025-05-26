#!/bin/sh
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

IMAGE=witreward-stats
RW_IMAGE=witreward-stats-rewriter
TAG=latest
BUILD_ARGS=""

print_help () {
    cat <<EOF
Usage: $0 [OPTION[=VALUE]]...

Builds the Docker images.
OPTIONS:
    --image=IMAGE                   The image name to use (default: witreward-stats)
    --rewriter-image=RW_IMAGE       The rewriter image name to use (default: witreward-stats-rewriter)
    --tag=TAG                       The image tag to use (default: latest)
    --plain-output                  Uses --progress=plain arg in Docker build command
    --help,-h,-?                    Displays this help message
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tag=*)
        TAG="${1#*=}"
        ;;
    --plain-output)
        BUILD_ARGS="$BUILD_ARGS --progress=plain"
        ;;
    --help|-h|-?)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

echo Building the images with tag $TAG...

if [ -n "$BUILD_ARGS" ]; then
    echo Build args: $BUILD_ARGS
fi

docker build -t $IMAGE:$TAG $BUILD_ARGS -f $SCRIPTPATH/../Dockerfile .
docker build -t $RW_IMAGE:$TAG $BUILD_ARGS -f $SCRIPTPATH/../frontend/Dockerfile .
